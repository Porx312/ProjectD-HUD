--[[ User-facing status messages. ]]



local state = require("common.api.state")

local util = require("common.api.util")

local context = require("common.api.context")

local profile = require("common.api.profile")

local bundle = require("common.api.bundle")



local status = {}



local battle_fetch = require("common.api.battle_fetch")



local function presence_message()

    if not util.should_show_presence_error(state.last_error) then return nil end

    return util.presence_message(state.last_error)

end



local function battle_message()

    if util.is_presence_fatal(state.battle_last_error) and util.ignore_presence_error(state.battle_last_error) then

        return nil

    end

    return util.battle_error_message(state.battle_last_error)

end



local function has_actionable_error()

    if state.last_error == nil or state.last_error == "" then return false end

    if util.should_ignore_error(state.last_error) then return false end

    return true

end



local function session_wait_message()
    if state.cached_bundle ~= nil then return nil end
    if state.last_error == "user_not_found" then return "Link Steam in ProjectD" end
    if state.last_error == "missing_steam" then return "Join online server (no Steam in race.ini)" end
    if has_actionable_error() then return nil end

    local wait_reason = util.safe_str(state.hud_waiting_reason)
    if wait_reason == "player_not_connected" then
        return "Waiting for server registration…"
    end
    if wait_reason == "server_not_found" then
        return "Server not registered in ProjectD — leave and rejoin"
    end
    if wait_reason == "track_not_found" then
        return "Waiting for track data…"
    end
    if wait_reason == "car_not_found" then
        return "Waiting for car data…"
    end



    if state.battle_sse_stream_pending then return "Connecting to ProjectD…" end



    local ok, ctx = pcall(context.read_session_context)

    if not ok then return nil end



    if ctx.is_online ~= true then return nil end



    if not context.context_is_ready(ctx) then

        return "Join online server (no Steam in race.ini)"

    end



    if state.battle_sse_connected or battle_fetch.is_session_live() then

        return "Waiting for server registration…"

    end



    return "Connecting to ProjectD…"

end



local function hud_stream_loading()

    if state.cached_bundle ~= nil then return false end

    if util.should_show_presence_error(state.last_error) then return false end

    if has_actionable_error() then return false end

    if session_wait_message() ~= nil then return false end



    if state.battle_sse_stream_pending then return true end

    if not state.battle_sse_connected then

        local ok, ctx = pcall(context.read_session_context)

        return ok and ctx.is_online == true and context.context_is_ready(ctx)

    end

    return (state.battle_sse_last_activity_at or 0) <= 0

end



function status.is_loading()

    return hud_stream_loading()

end



local function profile_missing_message()

    if state.last_error == "user_invalidated" then

        return "Account restricted"

    end

    local battle_err = util.safe_str(state.battle_last_error)
    if battle_err == "http_404" or battle_err == "player_not_connected" then
        return "Not registered on server — rejoin the lobby"
    end
    if battle_err == "not_managed_server" then
        return "Server not managed by ProjectD"
    end

    local presence = util.presence_message(state.last_error)

    if presence ~= nil and util.should_show_presence_error(state.last_error) then return presence end



    local wait_msg = session_wait_message()

    if wait_msg ~= nil then return wait_msg end



    if hud_stream_loading() then return "Loading..." end

    if state.last_error == "user_not_found" then

        return "Link Steam in ProjectD"

    end

    if state.last_error == "missing_steam" then return "Join online server (no Steam in race.ini)" end

    if state.last_error == "network_error" then return "Network error (profile)" end

    if state.last_error == "profile_unavailable" then return "Profile unavailable" end

    if state.last_error ~= nil and string.sub(state.last_error, 1, 4) == "http" then

        return "Profile unavailable"

    end

    if state.last_error ~= nil then return tostring(state.last_error) end

    return "Profile unavailable"

end



