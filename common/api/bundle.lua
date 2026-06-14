--[[ Cached session bundle + per-car leaderboard cache. ]]

local config = require("common.config")
local state = require("common.api.state")
local profile = require("common.api.profile")

local bundle = {}

local function filter_ttl()
    return config.FILTER_CACHE_TTL_SEC or config.CACHE_TTL_SEC or 60
end

local function ensure_filter_bundles()
    if state.filter_bundles == nil then state.filter_bundles = {} end
end

function bundle.store_filter_leaderboard(car_filter, leaderboard)
    if leaderboard == nil then return end
    ensure_filter_bundles()
    state.filter_bundles[car_filter or "global"] = {
        leaderboard = leaderboard,
        cached_at = os.clock(),
    }
end

function bundle.get_filter_leaderboard(car_filter)
    car_filter = car_filter or "global"
    ensure_filter_bundles()

    local cached = state.filter_bundles[car_filter]
    if cached ~= nil and cached.leaderboard ~= nil then
        if (os.clock() - (cached.cached_at or 0)) <= filter_ttl() then
            return cached.leaderboard
        end
        state.filter_bundles[car_filter] = nil
    end

    if car_filter == "global"
        and state.cached_bundle ~= nil
        and state.cached_bundle.leaderboard ~= nil
        and (os.clock() - state.cached_at) <= filter_ttl() then
        return state.cached_bundle.leaderboard
    end

    return nil
end

function bundle.apply_bundle(data, car_filter)
    if data == nil or data.ok ~= true then return false end

    car_filter = car_filter or "global"
    if data.leaderboard ~= nil then
        bundle.store_filter_leaderboard(car_filter, data.leaderboard)
    end

    state.cached_bundle = data
    state.cached_filter = "global"
    state.cached_at = os.clock()
    state.last_hud_refresh_at = state.cached_at
    state.last_hud_backup_sync_at = state.cached_at
    state.fetch_attempt = 0
    state.server_name_candidates = nil
    state.fetch_car_filter = nil
    state.last_error = nil
    return true
end

function bundle.merge_top10(car_filter, raw, leaderboard)
    if leaderboard == nil then return false end
    car_filter = car_filter or "global"
    bundle.store_filter_leaderboard(car_filter, leaderboard)

    if car_filter == "global" then
        if state.cached_bundle == nil then
            state.cached_bundle = { ok = true }
        end
        state.cached_bundle.ok = true
        state.cached_bundle.leaderboard = leaderboard
        state.cached_at = os.clock()
        state.last_hud_refresh_at = state.cached_at
        state.last_hud_backup_sync_at = state.cached_at
        state.cached_filter = "global"
        state.fetch_attempt = 0
        state.server_name_candidates = nil
        state.fetch_car_filter = nil
    end
    return true
end

function bundle.clear_filter_cache()
    state.filter_bundles = {}
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
