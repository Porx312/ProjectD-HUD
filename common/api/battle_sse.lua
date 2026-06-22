--[[ SSE client for GET /hud/battle/stream — parser + web.get stream hook. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local web_queue = require("common.api.web_queue")
local battle_fetch = require("common.api.battle_fetch")

local battle_sse = {}

local function trim_line(s)
    s = util.safe_str(s)
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function dispatch_event(event_name, data_str, ctx)
    local now = os.clock()
    local payload = util.parse_json_body(data_str)
    if payload == nil then
        battle_fetch.debug("sse json parse fail: " .. string.sub(data_str, 1, 80))
        return
    end

    event_name = trim_line(event_name)
    if event_name == "" then
        if payload.ok == false then
            event_name = "battle:clear"
        else
            event_name = "battle:update"
        end
    end

    if event_name == "battle:update" then
        if payload.ok == false then
            battle_fetch.handle_battle_clear(payload, now)
            return
        end
        battle_fetch.apply_snapshot(payload, ctx.player_steam_id, now)
        return
    end

    if event_name == "battle:clear" then
        battle_fetch.handle_battle_clear(payload, now)
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
            -- comment / keepalive
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
    state.battle_sse_connected = false
    state.battle_sse_stream_pending = false
    state.battle_sse_buffer = ""
    state.battle_sse_last_body_len = 0

    local now = os.clock()
    local reconnect = config.BATTLE_SSE_RECONNECT_SEC or 3
    state.battle_sse_reconnect_at = now + reconnect

  if util.is_web_error(err) then
        state.battle_last_error = "network_error"
        battle_fetch.debug("sse closed err=" .. tostring(err))
    else
        local code = util.http_status_code(response)
        if code ~= nil and code ~= 200 then
            state.battle_last_error = "http_" .. tostring(code)
            battle_fetch.debug("sse closed http=" .. tostring(code))
        else
            battle_fetch.debug("sse closed (reconnect in " .. tostring(reconnect) .. "s)")
        end
    end

    if ctx ~= nil and ctx._sse_on_close ~= nil then
        pcall(ctx._sse_on_close, err, response)
    end
end

--- Incremental body growth when CSP delivers full response object each tick.
local function on_stream_response(err, response, ctx, item)
    if util.is_web_error(err) then
        on_stream_closed(err, response, ctx)
        return
    end

    local code = util.http_status_code(response)
    if code ~= nil and code ~= 200 then
        on_stream_closed(err, response, ctx)
        return
    end

    state.battle_sse_connected = true
    state.battle_sse_stream_pending = false
    state.battle_last_error = nil

    local body = util.response_body(response)
    if body == nil or body == "" then return end

    local prev_len = state.battle_sse_last_body_len or 0
    local total_len = #body
    if total_len > prev_len then
        local delta = body:sub(prev_len + 1)
        state.battle_sse_last_body_len = total_len
        battle_sse.feed(delta, ctx)
    end

    if response ~= nil and response.complete == false then
        return
    end

    if response ~= nil and response.finished == false then
        return
    end

    if item ~= nil and item.expect_persistent == true then
        return
    end

    on_stream_closed(nil, response, ctx)
end

function battle_sse.connect(url, ctx, opts)
    opts = opts or {}
    if state.battle_sse_stream_pending or state.battle_sse_connected then
        return false
    end

    ctx = ctx or {}
    state.battle_sse_stream_pending = true
    state.battle_sse_buffer = ""
    state.battle_sse_last_body_len = 0
    state.last_fetch_url = url
    battle_fetch.debug("sse connect " .. url)

    local item = {
        url = url,
        kind = "battle_sse",
        expect_persistent = true,
        ctx = ctx,
        callbacks = {
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
        battle_fetch.debug("sse connect deferred (web busy)")
        return false
    end

    return true
end

function battle_sse.disconnect()
    web_queue.close_stream("battle_sse")
    state.battle_sse_connected = false
    state.battle_sse_stream_pending = false
    state.battle_sse_buffer = ""
    state.battle_sse_last_body_len = 0
    state.battle_sse_reconnect_at = 0
end

function battle_sse.is_active()
    return state.battle_sse_connected == true
        or state.battle_sse_stream_pending == true
        or state.web_stream ~= nil
end

return battle_sse
