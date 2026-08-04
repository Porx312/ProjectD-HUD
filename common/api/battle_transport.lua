--[[ Unified HUD transport: one SSE stream (session + battle) via GET /hud/stream. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local battle_fetch = require("common.api.battle_fetch")
local battle_sse = require("common.api.battle_sse")

local hud_transport = {}

local API_KEY_STORAGE = ac.storage("ProjectD-HUD:api_key", "")

local function api_key_suffix()
    local key = util.safe_str(API_KEY_STORAGE:get())
    if key == "" then return "" end
    return "&api_key=" .. util.url_encode(key)
end

local function stream_url(ctx)
    local qs = "steamId=" .. util.url_encode(ctx.player_steam_id)
        .. "&carFilter=global"
    local car = util.safe_str(ctx.car_id)
    if car ~= "" then
        qs = qs .. "&carModel=" .. util.url_encode(car)
    end
    qs = qs .. api_key_suffix()
    return string.format(
        "%s%s?%s",
        config.API_BASE_URL,
        config.HUD_STREAM_PATH or "/hud/stream",
        qs
    )
end

local function should_retry_disconnect(err_reason, response)
    if err_reason == "user_invalidated" then return false end
    if util.is_presence_fatal(err_reason) then
        return battle_fetch.is_session_live() or util.ignore_presence_error(err_reason)
    end
    if util.is_battle_fatal(err_reason) then return false end
    if err_reason ~= nil and err_reason ~= "" then
        if err_reason == "network_error" then return true end
        if string.sub(err_reason, 1, 4) == "http" then
            return err_reason == "http_502" or err_reason == "http_503" or err_reason == "http_504"
        end
    end
    local code = util.http_status_code(response)
    return code == 502 or code == 503 or code == 504
end

local function disconnect_sse_only()
    battle_sse.disconnect()
    state.battle_sse_session_key = ""
end

local function disconnect_and_clear(_ctx, _now)
    disconnect_sse_only()
    battle_fetch.reset()
    state.hud_waiting_reason = nil
end

local function session_key(ctx)
    return util.safe_str(ctx.player_steam_id) .. "|" .. util.safe_str(ctx.car_id)
end

function hud_transport.try_connect(ctx, now)
    now = now or os.clock()
    if ctx.is_online ~= true then return false end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" then return false end

    if battle_sse.is_active() then return true end
    if util.is_battle_fatal(state.battle_last_error)
        and not (util.is_presence_fatal(state.battle_last_error) and battle_fetch.is_session_live(now)) then
        return false
    end
    if now < (state.battle_sse_reconnect_at or 0) then return false end

    local url = stream_url(ctx)
    local sse_ctx = {
        player_steam_id = ctx.player_steam_id,
        _sse_on_close = function(_err, response)
            local reason = state.battle_last_error
            if should_retry_disconnect(reason, response) then
                state.battle_sse_reconnect_at = now + (config.HUD_SSE_RECONNECT_SEC or 3)
                battle_fetch.debug("hud sse reconnect scheduled")
            end
        end,
    }

    if battle_sse.connect(url, sse_ctx) then
        state.battle_sse_session_key = session_key(ctx)
        state.battle_sse_connected_at = now
        battle_fetch.debug("hud sse steamId=" .. ctx.player_steam_id)
        return true
    end

    return false
end

function hud_transport.tick(ctx, now)
    now = now or os.clock()
    battle_fetch.tick_latch(now)

    if ctx.is_online ~= true then
        if battle_sse.is_active() or state.battle_sse_session_key ~= "" then
            disconnect_and_clear(ctx, now)
        end
        return
    end

    if state.last_error == "user_invalidated" then
        if battle_sse.is_active() then
            disconnect_and_clear(ctx, now)
        end
        return
    end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)

    if ctx.player_steam_id == "" then
        if battle_sse.is_active() then
            battle_sse.poll()
        end
        return
    end

    local key = session_key(ctx)
    if state.battle_sse_session_key ~= "" and state.battle_sse_session_key ~= key then
        battle_fetch.debug("hud sse context changed -> reconnect")
        battle_sse.disconnect()
        state.battle_sse_reconnect_at = 0
        state.battle_sse_session_key = ""
    end

    if battle_sse.is_active() then
        battle_sse.poll()
    else
        hud_transport.try_connect(ctx, now)
    end
end

function hud_transport.mode(_ctx, _now)
    if battle_sse.is_active() and util.safe_str(state.hud_transport) == "tcp" then
        return "tcp"
    end
    if util.safe_str(state.hud_transport) == "poll" then
        return "poll"
    end
    if battle_sse.is_active() then
        return "tcp"
    end
    if state.cached_bundle ~= nil or state.snapshot_inflight then
        return "poll"
    end
    return "off"
end

function hud_transport.is_live(_ctx, now)
    now = now or os.clock()
    if battle_sse.is_active() then
        local last = state.battle_sse_last_activity_at or state.battle_sse_connected_at or 0
        if last > 0 and (now - last) <= (config.HUD_SSE_LIVE_SEC or 5) then
            return true
        end
        if state.hud_transport == "tcp" then
            return true
        end
    end
    return false
end

function hud_transport.session_age(_ctx, now)
    now = now or os.clock()
    local at = tonumber(state.cached_at) or 0
    if at <= 0 then return nil end
    return now - at
end

function hud_transport.reset()
    battle_sse.disconnect()
    battle_fetch.reset()
    state.battle_sse_session_key = ""
    state.battle_sse_reconnect_at = 0
    state.battle_sse_connected_at = 0
    state.hud_waiting_reason = nil
end

return hud_transport
