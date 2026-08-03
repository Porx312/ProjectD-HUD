--[[ Cached session bundle (profile + context + rivals from hud_session SSE). ]]

local state = require("common.api.state")
local util = require("common.api.util")

local bundle = {}
local profile = require("common.api.profile")

function bundle.apply_bundle(data)
    if data == nil or data.ok ~= true then return false end

    local coalesced = profile.coalesce_profile(data.profile)
    if coalesced == nil or coalesced.isInvalidated == true then
        return false
    end
    data.profile = coalesced

    state.cached_bundle = data
    state.cached_at = os.clock()
    state.session_seq = (state.session_seq or 0) + 1
    if state.last_error ~= "user_invalidated" then
        state.last_error = nil
    end
    return true
end

function bundle.clear_cache()
    state.cached_bundle = nil
    state.cached_at = 0
end

function bundle.invalidate_user()
    state.last_error = "user_invalidated"
    if state.cached_bundle ~= nil then
        state.cached_bundle.profile = nil
    end
end

return bundle
