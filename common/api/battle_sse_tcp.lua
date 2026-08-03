--[[ Raw TCP (+ TLS) SSE reader — CSP web.get buffers until close; SSE needs incremental reads. ]]

local state = require("common.api.state")
local battle_fetch = require("common.api.battle_fetch")

local battle_sse_tcp = {}

local socket_mod = nil
local ssl_mod = nil
local ssl_unavailable = false

local function load_socket()
    if socket_mod ~= nil then return socket_mod end
    for _, name in ipairs({ "socket", "shared/socket" }) do
        local ok, mod = pcall(require, name)
        if ok and mod ~= nil and mod.tcp ~= nil then
            socket_mod = mod
            battle_fetch.debug("sse tcp: using " .. name)
            return socket_mod
        end
    end
    return nil
end

local function load_ssl()
    if ssl_unavailable then return nil end
    if ssl_mod ~= nil then return ssl_mod end
    for _, name in ipairs({ "ssl", "luasec", "shared/ssl" }) do
        local ok, mod = pcall(require, name)
        if ok and mod ~= nil and mod.wrap ~= nil then
            ssl_mod = mod
            battle_fetch.debug("sse tcp: using tls " .. name)
            return ssl_mod
        end
    end
    ssl_unavailable = true
    return nil
end

function battle_sse_tcp.available()
    return load_socket() ~= nil
end

local function parse_url(url)
    url = tostring(url or "")
    local lower = url:lower()
    local is_https = lower:sub(1, 8) == "https://"

    local host, port, path = url:match("^https?://([^/:]+):(%d+)(/.*)$")
    if host ~= nil then
        return host, tonumber(port), path, is_https
    end

    host, path = url:match("^https?://([^/]+)(/.*)$")
    if host ~= nil then
        return host, is_https and 443 or 80, path, is_https
    end

    return nil, nil, nil, false
end

function battle_sse_tcp.can_connect(url)
    if not battle_sse_tcp.available() then return false end
    local _, _, _, is_https = parse_url(url)
    if is_https and load_ssl() == nil then
        return false
    end
    return true
end

local function wrap_tls(tcp, host)
    local ssl = load_ssl()
    if ssl == nil then return nil, "ssl_unavailable" end

    local params = {
        mode = "client",
        protocol = "tlsv1_2",
        options = "all",
        verify = "none",
        servername = host,
    }

    local ok, wrapped = pcall(ssl.wrap, tcp, params)
    if not ok or wrapped == nil then
        return nil, wrapped or "ssl_wrap_failed"
    end

    wrapped:settimeout(8)
    local ok_hs, err_hs = wrapped:dohandshake()
    if not ok_hs then
        pcall(function() wrapped:close() end)
        return nil, err_hs or "ssl_handshake_failed"
    end

    wrapped:settimeout(0)
    return wrapped
end

function battle_sse_tcp.connect(url, ctx)
    local socket = load_socket()
    if socket == nil then return false end

    local host, port, path, is_https = parse_url(url)
    if host == nil or path == nil then
        battle_fetch.debug("sse tcp: bad url " .. tostring(url))
        return false
    end

    if is_https and load_ssl() == nil then
        battle_fetch.debug("sse tcp: https requires ssl/luasec module")
        return false
    end

    battle_sse_tcp.disconnect()

    local tcp = socket.tcp()
    if tcp == nil then return false end

    tcp:settimeout(8)
    local ok, err = tcp:connect(host, port)
    if not ok then
        battle_fetch.debug("sse tcp connect fail: " .. tostring(err))
        pcall(function() tcp:close() end)
        return false
    end

    local io_sock = tcp
    if is_https then
        local wrapped, tls_err = wrap_tls(tcp, host)
        if wrapped == nil then
            battle_fetch.debug("sse tcp tls fail: " .. tostring(tls_err))
            pcall(function() tcp:close() end)
            return false
        end
        io_sock = wrapped
    else
        io_sock:settimeout(0)
    end

    local req = string.format(
        "GET %s HTTP/1.1\r\nHost: %s\r\nAccept: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n",
        path,
        host
    )
    local sent, send_err = io_sock:send(req)
    if not sent then
        battle_fetch.debug("sse tcp send fail: " .. tostring(send_err))
        pcall(function() io_sock:close() end)
        return false
    end

    state.battle_tcp = {
        socket = io_sock,
        ctx = ctx,
        url = url,
        pending = "",
        headers_done = false,
        is_https = is_https,
    }
    state.battle_sse_mode = "tcp"
    battle_fetch.debug("sse tcp open " .. host .. ":" .. tostring(port) .. path .. (is_https and " (tls)" or ""))
    return true
end

function battle_sse_tcp.disconnect()
    local t = state.battle_tcp
    state.battle_tcp = nil
    if t ~= nil and t.socket ~= nil then
        pcall(function() t.socket:close() end)
    end
    if state.battle_sse_mode == "tcp" then
        state.battle_sse_mode = nil
    end
end

function battle_sse_tcp.is_active()
    return state.battle_tcp ~= nil
end

function battle_sse_tcp.poll(feed_fn)
    local t = state.battle_tcp
    if t == nil or t.socket == nil or feed_fn == nil then return end

    local tcp = t.socket
    local chunk, err, partial = tcp:receive(16384)
    local data = chunk
    if (data == nil or data == "") and partial ~= nil and partial ~= "" then
        data = partial
    end

    if data ~= nil and data ~= "" then
        if not t.headers_done then
            t.pending = t.pending .. data
            local header_end = t.pending:find("\r\n\r\n", 1, true)
            local skip = 4
            if header_end == nil then
                header_end = t.pending:find("\n\n", 1, true)
                skip = 2
            end
            if header_end ~= nil then
                local headers = t.pending:sub(1, header_end - 1)
                local body = t.pending:sub(header_end + skip)
                t.pending = ""
                t.headers_done = true
                local status = headers:match("^HTTP/%d+%.%d+%s+(%d+)")
                if status ~= nil and status ~= "200" then
                    battle_fetch.debug("sse tcp http status " .. status)
                    battle_sse_tcp.disconnect()
                    state.battle_sse_connected = false
                    state.battle_last_error = "http_" .. status
                    if status == "404" then
                        state.last_error = "player_not_connected"
                    end
                    state.battle_sse_reconnect_at = os.clock() + 3
                    if t.ctx ~= nil and t.ctx._sse_on_close ~= nil then
                        pcall(t.ctx._sse_on_close, "http_" .. status, nil)
                    end
                    return
                end
                if body ~= "" then
                    feed_fn(body, t.ctx)
                end
            end
        else
            feed_fn(data, t.ctx)
        end
    end

    if err == "closed" then
        battle_fetch.debug("sse tcp closed")
        battle_sse_tcp.disconnect()
        state.battle_sse_connected = false
        state.battle_sse_reconnect_at = os.clock() + 3
        if t.ctx ~= nil and t.ctx._sse_on_close ~= nil then
            pcall(t.ctx._sse_on_close, "closed", nil)
        end
    elseif err ~= nil and err ~= "timeout" and err ~= "want read" then
        battle_fetch.debug("sse tcp err: " .. tostring(err))
    end
end

return battle_sse_tcp
