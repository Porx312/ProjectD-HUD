--[[ Battle HUD transport: one SSE stream per session, reconnect on error. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local battle_fetch = require("common.api.battle_fetch")
local battle_sse = require("common.api.battle_sse")
local web_queue = require("common.api.web_queue")

local battle_transport = {}

local API_KEY_STORAGE = ac.storage("ProjectD-HUD:api_key", "")

local function api_key_suffix()
    local key = util.safe_str(API_KEY_STORAGE:get())
    if key == "" then return "" end
    return "&api_key=" .. util.url_encode(key)
end

local function stream_url(server_name, steam_id)
    return string.format(
        "%s%s?serverName=%s&steamId=%s%s",
        config.API_BASE_URL,
        config.BATTLE_STREAM_PATH or "/hud/battle/stream",
        util.url_encode(server_name),
        util.url_encode(steam_id),
        api_key_suffix()
    )
end

local function server_candidates(ctx, force_new_cycle)
    if not force_new_cycle and state.battle_server_candidates ~= nil and #state.battle_server_candidates > 0 then
        return state.battle_server_candidates
    end
    state.battle_server_candidates = context.build_server_name_candidates(ctx)
    state.battle_sse_server_attempt = 0
    return state.battle_server_candidates
end

local function try_next_server(candidates)
    local attempt = state.battle_sse_server_attempt or 0
    if attempt < #candidates then
        state.battle_sse_server_attempt = attempt + 1
        return true
    end
    state.battle_server_candidates = nil
    state.battle_sse_server_attempt = 0
    return false
end

local function should_retry_disconnect(err_reason, response)
    if err_reason ~= nil and err_reason ~= "" then
        if err_reason == "network_error" then return true end
        if string.sub(err_reason, 1, 4) == "http" then
            return err_reason == "http_502" or err_reason == "http_503" or err_reason == "http_504"
        end
    end
    local code = util.http_status_code(response)
    return code == 502 or code == 503 or code == 504
end

local function disconnect_and_clear(ctx, now)
    battle_sse.disconnect()
    battle_fetch.reset()
    state.battle_sse_session_key = ""
end

local function session_key(ctx)
    local server = util.safe_str(state.battle_last_resolved_server_name)
    if server == "" then server = util.safe_str(state.battle_last_server_tried) end
    if server == "" then
        local candidates = state.battle_server_candidates
        if candidates ~= nil and #candidates > 0 then
            server = util.safe_str(candidates[1])
        end
    end
    return util.safe_str(ctx.player_steam_id) .. "|" .. server
end

function battle_transport.try_connect(ctx, now)
    now = now or os.clock()
    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" then return false end

    if battle_sse.is_active() then return true end
    if now < (state.battle_sse_reconnect_at or 0) then return false end

    local candidates = server_candidates(ctx, state.battle_server_candidates == nil)
    if #candidates == 0 then
        state.battle_last_error = "missing_server_name"
        return false
    end

    if state.battle_sse_server_attempt <= 0 then
        state.battle_sse_server_attempt = 1
    end

    local server_name = candidates[state.battle_sse_server_attempt]
    if server_name == nil then
        state.battle_sse_server_attempt = 0
        state.battle_server_candidates = nil
        return false
    end

    state.battle_last_server_tried = server_name
    local url = stream_url(server_name, ctx.player_steam_id)
    local sse_ctx = {
        player_steam_id = ctx.player_steam_id,
        _sse_on_close = function(err, response)
            local reason = state.battle_last_error
            if should_retry_disconnect(reason, response) and try_next_server(candidates) then
                state.battle_sse_reconnect_at = now
                battle_fetch.debug("sse retry next server")
            end
        end,
    }

    if battle_sse.connect(url, sse_ctx) then
        state.battle_last_resolved_server_name = server_name
        state.battle_sse_session_key = session_key(ctx)
        return true
    end

    return false
end

function battle_transport.tick(ctx, now)
    now = now or os.clock()
    battle_fetch.tick_latch(now)

    if not context.battle_context_ready(ctx) then
        if battle_sse.is_active() or state.battle_sse_session_key ~= "" then
            disconnect_and_clear(ctx, now)
        end
        return
    end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)

    local key = session_key(ctx)
    if state.battle_sse_session_key ~= "" and state.battle_sse_session_key ~= key then
        battle_fetch.debug("session changed -> reconnect sse")
        battle_sse.disconnect()
        state.battle_sse_reconnect_at = 0
        state.battle_server_candidates = nil
        state.battle_sse_session_key = ""
    end

    if battle_sse.is_active() then
        web_queue.poll_stream()
    else
        battle_transport.try_connect(ctx, now)
    end
end

function battle_transport.reset()
    battle_sse.disconnect()
    battle_fetch.reset()
    state.battle_sse_session_key = ""
    state.battle_sse_server_attempt = 0
    state.battle_sse_reconnect_at = 0
end

return battle_transport
