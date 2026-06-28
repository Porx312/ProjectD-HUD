--[[ Shared mutable HUD state — one instance for all windows. ]]

local STATE_KEY = "__ProjectDHudSharedState_v1"

local function create_state()
    return {
        cached_at = 0,
        cached_bundle = nil,

        last_http_status = nil,
        last_error = nil,
        last_session_had_players = false,

        last_tick_at = -1,
        tick_count = 0,

        last_fetch_url = "",
        last_fetch_kind = "",
        last_web_event = "",

        web_inflight = nil,
        web_queue = {},
        web_stream = nil,

        hud_version = "",

        TICK_INTERVAL_SEC = 0.25,

        steam_override_storage = ac.storage("ProjectD-HUD:steam_id", ""),
        steam_cache_storage = ac.storage("ProjectD-HUD:steam_cache", ""),
        server_override_storage = ac.storage("ProjectD-HUD:server_name", ""),

        battle_snapshot_raw = nil,
        battle_ui = nil,
        battle_last_error = nil,
        battle_result_hold_until = 0,
        battle_last_event_ts = 0,
        battle_event_shown_at = 0,
        battle_last_snapshot_at = 0,
        battle_last_applied_at = 0,
        battle_retained_ui = nil,
        battle_finish_latch_snapshot = nil,
        battle_last_battle_id = "",
        battle_prep_cd1_since = 0,
        battle_last_arming_cd = nil,

        battle_sse_connected = false,
        battle_sse_reconnect_at = 0,
        battle_sse_buffer = "",
        battle_sse_stream_pending = false,
        battle_sse_last_body_len = 0,
        battle_sse_session_key = "",
        battle_sse_connected_at = 0,
        battle_sse_last_activity_at = 0,
        battle_sse_mode = nil,
        battle_sse_steam_id = "",

        battle_last_event_name = "",
        battle_last_sse_summary = "",
        battle_last_payload_summary = "",
        battle_last_ui_summary = "",
        battle_last_debug_stage = "",
        battle_last_clear_reason = "",
        battle_last_trace_at = 0,

        battle_tcp = nil,
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
