--[[ HTTP fetch orchestration for /hud/session and /hud/player. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local profile = require("common.api.profile")
local parse = require("common.api.parse")
local bundle = require("common.api.bundle")
local web_queue = require("common.api.web_queue")
local sync = require("common.api.sync")

local fetch = {}

local function finish_fetch_lock()
    sync.release_fetch_lock()
    sync.publish_meta()
end

local function safe_web_get(url, kind, callback)
    web_queue.get(url, kind, callback)
end

local function profile_fetch_url(ctx, server_name)
    return string.format(
        "%s%s?steamId=%s&serverName=%s&track=%s&trackConfig=%s&carModel=%s",
        config.API_BASE_URL,
        config.PLAYER_PATH or "/hud/player",
        util.url_encode(ctx.player_steam_id),
        util.url_encode(server_name),
        util.url_encode(ctx.track_id),
        util.url_encode(ctx.layout_id),
        util.url_encode(ctx.car_id)
    )
end

local function profile_server_list(ctx)
    if state.profile_server_candidates ~= nil and #state.profile_server_candidates > 0 then
        return state.profile_server_candidates
    end
    local list = {}
    local function push(name)
        name = util.normalize_server_name(name)
        if name == "" then return end
        list[#list + 1] = name
    end
    if state.last_resolved_server_name ~= nil and state.last_resolved_server_name ~= "" then
        push(state.last_resolved_server_name)
        state.profile_server_candidates = list
        return list
    end
    if state.cached_bundle ~= nil and state.cached_bundle.context ~= nil then
        push(state.cached_bundle.context.server_name)
    end
    push(steam.server_name_from_race_ini())
    push(ctx.server_name)
    state.profile_server_candidates = list
    return list
end

local function retryable_api_reason(reason)
    return reason == "server_not_found"
        or reason == "track_not_found"
        or reason == "car_not_found"
        or (reason ~= nil and string.sub(reason, 1, 4) == "http")
end

local function mark_profile_candidates_exhausted(reason)
    state.profile_candidates_exhausted = true
    state.profile_server_candidates = nil
    state.profile_fetch_attempt = 0
    if reason ~= nil and reason ~= "" then
        state.last_error = tostring(reason)
    elseif state.last_error == nil then
        state.last_error = "profile_unavailable"
    end
end

function fetch.start_profile_fetch(ctx, force_new_cycle, chain_next)
    if not bundle.bundle_needs_profile() then
        state.profile_candidates_exhausted = false
        return
    end
    if state.profile_fetch_pending then return end
    if state.fetch_pending and not chain_next then return end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" or util.safe_str(ctx.track_id) == "" then return end

    local now = os.clock()
    if not chain_next and not force_new_cycle and state.profile_candidates_exhausted then
        if (now - state.last_profile_attempt_at) < state.PROFILE_RETRY_SEC then return end
        state.profile_candidates_exhausted = false
    end
    if not chain_next and not force_new_cycle and (now - state.last_profile_attempt_at) < state.PROFILE_RETRY_SEC then
        return
    end

    if force_new_cycle or state.profile_server_candidates == nil then
        state.profile_server_candidates = nil
        state.profile_fetch_attempt = 0
        state.profile_candidates_exhausted = false
    end

    local candidates = profile_server_list(ctx)
    if #candidates == 0 then
        mark_profile_candidates_exhausted("missing_server_name")
        return
    end

    state.profile_fetch_attempt = state.profile_fetch_attempt + 1
    local server_name = candidates[state.profile_fetch_attempt]
    if server_name == nil then
        mark_profile_candidates_exhausted("profile_unavailable")
        return
    end

    state.last_profile_attempt_at = now
    state.profile_fetch_pending = true
    state.profile_fetch_started_at = now
    local url = profile_fetch_url(ctx, server_name)
    if state.is_debug() then
        ac.debug("ProjectD-HUD profile GET", url)
    end

    safe_web_get(url, "profile", function(err, response)
        state.profile_fetch_pending = false
        sync.publish_meta()

        local function try_next(reason)
            if state.profile_fetch_attempt < #candidates then
                fetch.start_profile_fetch(ctx, false, true)
                return
            end
            mark_profile_candidates_exhausted(reason)
        end

        local raw, api_reason = util.read_api_payload(err, response)
        state.last_http_status = util.http_status_code(response) or state.last_http_status
        state.last_api_reason = api_reason or ""

        if api_reason == "network_error" then
            try_next("network_error")
            return
        end

        if api_reason ~= nil and api_reason ~= "" then
            if retryable_api_reason(api_reason) and state.profile_fetch_attempt < #candidates then
                fetch.start_profile_fetch(ctx, false, true)
                return
            end
            if raw == nil then
                try_next(api_reason)
                return
            end
            if raw.ok == false then
                local reason = tostring(raw.reason or raw.error or api_reason)
                if retryable_api_reason(reason) and state.profile_fetch_attempt < #candidates then
                    fetch.start_profile_fetch(ctx, false, true)
                    return
                end
                state.last_error = reason
                state.profile_candidates_exhausted = true
                return
            end
            try_next(api_reason)
            return
        end

        if raw == nil then
            try_next("json_parse_failed")
            return
        end

        local p = profile.coalesce_profile(raw.profile)
        if p ~= nil then
            state.last_resolved_server_name = server_name
            state.profile_server_candidates = nil
            state.profile_fetch_attempt = 0
            state.profile_candidates_exhausted = false
            state.last_session_had_players = true
            bundle.merge_profile_into_bundle(p)
            state.last_error = nil
            return
        end

        if raw.context ~= nil then
            state.last_error = "profile_unavailable"
        else
            state.last_error = "user_not_found"
        end
        state.profile_candidates_exhausted = true
    end)
end

local function session_url(ctx, plan, car_filter)
    return string.format(
        "%s%s?steamIds=%s&serverName=%s&track=%s&trackConfig=%s&carFilter=%s&carModel=%s",
        config.API_BASE_URL,
        config.SESSION_PATH,
        util.url_encode(ctx.player_steam_id),
        util.url_encode(plan.server_name),
        util.url_encode(plan.track_id),
        util.url_encode(plan.layout_id),
        util.url_encode(car_filter),
        util.url_encode(ctx.car_id)
    )
end

local function run_scheduled_filter_fetch(ctx)
    local next_filter = state.scheduled_filter_fetch
    if next_filter == nil or next_filter == "" then return end
    state.scheduled_filter_fetch = nil
    if bundle.get_cached_leaderboard(next_filter) ~= nil then
        bundle.try_switch_filter(next_filter)
        return
    end
    if not state.fetch_pending then
        fetch.start_fetch(ctx, next_filter, false)
    end
end

function fetch.start_fetch(ctx, car_filter, force_new_cycle)
    car_filter = car_filter or "global"
    if sync.is_fetch_locked() and not state.fetch_pending then
        state.scheduled_filter_fetch = car_filter
        return
    end
    if state.fetch_pending then
        if car_filter ~= state.fetch_car_filter then
            state.scheduled_filter_fetch = car_filter
        end
        return
    end
    if not sync.acquire_fetch_lock(car_filter) then
        state.scheduled_filter_fetch = car_filter
        return
    end

    ctx.player_steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if util.safe_str(ctx.track_id) == "" then
        state.last_error = "missing_track"
        finish_fetch_lock()
        return
    end
    if ctx.player_steam_id == "" then
        state.last_error = "missing_steam"
        finish_fetch_lock()
        return
    end

    if force_new_cycle or state.fetch_plans == nil then
        state.fetch_plans = context.build_fetch_plans(ctx)
        state.server_name_candidates = context.build_server_name_candidates(ctx)
        state.fetch_attempt = 0
    end

    if state.fetch_plans == nil or #state.fetch_plans == 0 then
        state.last_error = "missing_server_name"
        finish_fetch_lock()
        return
    end

    state.fetch_attempt = state.fetch_attempt + 1
    local plan = state.fetch_plans[state.fetch_attempt]
    if plan == nil then
        state.fetch_attempt = 0
        finish_fetch_lock()
        return
    end

    state.last_fetch_plan = plan
    local url = session_url(ctx, plan, car_filter)
    state.fetch_pending = true
    state.fetch_car_filter = car_filter
    state.last_fetch_at = os.clock()
    state.session_fetch_started_at = os.clock()
    state.last_session_had_players = false
    if state.is_debug() then
        ac.debug("ProjectD-HUD session GET", url)
    end

    safe_web_get(url, "session", function(err, response)
        state.fetch_pending = false
        local raw, api_reason, http_code = util.read_api_payload(err, response)
        state.last_http_status = http_code or (response and response.status) or nil
        state.last_api_reason = api_reason or ""

        local function retry_or_finish(fail_reason)
            if fail_reason ~= nil and fail_reason ~= "" then
                state.last_error = fail_reason
            end
            if state.fetch_attempt < #(state.fetch_plans or {}) then
                finish_fetch_lock()
                fetch.start_fetch(ctx, car_filter, false)
                return
            end
            finish_fetch_lock()
            run_scheduled_filter_fetch(ctx)
        end

        if api_reason == "network_error" then
            retry_or_finish("network_error")
            return
        end

        if api_reason ~= nil and api_reason ~= "" then
            if raw ~= nil and raw.ok == false then
                api_reason = tostring(raw.reason or raw.error or api_reason)
            end
            if retryable_api_reason(api_reason) then
                retry_or_finish(api_reason)
                return
            end
            if raw == nil then
                retry_or_finish(api_reason)
                return
            end
        end

        if raw == nil then
            retry_or_finish("json_parse_failed")
            return
        end

        local data = parse.normalize_session_response(raw, ctx.player_steam_id)
        if data == nil then
            retry_or_finish(state.last_error or "parse_failed")
            return
        end

        state.last_resolved_server_name = plan.server_name
        state.last_error = nil
        state.last_api_reason = ""
        bundle.apply_bundle(data, car_filter)
        state.profile_candidates_exhausted = false
        finish_fetch_lock()
        if bundle.bundle_needs_profile() and not state.profile_fetch_pending then
            fetch.start_profile_fetch(ctx, false, false)
        else
            state.profile_server_candidates = nil
            state.profile_fetch_attempt = 0
        end
        run_scheduled_filter_fetch(ctx)
    end)
end

function fetch.fetch_session(car_filter, force)
    car_filter = car_filter or "global"
    local now = os.clock()

    if not force and bundle.try_switch_filter(car_filter) then
        return
    end

    if not force and state.cached_bundle ~= nil and state.cached_filter == car_filter then
        if (now - state.cached_at) < config.CACHE_TTL_SEC then
            if bundle.bundle_needs_profile() and not state.profile_fetch_pending then
                local ok_ctx, ctx = pcall(context.read_session_context)
                if ok_ctx then fetch.start_profile_fetch(ctx, false, false) end
            end
            return
        end
    end

    local ok, ctx = pcall(context.read_session_context)
    if not ok then
        state.last_error = "context_error"
        ac.debug("ProjectD-HUD context", util.safe_str(ctx))
        return
    end

    local retry_sec = context.context_is_ready(ctx) and config.CACHE_TTL_SEC or state.CONTEXT_RETRY_SEC
    if not force and state.cached_bundle == nil and (now - state.last_attempt_at) < retry_sec then
        return
    end
    state.last_attempt_at = now

    fetch.start_fetch(ctx, car_filter, force == true)
end

function fetch.watchdog_profile_fetch(ctx)
    if not state.profile_fetch_pending then return end
    if (os.clock() - state.profile_fetch_started_at) < state.PROFILE_FETCH_TIMEOUT_SEC then return end
    state.profile_fetch_pending = false
    ac.debug("ProjectD-HUD profile", "fetch timeout")
    if state.profile_server_candidates ~= nil and state.profile_fetch_attempt < #state.profile_server_candidates then
        fetch.start_profile_fetch(ctx, false, true)
    else
        mark_profile_candidates_exhausted("profile_timeout")
    end
end

function fetch.watchdog_session_fetch(ctx, car_filter)
    if not state.fetch_pending then return end
    if (os.clock() - state.session_fetch_started_at) < state.SESSION_FETCH_TIMEOUT_SEC then return end
    state.fetch_pending = false
    ac.debug("ProjectD-HUD session", "fetch timeout")
    state.last_error = "session_timeout"
    finish_fetch_lock()
    if state.fetch_plans ~= nil and state.fetch_attempt < #state.fetch_plans then
        fetch.start_fetch(ctx, car_filter or state.cached_filter, false)
    else
        run_scheduled_filter_fetch(ctx)
    end
end

return fetch
