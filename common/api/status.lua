--[[ User-facing status messages. ]]

local state = require("common.api.state")
local util = require("common.api.util")
local context = require("common.api.context")
local profile = require("common.api.profile")
local bundle = require("common.api.bundle")
local parse = require("common.api.parse")

local status = {}

local function profile_missing_message()
    if state.profile_fetch_pending then return "Loading profile..." end
    if state.last_error == "user_not_found" then
        return "Link Steam in ProjectD"
    end
    if state.last_error == "missing_steam" then return "Join online server (no Steam in race.ini)" end
    if state.last_error == "network_error" then return "Network error (profile)" end
    if state.last_error == "server_not_found" then return "Server not found" end
    if state.last_error == "profile_unavailable" then return "Profile unavailable" end
    if state.last_error ~= nil and string.sub(state.last_error, 1, 4) == "http" then
        return "Profile unavailable"
    end
    if state.last_error ~= nil then return tostring(state.last_error) end
    if state.fetch_pending then return "Loading profile..." end
    if bundle.bundle_needs_profile() and not state.profile_candidates_exhausted then
        return "Loading profile..."
    end
    return "Profile unavailable"
end

function status.get_status()
    local ok, ctx = pcall(context.read_session_context)
    if not ok then ctx = {} end
    return {
        loading = state.fetch_pending,
        profile_loading = state.profile_fetch_pending,
        error = state.last_error,
        http_status = state.last_http_status,
        has_bundle = state.cached_bundle ~= nil,
        entry_count = state.cached_bundle
            and state.cached_bundle.leaderboard
            and util.count_table_entries(state.cached_bundle.leaderboard.entries)
            or 0,
        ui_row_count = state.cached_bundle
            and state.cached_bundle.leaderboard
            and parse.count_ui_entries(state.cached_bundle.leaderboard.entries)
            or 0,
        steam_id = util.safe_str(ctx.player_steam_id),
        server_name = util.safe_str(ctx.server_name),
        battle_server = util.safe_str(state.battle_last_server_tried),
        battle_sse = state.battle_sse_connected == true,
        battle_sse_mode = util.safe_str(state.battle_sse_mode),
        battle_snap_at = state.battle_last_snapshot_at or 0,
        track_id = util.safe_str(ctx.track_id),
        layout_id = util.safe_str(ctx.layout_id),
        context_ready = context.context_is_ready(ctx),
    }
end

function status.get_status_message(kind)
    local st = status.get_status()

    local bundled_profile = st.has_bundle
        and profile.coalesce_profile(state.cached_bundle.profile)
        or nil

    if st.has_bundle then
        local n = st.ui_row_count or st.entry_count or 0
        if kind == "leaderboard" and n > 0 then return nil end
        if kind == "leaderboard" and n == 0 and not state.fetch_pending then
            return "No times on this track"
        end
        if kind == "profile" and bundled_profile ~= nil then return nil end
        if kind == "profile" and bundled_profile == nil then
            return profile_missing_message()
        end
        if kind == "rival" then
            local p = bundled_profile
            if p == nil then return profile_missing_message() end
            local rank = tonumber(p.rank) or 0
            if rank == 1 then return "You're #1 — no rival" end
            if rank == 0 then return "No time yet — no rival" end
            if p.rival == nil then return "No rival data" end
        end
    end

    if kind == "leaderboard" then
        if state.fetch_pending and (st.ui_row_count or 0) == 0 then return "Loading..." end
    elseif kind == "profile" then
        if bundled_profile ~= nil then return nil end
        if state.fetch_pending then return "Loading..." end
        if state.profile_fetch_pending then return "Loading profile..." end
    elseif kind == "rival" then
        if bundled_profile ~= nil then
            local rank = tonumber(bundled_profile.rank) or 0
            if rank == 1 then return "You're #1 — no rival" end
            if rank == 0 then return "No time yet — no rival" end
            if bundled_profile.rival ~= nil then return nil end
            return "No rival data"
        end
        if state.fetch_pending then return "Loading..." end
        if state.profile_fetch_pending then return "Loading profile..." end
    elseif kind == "battle" then
        if state.battle_ui ~= nil then return nil end
        if state.battle_sse_stream_pending then return "Connecting battle..." end
        if state.battle_last_error == "http_502"
            or state.battle_last_error == "http_503"
            or state.battle_last_error == "http_504" then
            return "Battle data unavailable"
        end
        if state.battle_last_error == "network_error" then
            return "Network error (battle)"
        end
        if state.battle_last_error == "sse_no_data" then
            return "Battle SSE: no data (set battle_server_name=testing)"
        end
        if state.battle_last_error == "missing_server_name" then
            return "No server name — set ProjectD-HUD:battle_server_name (e.g. testing)"
        end
        return nil
    elseif state.fetch_pending or state.profile_fetch_pending then
        return "Loading..."
    end
    if state.last_error == "json_parse_failed" then return "JSON parse error" end
    if state.last_error == "missing_server_name" then return "No server name" end
    if state.last_error == "missing_steam" then return "Join online server (no Steam in race.ini)" end
    if state.last_error == "missing_track" then return "Waiting for track" end
    if state.last_error == "missing_steam_or_track" then return "Waiting for Steam / track" end
    if state.last_error == "web_unavailable" then return "CSP web.get unavailable" end
    if state.last_error == "network_error" then return "Network error — check firewall/VPN" end
    if state.last_error == "http_502" or state.last_error == "http_503" or state.last_error == "http_504" then
        if st.has_bundle then return nil end
        return "API gateway error — retrying"
    end
    if state.last_error == "profile_timeout" then return "Profile timeout — retrying" end
    if state.last_error == "session_timeout" then return "API timeout — check connection" end
    if state.last_error == "context_error" then return "AC context error" end
    if state.last_error == "server_not_found" then
        local tried = util.safe_str(state.last_server_tried)
        if tried ~= "" then
            return 'Server not found ("' .. tried .. '")'
        end
        return "Server not found"
    end
    if state.last_error == "track_not_found" then return "Track not found" end
    if state.last_error == "car_not_found" then return "Car not found" end
    if state.last_error ~= nil and string.sub(state.last_error, 1, 4) == "http" then
        if state.last_error == "http_404" then return "Server or track not found" end
        return "API error (" .. tostring(state.last_http_status or "?") .. ")"
    end
    if state.last_error ~= nil then return tostring(state.last_error) end
    if not st.has_bundle then return "Waiting for API..." end
    return "No data"
end

return status
