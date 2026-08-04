--[[ One-shot GET /hud/snapshot fallback when CSP web.get cannot stream SSE. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local web_queue = require("common.api.web_queue")
local session_fetch = require("common.api.session_fetch")
local battle_fetch = require("common.api.battle_fetch")
local battle_sse = require("common.api.battle_sse")

local session_snapshot = {}

local API_KEY_STORAGE = ac.storage("ProjectD-HUD:api_key", "")

local function api_key_suffix()
    local key = util.safe_str(API_KEY_STORAGE:get())
    if key == "" then return "" end
    return "&api_key=" .. util.url_encode(key)
end

local function snapshot_url(ctx)
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
        config.HUD_SNAPSHOT_PATH or "/hud/snapshot",
        qs
    )
end

local function battle_poll_active()
    if state.battle_ui ~= nil then return true end
    local snap_at = state.battle_last_snapshot_at or 0
    if snap_at > 0 then
        return (os.clock() - snap_at) < (config.HUD_SNAPSHOT_POLL_SEC or 5)
    end
    return false
end

local function poll_interval()
    if battle_poll_active() then
        return config.HUD_SNAPSHOT_BATTLE_POLL_SEC or 2
    end
    return config.HUD_SNAPSHOT_POLL_SEC or 5
end

local function sse_recently_active(now)
    local last = state.battle_sse_last_activity_at or 0
    return last > 0 and (now - last) < poll_interval()
end

local function should_poll(ctx, now)
    if ctx.is_online ~= true then return false end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" then return false end

    if state.last_error == "user_invalidated" then return false end

    if state.cached_bundle ~= nil then
        if battle_sse.is_active() and sse_recently_active(now) then
            return false
        end
        return now >= (state.snapshot_poll_at or 0)
    end

    if battle_sse.is_active() and sse_recently_active(now) then
        return false
    end

    return now >= (state.snapshot_poll_at or 0)
end

local function apply_snapshot_body(raw, steam_id)
    if raw == nil or type(raw) ~= "table" then
        state.last_error = "json_parse_failed"
        return
    end

    if raw.ok == false then
        local reason = util.safe_str(raw.reason)
        if reason ~= "" then
            session_fetch.apply_error({ reason = reason, steamId = steam_id })
        end
        return
    end

    local version = raw.version
    if version ~= nil and type(version) == "table" then
        session_fetch.apply_version(version)
    end

    local session = raw.session
    if session ~= nil and type(session) == "table" then
        session_fetch.apply_update(session, steam_id)
    end

    local battle = raw.battle
    local now = os.clock()
    if battle ~= nil and type(battle) == "table" then
        if battle.ok == false then
            local reason = util.safe_str(battle.reason)
            if reason == "no_battle" or reason == "" then
                battle_fetch.handle_battle_clear(battle, now)
            end
        else
            battle_fetch.apply_snapshot(battle, steam_id, now)
            battle_fetch.debug("hud snapshot battle state=" .. util.safe_str(battle.state))
        end
    end

    if state.cached_bundle ~= nil then
        state.hud_transport = "poll"
        state.battle_last_error = nil
        battle_fetch.debug("hud snapshot applied")
    end
end

local function on_snapshot_response(err, response, ctx)
    state.snapshot_inflight = false
    state.snapshot_poll_at = os.clock() + poll_interval()

    if util.is_web_error(err) then
        state.last_error = "network_error"
        battle_fetch.debug("hud snapshot network err")
        return
    end

    local code = util.http_status_code(response)
    if code ~= nil and code ~= 200 then
        local _, err_reason = util.read_api_response(err, response)
        if err_reason ~= nil and not util.should_ignore_error(err_reason) then
            session_fetch.apply_error({ reason = err_reason, steamId = ctx.player_steam_id })
            state.last_error = err_reason
        elseif code == 404 then
            state.hud_waiting_reason = "player_not_connected"
            state.last_error = nil
        end
        battle_fetch.debug("hud snapshot http=" .. tostring(code))
        return
    end

    local body = util.response_body(response)
    local raw = util.parse_json_body(body)
    apply_snapshot_body(raw, ctx.player_steam_id)
end

function session_snapshot.tick(ctx, now)
    now = now or os.clock()

    if ctx.is_online ~= true then
        state.snapshot_inflight = false
        return
    end

    if state.snapshot_inflight then return end
    if not should_poll(ctx, now) then return end

    state.snapshot_inflight = true
    state.snapshot_poll_at = now + poll_interval()
    local url = snapshot_url(ctx)
    state.last_fetch_url = url
    state.last_fetch_kind = "hud_snapshot"
    battle_fetch.debug("hud snapshot poll " .. url)

    web_queue.get(url, "hud_snapshot", function(err, response)
        on_snapshot_response(err, response, ctx)
    end)
end

function session_snapshot.reset()
    state.snapshot_poll_at = 0
    state.snapshot_inflight = false
    if state.hud_transport == "poll" then
        state.hud_transport = ""
    end
end

return session_snapshot
