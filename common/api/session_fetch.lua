--[[ Apply hud_session / hud_version / hud_error from unified HUD SSE stream. ]]

local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local parse = require("common.api.parse")
local bundle = require("common.api.bundle")

local session_fetch = {}

local TRANSIENT_WAIT_REASONS = {
    player_not_connected = true,
    server_not_found = true,
    track_not_found = true,
    car_not_found = true,
}

function session_fetch.apply_error(raw)
    if raw == nil or type(raw) ~= "table" then return end
    local reason = util.safe_str(raw.reason)
    if reason == "user_invalidated" then
        bundle.invalidate_user()
        state.last_error = "user_invalidated"
        state.hud_waiting_reason = nil
        return
    end
    if TRANSIENT_WAIT_REASONS[reason] then
        state.hud_waiting_reason = reason
        state.last_error = nil
        state.battle_sse_last_activity_at = os.clock()
        return
    end
    if reason ~= "" then
        state.hud_waiting_reason = nil
        util.apply_presence_error(reason)
    end
end

function session_fetch.apply_version(raw)
    if raw == nil or type(raw) ~= "table" then return end

    if raw.profile ~= nil or raw.context ~= nil or raw.ok == true then
        local steam_id = steam.normalize_steam_id(raw.steamId or state.battle_sse_steam_id or "")
        session_fetch.apply_update(raw, steam_id)
        return
    end

    local ver = util.safe_str(raw.version)
    if ver == "" then return end

    -- Board version from getHudVersion; never clear cached_bundle here — hud_session
    -- uses a different version string and always follows in the same push.
    state.hud_version = ver
    local lb = util.safe_str(raw.lbVersion)
    if lb ~= "" then
        state.hud_lb_version = lb
    end
    state.battle_sse_last_activity_at = os.clock()
end

function session_fetch.apply_update(raw, steam_id)
    if raw == nil or type(raw) ~= "table" then return end
    steam_id = steam.normalize_steam_id(steam_id)

    if raw.ok == false then
        session_fetch.apply_error(raw)
        return
    end

    local ver = util.safe_str(raw.version)
    if ver ~= "" then
        local prev = util.safe_str(state.session_version)
        if prev ~= "" and prev ~= ver then
            bundle.clear_cache()
        end
        state.session_version = ver
    end

    local ok_parse, data = pcall(parse.normalize_session_response, raw, steam_id)
    if not ok_parse then
        state.last_error = "parse_error"
        return
    end
    if data == nil then return end

    bundle.apply_bundle(data)
    util.note_presence_ok()
    state.hud_waiting_reason = nil
    state.battle_sse_last_activity_at = os.clock()
end

return session_fetch
