--[[ User-facing status messages and debug overlay lines. ]]

local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local profile = require("common.api.profile")
local bundle = require("common.api.bundle")
local parse = require("common.api.parse")
local web_queue = require("common.api.web_queue")

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

local function format_name_list(list, max_items)
    if list == nil or type(list) ~= "table" or #list == 0 then return "" end
    max_items = max_items or 4
    local parts = {}
    for i = 1, math.min(#list, max_items) do
        parts[#parts + 1] = tostring(list[i])
    end
    local text = table.concat(parts, " | ")
    if #list > max_items then text = text .. "..." end
    if #text > 64 then text = string.sub(text, 1, 61) .. "..." end
    return text
end

function status.get_diag_lines()
    local ok, ctx = pcall(context.read_session_context)
    if not ok then ctx = {} end
    local st = status.get_status()
    local race = steam.get_race_ini_status()
    local url = util.safe_str(state.last_fetch_url)
    if #url > 96 then
        url = string.sub(url, 1, 93) .. "..."
    end
    local candidates = state.server_names_tried
    if (candidates == nil or #candidates == 0) and state.server_name_candidates ~= nil then
        candidates = state.server_name_candidates
    end
    if candidates == nil or #candidates == 0 then
        local ok_list, fresh = pcall(context.build_server_name_candidates, ctx)
        if ok_list and fresh ~= nil then candidates = fresh end
    end
    local try_total = candidates ~= nil and #candidates or 0
    local sess_age = ""
    if state.fetch_pending and (state.session_fetch_started_at or 0) > 0 then
        sess_age = string.format("%.1fs", os.clock() - state.session_fetch_started_at)
    end
    local prof_age = ""
    if state.profile_fetch_pending and (state.profile_fetch_started_at or 0) > 0 then
        prof_age = string.format("%.1fs", os.clock() - state.profile_fetch_started_at)
    end
    return {
        "ver=" .. util.safe_str(state.hud_version),
        "tick=" .. tostring(state.tick_count),
        "ctx_ready=" .. tostring(st.context_ready),
        "sess_age=" .. sess_age,
        "prof_age=" .. prof_age,
        "steam=" .. util.safe_str(ctx.player_steam_id),
        "race_path=" .. util.safe_str(race.path ~= "" and race.path or "not found"),
        "race_remote=" .. tostring(race.remote_active),
        "race_guid=" .. tostring(race.has_guid),
        "server=" .. util.safe_str(ctx.server_name),
        "tried=" .. util.safe_str(state.last_server_tried),
        "names=" .. format_name_list(candidates, 5),
        "try=" .. tostring(state.fetch_attempt) .. "/" .. tostring(try_total),
        "override=" .. util.safe_str(state.server_override_storage:get()),
        "race_server=" .. steam.server_name_from_race_ini(),
        "race_slug=" .. steam.server_slug_from_race_ini(),
        "race.ini=" .. steam.steam_from_race_ini(),
        "bridge=" .. steam.steam_from_online_bridge(),
        "track=" .. util.safe_str(ctx.track_id) .. "/" .. util.safe_str(ctx.layout_id),
        "full=" .. util.safe_str(ctx.track_full_id),
        "car=" .. util.safe_str(ctx.car_id),
        "http=" .. tostring(st.http_status),
        "err=" .. tostring(st.error),
        "state=" .. state.state_tag(),
        "filter=" .. util.safe_str(state.cached_filter),
        "bundle=" .. tostring(st.has_bundle),
        "entries=" .. tostring(st.entry_count),
        "rows_ui=" .. tostring(st.ui_row_count),
        "profile=" .. tostring(profile.coalesce_profile(state.cached_bundle and state.cached_bundle.profile) ~= nil),
        "rank=" .. tostring(state.cached_bundle and state.cached_bundle.profile and state.cached_bundle.profile.rank or "?"),
        "rival=" .. tostring(state.cached_bundle ~= nil and state.cached_bundle.profile ~= nil and state.cached_bundle.profile.rival ~= nil),
        "srv=" .. util.safe_str(state.last_resolved_server_name),
        "sess_load=" .. tostring(state.fetch_pending),
        "prof_load=" .. tostring(state.profile_fetch_pending),
        "prof_done=" .. tostring(state.profile_candidates_exhausted),
        "prof_try=" .. tostring(state.profile_fetch_attempt),
        "players=" .. tostring(state.last_session_had_players),
        "fetch=" .. util.safe_str(state.last_fetch_kind),
        "url=" .. url,
        "web=" .. util.safe_str(state.last_web_event),
        "web_q=" .. tostring(web_queue.queue_len()),
        "web_now=" .. util.safe_str(state.web_inflight),
    }
end

function status.get_debug_lines()
    if not state.is_debug() then return {} end
    return status.get_diag_lines()
end

return status