function status.get_status()

    local ok, ctx = pcall(context.read_session_context)

    if not ok then ctx = {} end

    local bundled = profile.coalesce_profile(state.cached_bundle and state.cached_bundle.profile)

    local api_ctx = state.cached_bundle and state.cached_bundle.context or nil

    return {

        loading = hud_stream_loading(),

        profile_loading = hud_stream_loading(),

        error = state.last_error,

        http_status = state.last_http_status,

        has_bundle = state.cached_bundle ~= nil,

        has_profile = bundled ~= nil,

        board_version = util.safe_str(state.hud_version),

        steam_id = util.safe_str(ctx.player_steam_id),

        server_name = util.safe_str(api_ctx and api_ctx.server_name or ctx.server_name),

        battle_sse = state.battle_sse_connected == true,

        battle_sse_mode = util.safe_str(state.battle_sse_mode),

        hud_transport = util.safe_str(state.hud_transport),

        battle_last_error = util.safe_str(state.battle_last_error),

        last_web_event = util.safe_str(state.last_web_event),

        battle_snap_at = state.battle_last_snapshot_at or 0,

        battle_event_name = util.safe_str(state.battle_last_event_name),

        battle_sse_summary = util.safe_str(state.battle_last_sse_summary),

        battle_ui_summary = util.safe_str(state.battle_last_ui_summary),

        battle_stage = util.safe_str(state.battle_last_debug_stage),

        battle_clear_reason = util.safe_str(state.battle_last_clear_reason),

        track_id = util.safe_str(api_ctx and api_ctx.track_id or ctx.track_id),

        layout_id = util.safe_str(api_ctx and api_ctx.layout_id or ctx.layout_id),

        context_ready = context.context_is_ready(ctx),

        is_online = ctx.is_online == true,

        hud_waiting_reason = util.safe_str(state.hud_waiting_reason),

    }

end



function status.get_status_message(kind)

    local st = status.get_status()



    if state.last_error == "user_invalidated" then

        return "Account restricted"

    end



    local presence = presence_message()

    if presence ~= nil then

        if kind == "profile" or kind == "competition" then

            return presence

        end

    end



    local battle_err = battle_message()

    if battle_err ~= nil and kind == "battle" then

        return battle_err

    end



    local bundled_profile = st.has_bundle

        and profile.coalesce_profile(state.cached_bundle.profile)

        or nil



    if kind == "competition" or kind == "profile" then

        if bundled_profile ~= nil and bundled_profile.isInvalidated ~= true then

            return nil

        end

        local wait_msg = session_wait_message()

        if wait_msg ~= nil then return wait_msg end

        if hud_stream_loading() then

            return "Loading..."

        end

        return profile_missing_message()

    elseif kind == "battle" then

        if battle_fetch.get_battle() ~= nil then return nil end

        if state.battle_ui ~= nil then return nil end

        local wait_msg = session_wait_message()

        if wait_msg ~= nil then return wait_msg end

        if state.battle_sse_stream_pending then return "Connecting to ProjectD…" end

        battle_err = battle_message()

        if battle_err ~= nil then return battle_err end

        if state.battle_last_error == "http_401" then

            return "Battle authorization failed"

        end

        if state.battle_last_error == "http_502"

            or state.battle_last_error == "http_503"

            or state.battle_last_error == "http_504" then

            return "Battle data unavailable"

        end

        if state.battle_last_error == "network_error" then

            return "Network error (battle)"

        end

        if state.battle_last_error == "sse_stalled" then

            return "Battle SSE stalled - reconnecting"

        end

        if st.battle_stage ~= "" then

            return "Battle debug: " .. st.battle_stage

        end

        return nil

    elseif hud_stream_loading() then

        return "Loading..."

    end



    if state.last_error == "json_parse_failed" then return "JSON parse error" end

    if state.last_error == "missing_steam" then return "Join online server (no Steam in race.ini)" end

    if state.last_error == "web_unavailable" then return "CSP web.get unavailable" end

    if state.last_error == "network_error" then return "Network error — check firewall/VPN" end

    if state.last_error == "http_502" or state.last_error == "http_503" or state.last_error == "http_504" then

        if st.has_bundle then return nil end

        return "API gateway error — retrying"

    end

    if state.last_error == "profile_timeout" then return "Profile timeout — retrying" end

    if state.last_error == "session_timeout" then return "API timeout — check connection" end

    if state.last_error == "context_error" then return "AC context error" end

    if state.last_error ~= nil and string.sub(state.last_error, 1, 4) == "http" then

        return ("API error (" .. tostring(state.last_http_status or "?") .. ")")

    end

    if state.last_error ~= nil then return tostring(state.last_error) end

    if not st.has_bundle then return "Connecting to ProjectD…" end

    return "No data"

end



return status

