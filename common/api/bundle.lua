--[[ Cached session bundle helpers. ]]

local state = require("common.api.state")
local profile = require("common.api.profile")

local bundle = {}

function bundle.apply_bundle(data, car_filter)
    if data == nil or data.ok ~= true then return false end
    state.cached_bundle = data
    state.cached_filter = car_filter or "global"
    state.cached_at = os.clock()
    state.fetch_attempt = 0
    state.server_name_candidates = nil
    return true
end

function bundle.bundle_needs_profile()
    if state.cached_bundle == nil or state.cached_bundle.ok ~= true then return false end
    if profile.coalesce_profile(state.cached_bundle.profile) ~= nil then return false end
    if state.last_error == "user_not_found" then return false end
    return true
end

function bundle.merge_profile_into_bundle(p)
    p = profile.coalesce_profile(p)
    if state.cached_bundle == nil or p == nil then return false end
    state.cached_bundle.profile = p
    if p.rival == nil and state.cached_bundle.leaderboard ~= nil then
        local derived = profile.derive_rival_from_leaderboard(p, state.cached_bundle.leaderboard)
        if derived ~= nil then
            state.cached_bundle.profile.rival = derived
        end
    end
    return true
end

return bundle
