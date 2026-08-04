--[[ ProjectD HUD — live data from ac-data API. Interface = mock_data.lua ]]

local state = require("common.api.state")
local util = require("common.api.util")
local context = require("common.api.context")
local profile = require("common.api.profile")
local bundle = require("common.api.bundle")
local battle_fetch = require("common.api.battle_fetch")
local hud_transport = require("common.api.battle_transport")
local session_snapshot = require("common.api.session_snapshot")
local battle_parse = require("common.api.battle_parse")
local status = require("common.api.status")
local session_version = require("common.api.session_version")

local api = {}

local function api_blocked()
    if state.last_error == "user_invalidated" then return true end
    if util.is_presence_fatal(state.last_error) and util.should_show_presence_error(state.last_error) then
        return true
    end
    return false
end

local function profile_blocked()
    return api_blocked()
end

local function slot_from_rival(entry)
    if entry == nil then return nil end
    return {
        rank = tonumber(entry.rank) or 0,
        name = entry.name or "?",
        tier = profile.tier_for_display(entry),
        lap_ms = tonumber(entry.lap_ms or entry.best_lap_ms) or 0,
        car_name = entry.car_name or "",
        avatar_url = entry.avatar_url,
        elo = tonumber(entry.elo),
    }
end

function api.fetch_session(_car_filter, force)
    if not force then return end
    local ok, ctx = pcall(context.read_session_context)
    hud_transport.reset()
    if ok and ctx.is_online == true then
        pcall(hud_transport.try_connect, ctx, os.clock())
    end
end

function api.tick(_car_filter)
    local now = os.clock()
    if (now - (state.last_tick_at or -1)) < state.TICK_INTERVAL_SEC then return end
    state.last_tick_at = now
    state.tick_count = (state.tick_count or 0) + 1

    local ok_ctx, ctx = pcall(context.read_session_context)
    if ok_ctx then
        local ok_step = pcall(function()
            util.clear_stale_presence_error()
            pcall(hud_transport.tick, ctx, now)
            pcall(session_snapshot.tick, ctx, now)
            pcall(session_version.tick, ctx, now)
        end)
        if not ok_step then
            state.last_error = "tick_error"
            return
        end
    end

    local ok_img, images = pcall(require, "common.images")
    if ok_img and images.tick ~= nil then
        pcall(images.tick)
    end
end

function api.is_account_restricted()
    return state.last_error == "user_invalidated"
end

function api.is_loading()
    if profile_blocked() then return false end
    return status.is_loading()
end

function api.get_status()
    return status.get_status()
end

function api.get_status_message(kind)
    return status.get_status_message(kind)
end

function api.get_context()
    if state.cached_bundle ~= nil and state.cached_bundle.context ~= nil then
        local c = state.cached_bundle.context
        return {
            server_id = util.safe_str(c.server_id),
            server_name = util.safe_str(c.server_name),
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
        server_name = ctx.server_name,
    }
end

function api.get_player_profile()
    local raw = state.cached_bundle and state.cached_bundle.profile
    local p = profile.coalesce_profile(raw)
    if p ~= nil and p.isInvalidated ~= true then
        local rivals = p.rivals or { above = nil, below = nil }
        local rival = p.rival or rivals.above
        return {
            name = p.name or "?",
            rank = tonumber(p.rank) or 0,
            tier = profile.tier_for_display(p),
            best_lap_ms = tonumber(p.best_lap_ms) or 0,
            last_lap_ms = tonumber(p.last_lap_ms) or 0,
            lap_ms = profile.display_lap_ms(p),
            car_name = p.car_name or "",
            car_id = p.car_id or "",
            avatar_url = p.avatar_url,
            steam_id = p.steam_id or p.steamId,
            elo = tonumber(p.elo),
            rival = rival,
            rivals = rivals,
        }
    end
    if profile_blocked() then return nil end
    return nil
end

function api.get_competition_ladder(_car_filter)
    local p = profile.coalesce_profile(state.cached_bundle and state.cached_bundle.profile)
    if p ~= nil and p.isInvalidated ~= true then
        local rank = tonumber(p.rank) or 0
        local rivals = p.rivals or { above = nil, below = nil }
        local center = {
            rank = rank,
            name = p.name,
            tier = profile.tier_for_display(p),
            lap_ms = profile.display_lap_ms(p),
            car_name = p.car_name,
            avatar_url = p.avatar_url,
            elo = p.elo,
            is_self = true,
        }

        return {
            slots = {
                [0] = slot_from_rival(rivals.above),
                [1] = center,
                [2] = slot_from_rival(rivals.below),
            },
            player_rank = rank,
            profile = api.get_player_profile(),
        }
    end

    if profile_blocked() then
        return { slots = {}, player_rank = 0, profile = nil }
    end
    return { slots = {}, player_rank = 0, profile = nil }
end

function api.get_battle()
    local battle = battle_fetch.get_battle(os.clock())
    if battle ~= nil then return battle end

    local ok, ctx = pcall(context.read_session_context)
    if not ok or not context.battle_context_ready(ctx) then
        return nil
    end

    local prof = api.get_player_profile()
    if prof == nil then return nil end

    -- Poll idle: synthetic LOOKING lobby (is_synthetic_lobby=true) until real battle snapshot.
    if util.safe_str(state.hud_transport) == "poll" then
        if state.battle_ui == nil then
            return battle_parse.lobby_from_profile(prof)
        end
        return nil
    end

    if state.battle_sse_mode == "tcp" or state.battle_sse_connected == true then
        return battle_parse.lobby_from_profile(prof)
    end

    return nil
end

function api.reset_session_state()
    state.cached_at = 0
    state.cached_bundle = nil
    state.last_error = nil
    state.last_http_status = nil
    state.last_session_had_players = false
    state.last_fetch_url = ""
    state.last_fetch_kind = ""
    state.last_web_event = ""
    state.web_queue = {}
    state.web_inflight = nil
    state.web_stream = nil
    state.hud_version = ""
    state.hud_waiting_reason = nil
    state.session_seq = 0
    state.version_poll_at = 0
    state.version_poll_inflight = false
    bundle.clear_cache()
    hud_transport.reset()
    session_snapshot.reset()
end

function api.on_session_start()
    api.reset_session_state()
    api.fetch_session(nil, true)
end

function api.init()
    if web ~= nil and web.timeouts ~= nil then
        pcall(web.timeouts, 3000, 8000, 12000, 15000)
    end
end

return api
