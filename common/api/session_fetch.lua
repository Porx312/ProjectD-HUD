--[[ Apply session:update / session:error from unified HUD SSE stream. ]]

local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local parse = require("common.api.parse")
local bundle = require("common.api.bundle")

local session_fetch = {}

local function hud_debug(msg)
    ac.debug("ProjectD-HUD session", util.safe_str(msg))
end

function session_fetch.apply_error(raw)
    if raw == nil or type(raw) ~= "table" then return end
    local reason = util.safe_str(raw.reason)
    if reason == "user_invalidated" then
        bundle.invalidate_user()
        state.last_error = "user_invalidated"
        return
    end
    if reason ~= "" then
        util.apply_presence_error(reason)
    end
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
        state.hud_version = ver
    end

    local data = parse.normalize_session_response(raw, steam_id)
    if data == nil then return end

    bundle.apply_bundle(data)
    util.note_presence_ok()
    state.battle_sse_last_activity_at = os.clock()
    hud_debug("update v=" .. ver)
end

return session_fetch
