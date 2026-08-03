--[[ SSE client: TCP stream (primary) + web.get fallback. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local web_queue = require("common.api.web_queue")
local battle_fetch = require("common.api.battle_fetch")
local session_fetch = require("common.api.session_fetch")
local battle_sse_tcp = require("common.api.battle_sse_tcp")

local battle_sse = {}

local function trim_line(s)
    s = util.safe_str(s)
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize_payload(payload)
    if payload == nil then return nil end
    if type(payload) == "string" then
        return util.parse_json_body(payload)
    end
    if type(payload) ~= "table" then return nil end
    if payload.snapshot ~= nil and type(payload.snapshot) == "table" then
        return payload.snapshot
    end
    if payload.data ~= nil and type(payload.data) == "table" then
        local d = payload.data
        if d.state ~= nil or d.battleId ~= nil or d.player1 ~= nil then
            return d
        end
    end
    return payload
end

local function infer_event_name(payload)
    if payload == nil or type(payload) ~= "table" then return nil end

    if payload.ok == false and payload.players == nil
        and (payload.reason ~= nil or payload.error ~= nil) then
        return "hud_error"
    end

    if payload.players ~= nil then
        return "hud_session"
    end

    -- Convex session bundle uses root profile/context (no players[]).
    if payload.profile ~= nil or payload.context ~= nil then
        return "hud_session"
    end

    if payload.ok == true and payload.version ~= nil then
        return "hud_session"
    end

    if payload.version ~= nil and payload.state == nil and payload.battleId == nil
        and payload.player1 == nil and payload.players == nil then
        return "hud_version"
    end

    if payload.ok == false and (payload.state ~= nil or payload.battleId ~= nil) then
        return "battle"
    end

    if payload.state ~= nil or payload.battleId ~= nil or payload.player1 ~= nil then
        return "battle"
    end

    return nil
end

local function canonical_event_name(event_name, payload)
    event_name = trim_line(event_name)
    if event_name == "message" then event_name = "" end

    if event_name ~= "" then
        if event_name == "session:update" then return "hud_session" end
        if event_name == "session:error" then return "hud_error" end
        if event_name == "hud_session" then return "hud_session" end
        if event_name == "hud_error" then return "hud_error" end
        if event_name == "hud_version" then return "hud_version" end
        if event_name == "battle:update" or event_name == "battle:clear" then return "battle" end
        return event_name
    end

    return infer_event_name(payload)
end

local function dispatch_event(event_name, data_str, ctx)
    local now = os.clock()
    local payload = normalize_payload(util.parse_json_body(data_str))
    if payload == nil then
        battle_fetch.debug("sse json parse fail: " .. string.sub(data_str, 1, 120))
        return
    end

    event_name = canonical_event_name(event_name, payload)
    if event_name == nil then
        battle_fetch.debug("sse unknown payload")
        return
    end

    state.battle_last_event_name = event_name
    battle_fetch.debug("sse evt=" .. event_name)
    local steam_id = ctx ~= nil and ctx.player_steam_id or state.battle_sse_steam_id or ""

    if event_name == "hud_version" then
        session_fetch.apply_version(payload)
        return
    end

    if event_name == "hud_session" then
        session_fetch.apply_update(payload, steam_id)
        return
    end

    if event_name == "hud_error" then
        session_fetch.apply_error(payload)
        return
    end

    if event_name == "battle" then
        if payload.ok == false then
            battle_fetch.handle_battle_clear(payload, now)
            return
        end
        battle_fetch.apply_snapshot(payload, steam_id, now)
        return
    end

    battle_fetch.debug("sse unknown event: " .. event_name)
end

local function process_event_block(block, ctx)
    if block == nil or block == "" then return end

    local event_name = nil
    local data_lines = {}

    for line in string.gmatch(block, "[^\r\n]+") do
        if line:sub(1, 1) == ":" then
            -- keepalive
        elseif line:sub(1, 6) == "event:" then
            event_name = trim_line(line:sub(7))
        elseif line:sub(1, 5) == "data:" then
            data_lines[#data_lines + 1] = trim_line(line:sub(6))
        end
    end

    local data_str = table.concat(data_lines, "\n")
    if data_str == "" then return end
    dispatch_event(event_name, data_str, ctx)
end

function battle_sse.feed(chunk, ctx)
    if chunk == nil or chunk == "" then return end
    ctx = ctx or state.battle_sse_ctx
    if ctx == nil then return end

    state.battle_sse_buffer = (state.battle_sse_buffer or "") .. chunk
    local buffer = state.battle_sse_buffer

    while true do
        local sep = buffer:find("\n\n", 1, true)
        if sep == nil then
            local crlf = buffer:find("\r\n\r\n", 1, true)
            if crlf == nil then break end
            local block = buffer:sub(1, crlf - 1)
            buffer = buffer:sub(crlf + 4)
            process_event_block(block, ctx)
        else
            local block = buffer:sub(1, sep - 1)
            buffer = buffer:sub(sep + 2)
            process_event_block(block, ctx)
        end
    end

    state.battle_sse_buffer = buffer
end

local function on_stream_chunk(chunk, ctx)
    if chunk == nil then return end
    state.battle_sse_connected = true
    state.battle_sse_stream_pending = false
    if type(chunk) == "table" then
        local body = util.response_body(chunk)
        if body ~= nil and body ~= "" then
            battle_sse.feed(body, ctx)
        end
        return
    end
    if type(chunk) == "string" and chunk ~= "" then
        battle_fetch.debug("sse chunk " .. tostring(#chunk) .. "b")
        battle_sse.feed(chunk, ctx)
    end
end

local function on_stream_closed(err, response, ctx)
    if state.battle_sse_mode == "tcp" then return end

    state.battle_sse_connected = false
    state.battle_sse_stream_pending = false
    state.battle_sse_buffer = ""
    state.battle_sse_last_body_len = 0

    local now = os.clock()
    local reconnect = config.HUD_SSE_RECONNECT_SEC or 3

    if util.is_web_error(err) then
        state.battle_last_error = "network_error"
        battle_fetch.debug("sse closed err=" .. tostring(err))
    else
        local _, err_reason = util.read_api_response(err, response)
        if err_reason ~= nil then
            if util.should_ignore_error(err_reason) then
                battle_fetch.debug("sse ignored: " .. tostring(err_reason))
            elseif util.ignore_presence_error(err_reason) then
                battle_fetch.debug("sse presence ignored: " .. tostring(err_reason))
            else
                state.battle_last_error = err_reason
                state.last_error = err_reason
                battle_fetch.debug("sse closed reason=" .. tostring(err_reason))
            end
        else
            local code = util.http_status_code(response)
            if code ~= nil and code ~= 200 then
                state.battle_last_error = "http_" .. tostring(code)
                if code == 404 then
                    state.last_error = "player_not_connected"
                end
                battle_fetch.debug("sse closed http=" .. tostring(code))
            else
                battle_fetch.debug("sse closed (reconnect in " .. tostring(reconnect) .. "s)")
            end
        end
    end

    local block_reconnect = util.is_battle_fatal(state.battle_last_error)
        and not (util.is_presence_fatal(state.battle_last_error) and battle_fetch.is_session_live(now))
    if block_reconnect then
        state.battle_sse_reconnect_at = math.huge
    else
        state.battle_sse_reconnect_at = now + reconnect
    end

    if ctx ~= nil and ctx._sse_on_close ~= nil then
        pcall(ctx._sse_on_close, err, response)
    end
end

local function on_stream_response(err, response, ctx, item)
    if util.is_web_error(err) then
        on_stream_closed(err, response, ctx)
        return
    end

    local code = util.http_status_code(response)
    if code ~= nil and code ~= 200 then
        local _, err_reason = util.read_api_response(err, response)
        if err_reason ~= nil and not util.should_ignore_error(err_reason) and not util.ignore_presence_error(err_reason) then
            state.battle_last_error = err_reason
            state.last_error = err_reason
        elseif code == 404 then
            state.battle_last_error = "http_404"
            state.last_error = "player_not_connected"
        end
        on_stream_closed(err, response, ctx)
        return
    end

    state.battle_sse_connected = true
    state.battle_sse_stream_pending = false
    state.battle_last_error = nil
    state.battle_sse_last_activity_at = os.clock()

    local body = util.response_body(response)
    if body == nil or body == "" then return end

    local prev_len = state.battle_sse_last_body_len or 0
    local total_len = #body
    if total_len > prev_len then
        local delta = body:sub(prev_len + 1)
        state.battle_sse_last_body_len = total_len
        battle_sse.feed(delta, ctx)
    end

    if response ~= nil and response.complete == false then return end
    if response ~= nil and response.finished == false then return end
    if item ~= nil and item.expect_persistent == true then return end

    on_stream_closed(nil, response, ctx)
end

local function connect_web(url, ctx)
    if state.battle_sse_stream_pending or (state.battle_sse_connected and state.web_stream ~= nil) then
        return false
    end

    state.battle_sse_stream_pending = true
    state.battle_sse_buffer = ""
    state.battle_sse_last_body_len = 0
    state.battle_sse_mode = "web"
    state.battle_sse_web_stall_at = 0
    state.battle_sse_last_activity_at = 0
    state.last_fetch_url = url
    battle_fetch.debug("hud sse web connect " .. url)

    local item = {
        url = url,
        kind = "hud_sse",
        expect_persistent = true,
        ctx = ctx,
        callbacks = {
            on_open = function()
                state.battle_sse_connected = true
                state.battle_sse_stream_pending = false
                state.battle_last_error = nil
                battle_fetch.debug("hud sse web stream open")
            end,
            on_chunk = function(chunk)
                on_stream_chunk(chunk, ctx)
            end,
            on_response = function(err, response)
                on_stream_response(err, response, ctx, item)
            end,
            on_complete = function(err, response)
                on_stream_closed(err, response, ctx)
            end,
        },
    }

    local opened = web_queue.open_stream(item)
    if not opened then
        state.battle_sse_stream_pending = false
        state.battle_sse_mode = nil
        battle_fetch.debug("sse web deferred (web busy)")
        return false
    end

    state.battle_sse_connected = true
    state.battle_sse_stream_pending = false
    state.battle_sse_connected_at = os.clock()
    return true
end

local WEB_SSE_STALL_SEC = 8

local function try_tcp_connect(url, ctx)
    if not battle_sse_tcp.can_connect(url) then
        return false
    end
    if battle_sse_tcp.connect(url, ctx) then
        state.battle_sse_connected = true
        state.battle_sse_stream_pending = false
        state.battle_sse_connected_at = os.clock()
        state.battle_sse_last_activity_at = 0
        state.battle_sse_web_stall_at = 0
        state.battle_last_error = nil
        return true
    end
    return false
end

function battle_sse.connect(url, ctx)
    ctx = ctx or {}
    state.battle_sse_ctx = ctx
    state.battle_sse_steam_id = util.safe_str(ctx.player_steam_id)

    if try_tcp_connect(url, ctx) then
        return true
    end

    battle_fetch.debug("sse tcp unavailable or failed, trying web stream")
    return connect_web(url, ctx)
end

function battle_sse.disconnect()
    battle_sse_tcp.disconnect()
    web_queue.close_stream("hud_sse")
    state.battle_sse_connected = false
    state.battle_sse_stream_pending = false
    state.battle_sse_buffer = ""
    state.battle_sse_last_body_len = 0
    state.battle_sse_web_stall_at = 0
    state.battle_sse_mode = nil
end

function battle_sse.poll()
    if state.battle_sse_mode == "tcp" then
        battle_sse_tcp.poll(battle_sse.feed)
        return
    end

    web_queue.poll_stream()

    if state.battle_sse_mode ~= "web" or not state.battle_sse_connected then
        return
    end

    local now = os.clock()
    local connected_at = state.battle_sse_connected_at or 0
    local last_activity = state.battle_sse_last_activity_at or 0
    if connected_at <= 0 or last_activity > 0 then return end
    if (now - connected_at) < WEB_SSE_STALL_SEC then return end
    if (state.battle_sse_web_stall_at or 0) >= connected_at then return end

    state.battle_sse_web_stall_at = now
    local url = util.safe_str(state.last_fetch_url)
    local ctx = state.battle_sse_ctx
    battle_fetch.debug("sse web stalled — retry tcp")

    battle_sse.disconnect()
    state.battle_sse_reconnect_at = 0
    state.battle_sse_connected_at = 0

    if url ~= "" and ctx ~= nil and try_tcp_connect(url, ctx) then
        return
    end

    state.battle_sse_reconnect_at = now + (config.HUD_SSE_RECONNECT_SEC or 3)
end

function battle_sse.is_active()
    return battle_sse_tcp.is_active()
        or state.battle_sse_connected == true
        or state.battle_sse_stream_pending == true
        or state.web_stream ~= nil
end

return battle_sse
