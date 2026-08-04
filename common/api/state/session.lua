--[[ Session cache fields (profile, rivals, versions). ]]

return {
    cached_at = 0,
    cached_bundle = nil,
    hud_waiting_reason = nil,
    last_session_had_players = false,
    hud_version = "",
    hud_lb_version = "",
    session_version = "",
    session_seq = 0,
    version_poll_at = 0,
    version_poll_inflight = false,
}
