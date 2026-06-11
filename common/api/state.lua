--[[ Shared mutable fetch/cache state for ProjectD HUD API client. ]]

local state = {
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
    profile_fetch_started_at = 0,
    session_fetch_started_at = 0,
    fetch_attempt = 0,
    profile_fetch_attempt = 0,
    profile_candidates_exhausted = false,
    server_name_candidates = nil,
    profile_server_candidates = nil,
    last_resolved_server_name = nil,
    last_session_had_players = false,
    last_tick_at = -1,
    tick_count = 0,
    last_fetch_url = "",
    last_fetch_kind = "",
    last_web_event = "",
    hud_version = "1.0.17",

    CONTEXT_RETRY_SEC = 0.5,
    TICK_INTERVAL_SEC = 0.15,
    PROFILE_RETRY_SEC = 8,
    PROFILE_FETCH_TIMEOUT_SEC = 12,
    SESSION_FETCH_TIMEOUT_SEC = 15,

    debug_storage = ac.storage("ProjectD-HUD:debug", true),
    steam_override_storage = ac.storage("ProjectD-HUD:steam_id", ""),
    steam_cache_storage = ac.storage("ProjectD-HUD:steam_cache", ""),
}

function state.is_debug()
    return state.debug_storage:get() == true
end

return state
