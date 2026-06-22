--[[ HTTP polling for /hud/battle/version and /hud/battle. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local web_queue = require("common.api.web_queue")
local battle_parse = require("common.api.battle_parse")

local battle_fetch = {}

local API_KEY_STORAGE = ac.storage("ProjectD-HUD:api_key", "")

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

local function clear_battle_cache(keep_hold)
    local now = os.clock()
    if keep_hold and state.battle_ui ~= nil and now < (state.battle_result_hold_until or 0) then
        state.battle_snapshot_raw = nil
        state.battle_version = "0"
        return
    end
    state.battle_snapshot_raw = nil
    state.battle_ui = nil
    state.battle_version = ""
    state.battle_result_hold_until = 0
end

local function apply_snapshot(raw, local_steam_id, now)
    if raw == nil then
        clear_battle_cache(false)
        return
    end

    local prev_state = state.battle_ui ~= nil and state.battle_ui.state or ""
    local v = util.safe_str(raw.version)
    state.battle_applied_version = v
    state.battle_version = v
    state.battle_remote_version = v
    state.battle_last_snapshot_at = now

    local ui = battle_parse.to_ui(raw, local_steam_id)
    if ui == nil then
        clear_battle_cache(false)
        return
    end

    local new_event_ts = tonumber(ui.event_ts) or 0
    if new_event_ts > 0 and new_event_ts ~= (state.battle_last_event_ts or 0) then
        state.battle_last_event_ts = new_event_ts
        state.battle_event_shown_at = now
    end

    if ui.state == "finished" or ui.state == "cancelled" then
        if prev_state ~= ui.state then
            state.battle_result_hold_until = battle_parse.start_result_hold(ui.state, now)
        end
    end

    state.battle_ui = ui
    state.battle_last_error = nil
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

function battle_fetch.start_snapshot_fetch(ctx, server_name, chain_next)
    if state.battle_fetch_pending then return end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" or util.safe_str(server_name) == "" then return end

    state.battle_fetch_pending = true
    state.battle_fetch_started_at = os.clock()
    state.battle_last_server_tried = server_name

    local url = battle_url(config.BATTLE_PATH or "/hud/battle", server_name, ctx.player_steam_id)
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
                clear_battle_cache(true)
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

        if code == 429 then
            state.battle_backoff_until = now + (config.BATTLE_BACKOFF_SEC or 5)
            state.battle_last_error = nil
            return
        end

        local raw, err_reason = util.read_api_response(err, response)
        if err_reason == "no_battle" or (code == 404 and raw ~= nil and raw.reason == "no_battle") then
            clear_battle_cache(true)
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
                clear_battle_cache(true)
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

        if code == 429 then
            state.battle_backoff_until = tick_now + (config.BATTLE_BACKOFF_SEC or 5)
            return
        end

        local raw, err_reason = util.read_api_response(err, response)
        if err_reason == "no_battle" or (code == 404 and raw ~= nil and raw.reason == "no_battle") then
            clear_battle_cache(true)
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

        if remote_version == "" or remote_version == "0" then
            state.battle_version = "0"
            state.battle_applied_version = ""
            clear_battle_cache(true)
            return
        end

        if battle_parse.should_refresh_snapshot(
            state.battle_ui,
            remote_version,
            state.battle_applied_version,
            state.battle_last_snapshot_at,
            tick_now
        ) then
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

    if state.battle_ui == nil then return nil end

    local ui = state.battle_ui
    local toast_sec = config.BATTLE_EVENT_TOAST_SEC or 2
    if ui.event_label ~= nil and ui.event_label ~= "" then
        local shown_at = state.battle_event_shown_at or 0
        if shown_at > 0 and (now - shown_at) > toast_sec then
            ui = {}
            for k, v in pairs(state.battle_ui) do ui[k] = v end
            ui.event_label = ""
        end
    end

    if state.battle_version == "0" or state.battle_version == "" then
        if now < (state.battle_result_hold_until or 0) then
            return ui
        end
        state.battle_ui = nil
        state.battle_result_hold_until = 0
        return nil
    end

    return ui
end

function battle_fetch.tick(ctx, now)
    now = now or os.clock()
    watchdog_timeouts(now)

    if state.battle_ui ~= nil and (state.battle_version == "0" or state.battle_version == "") then
        if now >= (state.battle_result_hold_until or 0) then
            state.battle_ui = nil
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

    local interval_ms = battle_parse.poll_interval_ms(state.battle_ui, state.battle_version)
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
