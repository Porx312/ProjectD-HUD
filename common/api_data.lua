--[[ ProjectD HUD — live data from ac-data API. Interface = mock_data.lua ]]

local state = require("common.api.state")
local util = require("common.api.util")
local context = require("common.api.context")
local profile = require("common.api.profile")
local parse = require("common.api.parse")
local bundle = require("common.api.bundle")
local fetch = require("common.api.fetch")
local status = require("common.api.status")
local sync = require("common.api.sync")
local web_queue = require("common.api.web_queue")

local api = {}

function api.hydrate()
    sync.pull_bundle()
end

function api.fetch_session(car_filter, force)
    api.hydrate()
    fetch.fetch_session(car_filter, force)
end

function api.tick(car_filter)
    car_filter = car_filter or state.cached_filter
    local ok_ctx, ctx = pcall(context.read_session_context)
    if ok_ctx then
        fetch.watchdog_session_fetch(ctx, car_filter)
        fetch.watchdog_profile_fetch(ctx)
    end
    web_queue.watchdog()

    local ok, err = pcall(api.fetch_session, car_filter or state.cached_filter, false)
    if not ok then
        state.last_error = "tick_error"
        ac.debug("ProjectD-HUD tick", util.safe_str(err))
        sync.publish_meta()
        return
    end
    if ok_ctx then
        if bundle.bundle_needs_profile() and not state.profile_fetch_pending and not sync.is_fetch_locked() then
            pcall(fetch.start_profile_fetch, ctx, false, false)
        end
    end

    local ok_img, images = pcall(require, "common.images")
    if ok_img and images.tick ~= nil then
        pcall(images.tick)
    end
    sync.publish_meta()
end

function api.run_tick(car_filter)
    api.hydrate()
    if not sync.tick_throttle_ok() then return end
    state.tick_count = (state.tick_count or 0) + 1
    api.tick(car_filter)
end

function api.is_loading()
    api.hydrate()
    return state.fetch_pending or state.profile_fetch_pending
end

function api.get_status()
    api.hydrate()
    return status.get_status()
end

function api.get_status_message(kind)
    api.hydrate()
    return status.get_status_message(kind)
end

function api.is_debug()
    return state.is_debug()
end

function api.get_debug_lines()
    return status.get_debug_lines()
end

function api.get_diag_lines()
    api.hydrate()
    return status.get_diag_lines()
end

function api.should_show_diag()
    api.hydrate()
    if state.is_debug() then return true end
    if state.fetch_pending or state.profile_fetch_pending then return true end
    if state.cached_bundle == nil then return true end
    if state.last_error ~= nil and state.last_error ~= "" then return true end
    return false
end

function api.get_context()
    api.hydrate()
    if state.cached_bundle ~= nil and state.cached_bundle.context ~= nil then
        local c = state.cached_bundle.context
        return {
            server_id = util.safe_str(c.server_id),
            track_id = util.safe_str(c.track_id),
            track_name = util.safe_str(c.track_name),
            layout_id = util.safe_str(c.layout_id),
            layout_name = util.safe_str(c.layout_name),
            car_id = util.safe_str(c.car_id),
            car_name = util.safe_str(c.car_name),
            player_steam_id = util.safe_str(c.player_steam_id),
        }
    end
    local ok, ctx = pcall(context.read_session_context)
    if not ok then return {} end
    return {
        track_id = ctx.track_id,
        track_name = ctx.track_name,
        layout_id = ctx.layout_id,
        layout_name = ctx.layout_name,
        car_id = ctx.car_id,
        car_name = ctx.car_name,
        player_steam_id = ctx.player_steam_id,
    }
end

function api.get_leaderboard_filters()
    api.hydrate()
    if state.known_filters ~= nil and #state.known_filters > 0 then
        return state.known_filters
    end
    if state.cached_bundle ~= nil and state.cached_bundle.leaderboard ~= nil and state.cached_bundle.leaderboard.filters ~= nil then
        local filters = state.cached_bundle.leaderboard.filters
        if #filters > 0 then return filters end
    end
    return { { id = "global", label = "Global ranking" } }
end

