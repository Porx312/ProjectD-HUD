--[[ SSE / snapshot transport state. ]]

return {
    battle_sse_connected = false,
    battle_sse_reconnect_at = 0,
    battle_sse_buffer = "",
    battle_sse_stream_pending = false,
    battle_sse_last_body_len = 0,
    battle_sse_session_key = "",
    battle_sse_connected_at = 0,
    battle_sse_web_stall_at = 0,
    battle_sse_last_activity_at = 0,
    battle_sse_mode = nil,
    battle_sse_steam_id = "",
    hud_transport = "",
    snapshot_poll_at = 0,
    snapshot_inflight = false,
    snapshot_poll_interval_sec = 5,
    battle_tcp = nil,
}
