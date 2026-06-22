--[[ Shared mutable fetch/cache state — one instance for all HUD windows. ]]

local STATE_KEY = "__ProjectDHudSharedState_v1"

local function create_state()
    return {
        cached_at = 0,
        cached_filter = "global",
        cached_bundle = nil,
        fetch_pending = false,
        profile_fetch_pending = false,
        last_http_status = nil,
        last_error = nil,
        last_fetch_at = 0,
        last_attempt_at = 0,
        last_profile_attempt_at = 0,
        last_version_attempt_at = 0,
        last_version_poll_at = 0,
        last_hud_refresh_at = 0,
        last_hud_backup_sync_at = 0,
        profile_fetch_started_at = 0,
        session_fetch_started_at = 0,
        version_fetch_started_at = 0,
        fetch_attempt = 0,
        profile_fetch_attempt = 0,
        version_fetch_attempt = 0,
        profile_candidates_exhausted = false,
        server_name_candidates = nil,
        profile_server_candidates = nil,
        version_server_candidates = nil,
        last_resolved_server_name = nil,
        last_session_had_players = false,
        last_tick_at = -1,
        tick_count = 0,
        last_fetch_url = "",
        last_fetch_kind = "",
        last_web_event = "",
        web_inflight = nil,
        web_queue = {},
        filter_bundles = {},
        fetch_car_filter = nil,
        scheduled_filter_fetch = nil,
        filter_fetch_at = {},
        hud_version = "1.0.26",
        hud_lb_version = "",
        hud_player_versions = {},
        version_fetch_pending = false,
        version_cache_ok = false,
        active_car_filter = "global",

        CONTEXT_RETRY_SEC = 0.5,
        TICK_INTERVAL_SEC = 0.25,
        PROFILE_RETRY_SEC = 8,
        PROFILE_FETCH_TIMEOUT_SEC = 12,
        SESSION_FETCH_TIMEOUT_SEC = 15,
        VERSION_FETCH_TIMEOUT_SEC = 12,

        steam_override_storage = ac.storage("ProjectD-HUD:steam_id", ""),
        steam_cache_storage = ac.storage("ProjectD-HUD:steam_cache", ""),
        server_override_storage = ac.storage("ProjectD-HUD:server_name", ""),
        last_server_tried = "",
        server_names_tried = nil,

        battle_version = "",
        battle_remote_version = "",
        battle_applied_version = "",
        battle_snapshot_raw = nil,
        battle_ui = nil,
        battle_version_pending = false,
        battle_fetch_pending = false,
        battle_last_poll_at = 0,
        battle_last_error = nil,
        battle_server_candidates = nil,
        battle_fetch_attempt = 0,
        battle_version_fetch_attempt = 0,
        battle_result_hold_until = 0,
        battle_last_event_ts = 0,
        battle_version_fetch_started_at = 0,
        battle_fetch_started_at = 0,
        battle_backoff_until = 0,
        battle_last_resolved_server_name = nil,
        battle_last_server_tried = "",
        battle_event_shown_at = 0,
        battle_last_snapshot_at = 0,
        battle_finish_latch_snapshot = nil,
        battle_last_battle_id = "",

        BATTLE_FETCH_TIMEOUT_SEC = 12,
        BATTLE_VERSION_TIMEOUT_SEC = 12,
        BATTLE_BACKOFF_SEC = 5,
    }
end

local shared_root = (ac ~= nil and ac.shared) or _G
if shared_root[STATE_KEY] == nil then
    shared_root[STATE_KEY] = create_state()
end

local state = shared_root[STATE_KEY]

function state.state_tag()
    return string.sub(tostring(state), -8)
end

return state
