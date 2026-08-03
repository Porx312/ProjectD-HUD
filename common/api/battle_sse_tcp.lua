--[[ Raw TCP SSE reader — CSP web.get buffers until close; SSE needs incremental reads. ]]

local state = require("common.api.state")
local battle_fetch = require("common.api.battle_fetch")

local battle_sse_tcp = {}

local socket_mod = nil

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

function battle_sse_tcp.available()
    return load_socket() ~= nil
end

local function parse_url(url)
    url = tostring(url or "")
    local host, port, path = url:match("^https?://([^/:]+):(%d+)(/.*)$")
    if host ~= nil then
        return host, tonumber(port), path
    end
    host, path = url:match("^https?://([^/]+)(/.*)$")
    if host ~= nil then
        return host, 80, path
    end
    return nil, nil, nil
end

function battle_sse_tcp.connect(url, ctx)
    local socket = load_socket()
    if socket == nil then return false end

    local host, port, path = parse_url(url)
    if host == nil or path == nil then
        battle_fetch.debug("sse tcp: bad url " .. tostring(url))
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

    tcp:settimeout(0)
    local req = string.format(
        "GET %s HTTP/1.1\r\nHost: %s\r\nAccept: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n",
        path,
        host
    )
    local sent, send_err = tcp:send(req)
    if not sent then
        battle_fetch.debug("sse tcp send fail: " .. tostring(send_err))
        pcall(function() tcp:close() end)
        return false
    end

    state.battle_tcp = {
        socket = tcp,
        ctx = ctx,
        url = url,
        pending = "",
        headers_done = false,
    }
    state.battle_sse_mode = "tcp"
    battle_fetch.debug("sse tcp open " .. host .. ":" .. tostring(port) .. path)
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
                local body = t.pending:sub(header_end + skip)
                t.pending = ""
                t.headers_done = true
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
