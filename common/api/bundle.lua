--[[ Cached session bundle helpers + per-car-filter leaderboard cache. ]]

local config = require("common.config")
local state = require("common.api.state")
local profile = require("common.api.profile")
local parse = require("common.api.parse")

local bundle = {}

local function filter_ttl()
    return config.FILTER_CACHE_TTL_SEC or config.CACHE_TTL_SEC or 60
end

local function ensure_filter_bundles()
    if state.filter_bundles == nil then state.filter_bundles = {} end
end

function bundle.remember_filters(filters)
    if filters ~= nil and type(filters) == "table" and #filters > 0 then
        state.known_filters = filters
    end
end

function bundle.store_filter_leaderboard(car_filter, leaderboard)
    if leaderboard == nil then return end
    ensure_filter_bundles()
    state.filter_bundles[car_filter or "global"] = {
        leaderboard = leaderboard,
        cached_at = os.clock(),
    }
end

function bundle.get_cached_leaderboard(car_filter)
    car_filter = car_filter or "global"
    if state.cached_bundle ~= nil
        and state.cached_filter == car_filter
        and state.cached_bundle.leaderboard ~= nil then
        return state.cached_bundle.leaderboard
    end
    ensure_filter_bundles()
    local cached = state.filter_bundles[car_filter]
    if cached == nil or cached.leaderboard == nil then return nil end
    if (os.clock() - (cached.cached_at or 0)) > filter_ttl() then
        state.filter_bundles[car_filter] = nil
        return nil
    end
    return cached.leaderboard
end

function bundle.switch_to_filter(car_filter)
    car_filter = car_filter or "global"
    local leaderboard = bundle.get_cached_leaderboard(car_filter)
    if leaderboard == nil then return false end

    local base = state.cached_bundle
    if base == nil then
        base = { ok = true, context = nil, profile = nil }
    end

    state.cached_bundle = {
        ok = true,
        context = base.context,
        profile = base.profile,
        leaderboard = leaderboard,
    }
    state.cached_filter = car_filter
    local cached = state.filter_bundles[car_filter]
    state.cached_at = cached and cached.cached_at or os.clock()
    return true
end

function bundle.try_switch_filter(car_filter)
    return bundle.switch_to_filter(car_filter)
end

function bundle.apply_bundle(data, car_filter)
    if data == nil or data.ok ~= true then return false end

    car_filter = car_filter or "global"
    data.leaderboard = parse.coalesce_leaderboard(data)
    local prev_profile = profile.coalesce_profile(state.cached_bundle and state.cached_bundle.profile)
    if profile.coalesce_profile(data.profile) == nil and prev_profile ~= nil then
        data.profile = prev_profile
    end

    if data.leaderboard ~= nil then
        bundle.store_filter_leaderboard(car_filter, data.leaderboard)
        bundle.remember_filters(data.leaderboard.filters)
    end

    state.cached_bundle = data
    state.cached_filter = car_filter
    state.cached_at = os.clock()
    state.fetch_attempt = 0
    state.server_name_candidates = nil
    state.fetch_car_filter = nil

    local ok_sync, sync = pcall(require, "common.api.sync")
    if ok_sync and sync ~= nil and sync.publish_bundle ~= nil then
        pcall(sync.publish_bundle, car_filter)
    end
    return true
end

function bundle.clear_filter_cache()
    state.filter_bundles = {}
    state.known_filters = nil
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