function api.select_filter(car_filter)
    car_filter = car_filter or "global"
    api.hydrate()
    if bundle.try_switch_filter(car_filter) then return true end
    if state.fetch_pending or sync.is_fetch_locked() then
        state.scheduled_filter_fetch = car_filter
        return false
    end
    api.fetch_session(car_filter, false)
    return false
end

function api.get_leaderboard_header()
    api.hydrate()
    if state.cached_bundle ~= nil and state.cached_bundle.leaderboard ~= nil then
        local lb = state.cached_bundle.leaderboard
        return { title = lb.title or "Top 10", map = lb.map or "", layout = lb.layout or "" }
    end
    local ctx = api.get_context()
    return {
        title = "Top 10",
        map = ctx.track_name or ctx.track_id or "",
        layout = ctx.layout_name or ctx.layout_id or "",
    }
end

function api.get_top10(car_filter)
    car_filter = car_filter or "global"
    api.hydrate()
    local leaderboard = bundle.get_cached_leaderboard(car_filter)
    if leaderboard == nil and not state.fetch_pending and not sync.is_fetch_locked() then
        api.fetch_session(car_filter, false)
    elseif leaderboard == nil and state.fetch_car_filter ~= car_filter then
        state.scheduled_filter_fetch = car_filter
    end
    if leaderboard ~= nil then
        return parse.copy_entries(leaderboard.entries)
    end
    if state.cached_bundle ~= nil and state.cached_bundle.leaderboard ~= nil and state.cached_filter == car_filter then
        return parse.copy_entries(state.cached_bundle.leaderboard.entries)
    end
    return {}
end

function api.get_top8(car_filter) return api.get_top10(car_filter) end
function api.get_top5(car_filter) return api.get_top10(car_filter) end

function api.get_player_profile()
    api.hydrate()
    local p = profile.coalesce_profile(state.cached_bundle and state.cached_bundle.profile)
    if p ~= nil then
        return {
            name = p.name or "?",
            rank = tonumber(p.rank) or 0,
            tier = tonumber(p.tier) or 0,
            best_lap_ms = tonumber(p.best_lap_ms) or 0,
            car_name = p.car_name or "",
            car_id = p.car_id or "",
            avatar_url = p.avatar_url,
            steam_id = p.steam_id or p.steamId,
        }
    end
    return nil
end

function api.get_rival()
    api.hydrate()
    local p = profile.coalesce_profile(state.cached_bundle and state.cached_bundle.profile)
    if p == nil then return nil end

    local r = p.rival
    if r == nil and state.cached_bundle ~= nil and state.cached_bundle.leaderboard ~= nil then
        r = profile.derive_rival_from_leaderboard(p, state.cached_bundle.leaderboard)
    end
    if r == nil then return nil end

    return {
        name = r.name or "?",
        rank = tonumber(r.rank) or 0,
        tier = tonumber(r.tier) or 0,
        best_lap_ms = tonumber(r.best_lap_ms) or tonumber(r.lap_ms) or 0,
        car_name = r.car_name or "",
        avatar_url = r.avatar_url,
    }
end

function api.reset_session_state()
    state.cached_at = 0
    state.cached_bundle = nil
    state.fetch_pending = false
    state.profile_fetch_pending = false
    state.last_error = nil
    state.last_http_status = nil
    state.fetch_attempt = 0
    state.profile_fetch_attempt = 0
    state.profile_candidates_exhausted = false
    state.server_name_candidates = nil
    state.profile_server_candidates = nil
    state.last_resolved_server_name = nil
    state.last_session_had_players = false
    state.last_fetch_url = ""
    state.last_fetch_kind = ""
    state.last_web_event = ""
    state.session_fetch_started_at = 0
    state.profile_fetch_started_at = 0
    state.web_queue = {}
    state.scheduled_filter_fetch = nil
    state.fetch_car_filter = nil
    state.local_sync_ver = 0
    bundle.clear_filter_cache()
end

function api.on_session_start()
    sync.on_session_reset()
    api.reset_session_state()
    api.fetch_session(state.cached_filter or "global", true)
end

function api.init()
    if sync.was_inited() then
        api.hydrate()
        return
    end
    sync.mark_inited()
    if web ~= nil and web.timeouts ~= nil then
        pcall(web.timeouts, 3000, 8000, 12000, 15000)
    end
    api.fetch_session("global", true)
end

return api
