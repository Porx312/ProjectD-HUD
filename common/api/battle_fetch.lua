--[[ HTTP polling for /hud/battle/version and /hud/battle (anti-desync). ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local web_queue = require("common.api.web_queue")
local battle_parse = require("common.api.battle_parse")

local battle_fetch = {}

local API_KEY_STORAGE = ac.storage("ProjectD-HUD:api_key", "")
local DEBUG_STORAGE = ac.storage("ProjectD-HUD:battle_debug", false)

local function battle_debug(msg)
    if DEBUG_STORAGE:get() then
        ac.debug("ProjectD-HUD battle", msg)
    end
end

local function api_key_suffix()
    local key = util.safe_str(API_KEY_STORAGE:get())
    if key == "" then return "" end
    return "&api_key=" .. util.url_encode(key)
end

local function battle_url(path, server_name, steam_id)
    return string.format(
        "%s%s?serverName=%s&steamId=%s%s",
        config.API_BASE_URL,
        path,
        util.url_encode(server_name),
        util.url_encode(steam_id),
        api_key_suffix()
    )
end

local function latch_active(now)
    now = now or os.clock()
    return now < (state.battle_result_hold_until or 0)
        and state.battle_finish_latch_snapshot ~= nil
end

local function clear_battle_cache(keep_latch)
    if keep_latch and latch_active(os.clock()) then
        state.battle_snapshot_raw = nil
        state.battle_ui = nil
        state.battle_version = "0"
        state.battle_applied_version = ""
        state.battle_remote_version = "0"
        battle_debug("clear_battle_cache keep_latch")
        return
    end
    state.battle_snapshot_raw = nil
    state.battle_ui = nil
    state.battle_finish_latch_snapshot = nil
    state.battle_version = ""
    state.battle_applied_version = ""
    state.battle_remote_version = ""
    state.battle_result_hold_until = 0
    battle_debug("clear_battle_cache full")
end

local function reset_battle_session()
    state.battle_last_event_ts = 0
    state.battle_event_shown_at = 0
    state.battle_finish_latch_snapshot = nil
    state.battle_result_hold_until = 0
end

local function apply_snapshot(raw, local_steam_id, now)
    if raw == nil then
        clear_battle_cache(false)
        return
    end

    local battle_id = util.safe_str(raw.battleId)
    if battle_id ~= "" and battle_id ~= (state.battle_last_battle_id or "") then
        if state.battle_last_battle_id ~= nil and state.battle_last_battle_id ~= "" then
            reset_battle_session()
            battle_debug("battleId changed -> reset session " .. battle_id)
        end
        state.battle_last_battle_id = battle_id
    end

    local ui = battle_parse.to_ui(raw, local_steam_id)
    if ui == nil then
        clear_battle_cache(false)
        return
    end

    state.battle_snapshot_raw = raw
    state.battle_ui = ui
    state.battle_last_snapshot_at = now
    state.battle_last_error = nil

    local new_event_ts = tonumber(ui.event_ts) or 0
    if new_event_ts > (state.battle_last_event_ts or 0) then
        state.battle_last_event_ts = new_event_ts
        state.battle_event_shown_at = now
        battle_debug("event toast: " .. util.safe_str(ui.event_label))
    end

    if battle_parse.is_terminal_ui(ui) then
        state.battle_finish_latch_snapshot = battle_parse.deep_copy_ui(ui)
        state.battle_result_hold_until = battle_parse.start_result_hold(now)
        battle_debug("latch ON state=" .. ui.state .. " status=" .. ui.status)
    end

    local v = util.safe_str(raw.version)
    state.battle_applied_version = v
    state.battle_version = v
    state.battle_remote_version = v
    battle_debug(string.format(
        "apply_snapshot ok v=%s state=%s scores=%d-%d",
        v, ui.state, ui.score_left or 0, ui.score_right or 0
    ))
end

local function with_toast_timeout(ui, now)
    if ui == nil then return nil end
    now = now or os.clock()
    local toast_sec = config.BATTLE_EVENT_TOAST_SEC or 2
    if ui.event_label ~= nil and ui.event_label ~= "" then
        local shown_at = state.battle_event_shown_at or 0
        if shown_at > 0 and (now - shown_at) > toast_sec then
            local copy = battle_parse.deep_copy_ui(ui)
            if copy ~= nil then
                copy.event_label = ""
            end
            return copy
        end
    end
    return ui
end

local function server_candidates(ctx, force_new_cycle)
    if not force_new_cycle and state.battle_server_candidates ~= nil and #state.battle_server_candidates > 0 then
        return state.battle_server_candidates
    end
    state.battle_server_candidates = context.build_server_name_candidates(ctx)
    state.battle_version_fetch_attempt = 0
    state.battle_fetch_attempt = 0
    return state.battle_server_candidates
end

local function current_server_name(candidates)
    local idx = state.battle_version_fetch_attempt
    if idx <= 0 then idx = 1 end
    return candidates[idx]
end

local function should_retry_server(err_reason)
    if err_reason == nil then return false end
    if err_reason == "server_not_found" then return true end
    if err_reason == "network_error" then return true end
    if string.sub(err_reason, 1, 4) == "http" then
        return err_reason == "http_502" or err_reason == "http_503" or err_reason == "http_504"
    end
    return false
end

local function try_next_server(candidates, attempt_field)
    local attempt = state[attempt_field] or 0
    if attempt < #candidates then
        state[attempt_field] = attempt + 1
        return true
    end
    state.battle_server_candidates = nil
    state[attempt_field] = 0
    return false
end

local function is_transient_http(code)
    return code == 429 or code == 502 or code == 503 or code == 504
end

function battle_fetch.start_snapshot_fetch(ctx, server_name, chain_next)
    if state.battle_fetch_pending then return end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" or util.safe_str(server_name) == "" then return end

    state.battle_fetch_pending = true
    state.battle_fetch_started_at = os.clock()
    state.battle_last_server_tried = server_name

    local url = battle_url(config.BATTLE_PATH or "/hud/battle", server_name, ctx.player_steam_id)
    battle_debug("fetch /battle server=" .. server_name)
    web_queue.get(url, "battle", function(err, response)
        state.battle_fetch_pending = false
        local now = os.clock()

        local function retry_or_fail(reason)
            local candidates = state.battle_server_candidates or {}
            if should_retry_server(reason) and try_next_server(candidates, "battle_fetch_attempt") then
                local next_name = current_server_name(candidates)
                if next_name ~= nil then
                    battle_fetch.start_snapshot_fetch(ctx, next_name, true)
                    return
                end
            end
            if reason == "no_battle" then
                if latch_active(now) then
                    battle_debug("snapshot no_battle ignored (latch)")
                    return
                end
                clear_battle_cache(false)
                state.battle_last_error = nil
                return
            end
            state.battle_last_error = reason or "battle_unavailable"
            battle_debug("snapshot fail: " .. tostring(reason))
        end

        if util.is_web_error(err) then
            retry_or_fail("network_error")
            return
        end

        state.last_http_status = util.http_status_code(response) or state.last_http_status
        local code = util.http_status_code(response)

        if is_transient_http(code) then
            state.battle_backoff_until = now + (config.BATTLE_BACKOFF_SEC or 2.5)
            battle_debug("snapshot http " .. tostring(code) .. " backoff")
            return
        end

        local raw, err_reason = util.read_api_response(err, response)
        if err_reason == "no_battle" or (code == 404 and raw ~= nil and raw.reason == "no_battle") then
            if latch_active(now) then
                battle_debug("snapshot 404 ignored (latch)")
                return
            end
            clear_battle_cache(false)
            state.battle_last_error = nil
            return
        end

        if err_reason ~= nil then
            retry_or_fail(err_reason)
            return
        end

        if raw == nil or raw.ok == false then
            retry_or_fail("battle_unavailable")
            return
        end

        state.battle_last_resolved_server_name = server_name
        state.battle_server_candidates = nil
        state.battle_fetch_attempt = 0
        apply_snapshot(raw, ctx.player_steam_id, now)
    end)
end

function battle_fetch.start_version_fetch(ctx, force_new_cycle, chain_next)
    if state.battle_version_pending or state.battle_fetch_pending then return end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" then return end

    local now = os.clock()
    if now < (state.battle_backoff_until or 0) then return end

    if force_new_cycle or state.battle_server_candidates == nil then
        server_candidates(ctx, true)
    end

    local candidates = state.battle_server_candidates or {}
    if #candidates == 0 then
        state.battle_last_error = "missing_server_name"
        return
    end

    if state.battle_version_fetch_attempt <= 0 then
        state.battle_version_fetch_attempt = 1
    end

    local server_name = candidates[state.battle_version_fetch_attempt]
    if server_name == nil then
        state.battle_version_fetch_attempt = 0
        state.battle_server_candidates = nil
        return
    end

    state.battle_version_pending = true
    state.battle_version_fetch_started_at = now
    state.battle_last_poll_at = now
    state.battle_last_server_tried = server_name

    local url = battle_url(config.BATTLE_VERSION_PATH or "/hud/battle/version", server_name, ctx.player_steam_id)
    web_queue.get(url, "battle_version", function(err, response)
        state.battle_version_pending = false
        local tick_now = os.clock()

        local function retry_or_fail(reason)
            if should_retry_server(reason) and try_next_server(candidates, "battle_version_fetch_attempt") then
                battle_fetch.start_version_fetch(ctx, false, true)
                return
            end
            if reason == "no_battle" then
                if latch_active(tick_now) then
                    battle_debug("version no_battle ignored (latch)")
                    return
                end
                clear_battle_cache(false)
                state.battle_last_error = nil
                return
            end
            state.battle_last_error = reason or "battle_unavailable"
        end

        if util.is_web_error(err) then
            retry_or_fail("network_error")
            return
        end

        state.last_http_status = util.http_status_code(response) or state.last_http_status
        local code = util.http_status_code(response)

        if is_transient_http(code) then
            state.battle_backoff_until = tick_now + (config.BATTLE_BACKOFF_SEC or 2.5)
            battle_debug("version http " .. tostring(code) .. " backoff")
            return
        end

        local raw, err_reason = util.read_api_response(err, response)
        if err_reason == "no_battle" or (code == 404 and raw ~= nil and raw.reason == "no_battle") then
            if latch_active(tick_now) then
                battle_debug("version 404 ignored (latch)")
                return
            end
            clear_battle_cache(false)
            state.battle_last_error = nil
            return
        end

        if err_reason ~= nil then
            retry_or_fail(err_reason)
            return
        end

        if raw == nil or raw.ok ~= true then
            retry_or_fail("battle_unavailable")
            return
        end

        local remote_version = util.safe_str(raw.version)
        state.battle_remote_version = remote_version
        state.battle_last_resolved_server_name = server_name
        state.battle_server_candidates = nil
        state.battle_version_fetch_attempt = 0
        state.battle_last_error = nil
        battle_debug("version=" .. remote_version .. " applied=" .. util.safe_str(state.battle_applied_version))

        if remote_version == "" or remote_version == "0" then
            if latch_active(tick_now) then
                battle_debug("version 0 ignored (latch)")
                return
            end
            state.battle_version = "0"
            state.battle_applied_version = ""
            clear_battle_cache(false)
            return
        end

        if battle_parse.should_refresh_snapshot(remote_version, state.battle_applied_version) then
            battle_fetch.start_snapshot_fetch(ctx, server_name, false)
        end
    end)
end

local function watchdog_timeouts(now)
    if state.battle_version_pending then
        local started = state.battle_version_fetch_started_at or 0
        if started > 0 and (now - started) > (state.BATTLE_VERSION_TIMEOUT_SEC or 12) then
            state.battle_version_pending = false
            state.battle_last_error = "battle_timeout"
        end
    end
    if state.battle_fetch_pending then
        local started = state.battle_fetch_started_at or 0
        if started > 0 and (now - started) > (state.BATTLE_FETCH_TIMEOUT_SEC or 12) then
            state.battle_fetch_pending = false
            state.battle_last_error = "battle_timeout"
        end
    end
end

function battle_fetch.get_battle(now)
    now = now or os.clock()

    if latch_active(now) then
        return with_toast_timeout(state.battle_finish_latch_snapshot, now)
    end

    if state.battle_ui ~= nil then
        return with_toast_timeout(state.battle_ui, now)
    end

    return nil
end

function battle_fetch.tick(ctx, now)
    now = now or os.clock()
    watchdog_timeouts(now)

    if latch_active(now) == false and (state.battle_result_hold_until or 0) > 0 then
        if now >= (state.battle_result_hold_until or 0) then
            battle_debug("latch OFF")
            state.battle_finish_latch_snapshot = nil
            state.battle_result_hold_until = 0
        end
    end

    if not context.battle_context_ready(ctx) then
        clear_battle_cache(false)
        return
    end

    if state.battle_version_pending or state.battle_fetch_pending then
        return
    end

    if now < (state.battle_backoff_until or 0) then return end

    local poll_ui = state.battle_ui
    if latch_active(now) and state.battle_finish_latch_snapshot ~= nil then
        poll_ui = state.battle_finish_latch_snapshot
    end
    local interval_ms = battle_parse.poll_interval_ms(poll_ui, state.battle_remote_version)
    local interval_sec = interval_ms / 1000
    if (now - (state.battle_last_poll_at or 0)) < interval_sec then
        return
    end

    battle_fetch.start_version_fetch(ctx, false, false)
end

function battle_fetch.reset()
    state.battle_version = ""
    state.battle_remote_version = ""
    state.battle_applied_version = ""
    state.battle_snapshot_raw = nil
    state.battle_ui = nil
    state.battle_finish_latch_snapshot = nil
    state.battle_last_battle_id = ""
    state.battle_version_pending = false
    state.battle_fetch_pending = false
    state.battle_last_poll_at = 0
    state.battle_last_error = nil
    state.battle_server_candidates = nil
    state.battle_fetch_attempt = 0
    state.battle_version_fetch_attempt = 0
    state.battle_result_hold_until = 0
    state.battle_last_event_ts = 0
    state.battle_version_fetch_started_at = 0
    state.battle_fetch_started_at = 0
    state.battle_backoff_until = 0
    state.battle_last_resolved_server_name = nil
    state.battle_last_server_tried = ""
    state.battle_event_shown_at = 0
    state.battle_last_snapshot_at = 0
end

return battle_fetch
