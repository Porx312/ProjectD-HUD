--[[ Battle HUD state: apply SSE snapshots, latch, lobby transition. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local profile = require("common.api.profile")
local battle_parse = require("common.api.battle_parse")

local battle_fetch = {}

local DEBUG_STORAGE = ac.storage("ProjectD-HUD:battle_debug", false)

local PREP_PHASES = {
    pairing = true,
    arming = true,
    armed = true,
    launching = true,
}

local COUNTDOWN_PHASES = {
    arming = true,
    pairing = true,
}

local PHASE_HOLD_SEC = 1.5
local NO_BATTLE_CLEAR_GRACE_SEC = 4
local NO_BATTLE_CLEAR_STREAK = 2

local function battle_debug(msg)
    if DEBUG_STORAGE:get() == true then
        ac.debug("ProjectD-HUD battle", util.safe_str(msg))
    end
end

function battle_fetch.debug(msg)
    battle_debug(msg)
end

local function ensure_battle_runtime()
    if state.battle_runtime ~= nil then return end
    state.battle_runtime = {
        arming_cd = state.battle_last_arming_cd,
        arming_since = state.battle_prep_cd1_since or 0,
        last_snapshot_version = "",
        last_snapshot_state = "",
    }
end

local function reset_arming_countdown_anchor()
    ensure_battle_runtime()
    state.battle_last_arming_cd = nil
    state.battle_prep_cd1_since = 0
    state.battle_cd_received_at = 0
    if state.battle_runtime ~= nil then
        state.battle_runtime.arming_cd = nil
        state.battle_runtime.arming_since = 0
    end
end

local function sync_arming_runtime(cd, since)
    state.battle_last_arming_cd = cd
    state.battle_prep_cd1_since = since
    state.battle_cd_received_at = since
    if state.battle_runtime ~= nil then
        state.battle_runtime.arming_cd = cd
        state.battle_runtime.arming_since = since
    end
end

local function countdown_phase(ui)
    if ui == nil then return nil end
    local phase = string.lower(util.safe_str(ui.state))
    if COUNTDOWN_PHASES[phase] then
        local cd = tonumber(ui.arming_countdown)
        if cd ~= nil and cd >= 0 then return phase end
    end
    if phase == "launching" then return phase end
    return nil
end

local function read_arming_cd()
    if state.battle_runtime ~= nil and state.battle_runtime.arming_cd ~= nil then
        return tonumber(state.battle_runtime.arming_cd)
    end
    return tonumber(state.battle_last_arming_cd)
end

local function read_arming_since()
    if state.battle_runtime ~= nil and (state.battle_runtime.arming_since or 0) > 0 then
        return state.battle_runtime.arming_since
    end
    return state.battle_prep_cd1_since or 0
end

--- Re-anchor countdown from each poll snapshot; interpolate locally between polls.
local function sync_arming_countdown_anchor(ui, now)
    now = now or os.clock()
    local phase = countdown_phase(ui)
    if phase == nil then
        if string.lower(util.safe_str(ui and ui.state)) ~= "launching" then
            reset_arming_countdown_anchor()
        end
        return
    end

    local cd = tonumber(ui.arming_countdown)
    if cd == nil and phase ~= "launching" then return end

    sync_arming_runtime(cd or 0, now)
    battle_debug("arming cd anchor " .. tostring(cd))
end

local function live_arming_countdown(now)
    local base = read_arming_cd()
    local since = state.battle_cd_received_at or 0
    if since <= 0 then since = read_arming_since() end
    if base == nil or since <= 0 then return nil end
    local elapsed = math.max(0, (now or os.clock()) - since)
    return math.max(0, math.floor(base - elapsed + 0.0001))
end

local function apply_go_hold_ui(ui, now)
    local copy = battle_parse.deep_copy_ui(ui)
    if copy == nil then return ui end
    copy.arming_countdown = 0
    copy.center_text = "GO!"
    copy.mode = "GO!"
    if string.lower(util.safe_str(copy.state)) == "arming" then
        copy.state = "launching"
    end
    return battle_parse.attach_display(copy)
end

local function apply_live_arming_countdown(ui, now)
    if ui == nil then return ui end
    now = now or os.clock()

    local hold_until = state.battle_phase_hold_until or 0
    if hold_until > 0 and now < hold_until then
        local phase = string.lower(util.safe_str(ui.state))
        if phase == "armed" or phase == "launching" or phase == "active" then
            state.battle_phase_hold_until = 0
        else
            return apply_go_hold_ui(ui, now)
        end
    end

    local phase = countdown_phase(ui)
    if phase == "launching" then
        return apply_go_hold_ui(ui, now)
    end

    local phase_name = string.lower(util.safe_str(ui.state))
    if phase == nil then
        if phase_name == "arming" or phase_name == "launching" then
            local fallback_cd = read_arming_cd()
            local fallback_text = util.safe_str(ui.center_text or ui.mode)
            if fallback_cd ~= nil or fallback_text ~= "" then
                local copy = battle_parse.deep_copy_ui(ui)
                if copy ~= nil then
                    if fallback_cd ~= nil then
                        copy.arming_countdown = fallback_cd
                        copy.center_text = fallback_cd > 0 and tostring(fallback_cd) or "GO!"
                        copy.mode = copy.center_text
                    elseif fallback_text ~= "" then
                        copy.center_text = fallback_text
                        copy.mode = fallback_text
                    end
                    return battle_parse.attach_display(copy)
                end
            end
        end
        return ui
    end

    local live = live_arming_countdown(now)
    if live == nil then
        local anchored = read_arming_cd()
        if anchored ~= nil then
            live = anchored
        else
            local center_text = util.safe_str(ui.center_text or ui.mode)
            if tonumber(center_text) ~= nil then
                live = tonumber(center_text)
            end
        end
        if live == nil then return ui end
    end

    if live == 0 and string.lower(util.safe_str(ui.state)) == "arming" then
        state.battle_phase_hold_until = now + PHASE_HOLD_SEC
        return apply_go_hold_ui(ui, now)
    end

    local center = live > 0 and tostring(live) or "GO!"
    if center == tostring(ui.center_text or ui.mode or "") and live == tonumber(ui.arming_countdown) then
        return ui
    end

    local copy = battle_parse.deep_copy_ui(ui)
    if copy == nil then return ui end
    copy.arming_countdown = live
    copy.center_text = center
    copy.mode = center
    return battle_parse.attach_display(copy)
end

local function latch_active(now)
    now = now or os.clock()
    return now < (state.battle_result_hold_until or 0)
        and state.battle_finish_latch_snapshot ~= nil
end

local function copy_player_ui(p)
    if p == nil then return nil end
    return {
        name = p.name,
        tier = p.tier,
        avatar_url = p.avatar_url,
        car_name = p.car_name,
        role = p.role,
        elo = p.elo,
        placeholder = p.placeholder == true,
    }
end

local function clear_battle_cache(keep_latch)
    if keep_latch and latch_active(os.clock()) then
        state.battle_snapshot_raw = nil
        state.battle_ui = nil
        battle_debug("clear_battle_cache keep_latch")
        return
    end
    state.battle_snapshot_raw = nil
    state.battle_ui = nil
    state.battle_finish_latch_snapshot = nil
    state.battle_result_hold_until = 0
    battle_debug("clear_battle_cache full")
end

local function ensure_end_latch_before_clear(now)
    if latch_active(now) then return end
    if state.battle_ui == nil then return end

    if battle_parse.is_terminal_ui(state.battle_ui) then
        state.battle_finish_latch_snapshot = battle_parse.deep_copy_ui(state.battle_ui)
        state.battle_result_hold_until = battle_parse.start_result_hold(now, state.battle_ui)
        state.battle_ui = nil
        state.battle_snapshot_raw = nil
        battle_debug("latch ON (terminal ui)")
        return
    end

    local reason = "CANCELLED"
    if util.safe_str(state.battle_ui.end_label) ~= "" then
        reason = state.battle_ui.end_label
    elseif util.safe_str(state.battle_ui.event_label) ~= "" then
        reason = state.battle_ui.event_label
    end
    local synth = battle_parse.synthesize_end_ui(state.battle_ui, reason)
    if synth ~= nil then
        state.battle_finish_latch_snapshot = synth
        state.battle_result_hold_until = battle_parse.start_result_hold(now, synth)
        state.battle_ui = nil
        state.battle_snapshot_raw = nil
        battle_debug("latch ON (synthetic " .. tostring(reason) .. ")")
    end
end

local function clear_idle_battle_state(now)
    now = now or os.clock()
    if state.battle_ui ~= nil and not battle_parse.is_terminal_ui(state.battle_ui) then
        ensure_end_latch_before_clear(now)
    end
    if latch_active(now) then
        clear_battle_cache(true)
        return
    end
    clear_battle_cache(false)
    state.battle_last_battle_id = ""
end

local function reset_battle_session()
    state.battle_last_event_ts = 0
    state.battle_event_shown_at = 0
    state.battle_finish_latch_snapshot = nil
    state.battle_result_hold_until = 0
    reset_arming_countdown_anchor()
end

function battle_fetch.apply_snapshot(raw, local_steam_id, now)
    now = now or os.clock()
    ensure_battle_runtime()
    if raw == nil then
        clear_idle_battle_state(now)
        return
    end

    if raw.ok == false then
        battle_fetch.handle_battle_clear(raw, now)
        return
    end

    local battle_id = util.safe_str(raw.battleId)
    local prev_battle_id = state.battle_last_battle_id or ""
    local battle_id_changed = battle_id ~= "" and battle_id ~= prev_battle_id
    if battle_id_changed then
        if prev_battle_id ~= "" then
            reset_battle_session()
            state.battle_ui = nil
            state.battle_snapshot_raw = nil
            battle_debug("battleId changed -> reset session " .. battle_id)
        end
        state.battle_last_battle_id = battle_id
    end

    local ui = battle_parse.to_ui(raw, local_steam_id)
    if ui == nil then
        clear_idle_battle_state(now)
        return
    end

    local prev_ui = battle_id_changed and nil or state.battle_ui
    battle_parse.merge_players_from_previous(ui, prev_ui)

    local bundled_prof = profile.coalesce_profile(state.cached_bundle and state.cached_bundle.profile)
    local session_tier = profile.tier_for_display(bundled_prof)
    if session_tier > 0 and ui.player_left ~= nil and ui.player_left.placeholder ~= true then
        if profile.tier_for_display(ui.player_left) <= 0 then
            ui.player_left = battle_parse.merge_player_ui({ tier = session_tier }, ui.player_left)
        end
    end

    if util.is_presence_fatal(state.last_error) then
        state.last_error = nil
    end

    if util.is_presence_fatal(state.battle_last_error) and util.ignore_presence_error(state.battle_last_error) then
        state.battle_last_error = nil
    end

    if battle_parse.is_terminal_ui(ui) and prev_ui ~= nil then
        local pr = ui.player_right
        if pr ~= nil and pr.placeholder and prev_ui.player_right ~= nil and prev_ui.player_right.placeholder ~= true then
            ui.player_right = copy_player_ui(prev_ui.player_right)
            ui.score_right = prev_ui.score_right or ui.score_right
            ui.looking_for_opponent = false
        end
    end

    state.battle_last_snapshot_at = now
    state.battle_last_error = nil
    state.battle_no_battle_streak = 0
    state.battle_phase_hold_until = 0
    if state.battle_runtime ~= nil then
        state.battle_runtime.last_snapshot_version = util.safe_str(raw.version)
        state.battle_runtime.last_snapshot_state = util.safe_str(ui.state)
    end

    local new_event_ts = tonumber(ui.event_ts) or 0
    local score_changed = prev_ui == nil
        or (tonumber(ui.score_left) or 0) ~= (tonumber(prev_ui.score_left) or 0)
        or (tonumber(ui.score_right) or 0) ~= (tonumber(prev_ui.score_right) or 0)
    local should_toast = new_event_ts > (state.battle_last_event_ts or 0)
        or (ui.state == "active" and score_changed and util.safe_str(ui.event_label) ~= "")
    local prev_log_len = 0
    if prev_ui ~= nil and type(prev_ui.points_log) == "table" then
        prev_log_len = #prev_ui.points_log
    end
    local new_log_len = type(ui.points_log) == "table" and #ui.points_log or 0
    if ui.state == "active" and new_log_len > prev_log_len and util.safe_str(ui.event_label) ~= "" then
        should_toast = true
    end
    if should_toast then
        if new_event_ts > (state.battle_last_event_ts or 0) then
            state.battle_last_event_ts = new_event_ts
        end
        state.battle_event_shown_at = now
        battle_debug("event toast: " .. util.safe_str(ui.event_label))
    end

    if battle_parse.is_terminal_ui(ui) then
        state.battle_finish_latch_snapshot = battle_parse.deep_copy_ui(ui)
        state.battle_result_hold_until = battle_parse.start_result_hold(now, ui)
        state.battle_event_shown_at = now
        state.battle_ui = nil
        state.battle_snapshot_raw = nil
        battle_debug("latch ON state=" .. ui.state .. " -> lobby after hold")
    else
        state.battle_snapshot_raw = raw
        state.battle_ui = ui
        sync_arming_countdown_anchor(ui, now)
    end

    battle_debug(string.format(
        "apply_snapshot ok v=%s state=%s cd=%s scores=%d-%d",
        util.safe_str(raw.version),
        ui.state,
        tostring(ui.arming_countdown or "-"),
        ui.score_left or 0,
        ui.score_right or 0
    ))
end

function battle_fetch.handle_battle_clear(payload, now)
    now = now or os.clock()
    if latch_active(now) then
        battle_debug("battle:clear ignored (latch)")
        return
    end
    local reason = payload ~= nil and util.safe_str(payload.reason) or "no_battle"
    if reason == "no_battle" or payload == nil then
        local streak = (state.battle_no_battle_streak or 0) + 1
        state.battle_no_battle_streak = streak

        local ui = state.battle_ui
        local snap_at = state.battle_last_snapshot_at or 0
        local age = now - snap_at

        if ui ~= nil then
            local phase = string.lower(util.safe_str(ui.state))
            if PREP_PHASES[phase] and age < NO_BATTLE_CLEAR_GRACE_SEC then
                battle_debug("battle:clear ignored (prep grace age=" .. string.format("%.1f", age) .. "s)")
                return
            end
        end

        if streak < NO_BATTLE_CLEAR_STREAK and age < NO_BATTLE_CLEAR_GRACE_SEC then
            battle_debug("battle:clear ignored (streak=" .. tostring(streak) .. ")")
            return
        end

        state.battle_no_battle_streak = 0
        state.battle_phase_hold_until = 0
        clear_idle_battle_state(now)
        state.battle_last_error = nil
        battle_debug("battle:clear -> idle")
    end
end

local function with_toast_timeout(ui, now)
    if ui == nil then return nil end
    if battle_parse.is_terminal_ui(ui) then
        return ui
    end
    now = now or os.clock()
    ui = apply_live_arming_countdown(ui, now)
    local toast_sec = config.BATTLE_EVENT_TOAST_SEC or 2
    if ui.event_label ~= nil and ui.event_label ~= "" then
        local shown_at = state.battle_event_shown_at or 0
        if shown_at > 0 and (now - shown_at) > toast_sec then
            local copy = battle_parse.deep_copy_ui(ui)
            if copy ~= nil then
                copy.event_label = ""
                return battle_parse.attach_display(copy)
            end
        end
    end
    return ui
end

function battle_fetch.is_session_live(now)
    now = now or os.clock()
    if latch_active(now) then return true end
    if state.battle_ui ~= nil then
        return not battle_parse.is_terminal_ui(state.battle_ui)
    end
    return false
end

function battle_fetch.get_battle(now)
    now = now or os.clock()

    if latch_active(now) then
        return with_toast_timeout(state.battle_finish_latch_snapshot, now)
    end

    if state.battle_ui ~= nil then
        if battle_parse.is_terminal_ui(state.battle_ui) then
            state.battle_ui = nil
            state.battle_snapshot_raw = nil
            return nil
        end
        return with_toast_timeout(state.battle_ui, now)
    end

    return nil
end

function battle_fetch.tick_latch(now)
    now = now or os.clock()
    if latch_active(now) == false and (state.battle_result_hold_until or 0) > 0 then
        if now >= (state.battle_result_hold_until or 0) then
            battle_debug("latch OFF -> lobby")
            clear_battle_cache(false)
            state.battle_last_battle_id = ""
        end
    end
end

function battle_fetch.reset()
    state.battle_snapshot_raw = nil
    state.battle_ui = nil
    state.battle_finish_latch_snapshot = nil
    state.battle_last_battle_id = ""
    state.battle_last_error = nil
    state.battle_result_hold_until = 0
    state.battle_last_event_ts = 0
    state.battle_event_shown_at = 0
    state.battle_last_snapshot_at = 0
    state.battle_no_battle_streak = 0
    state.battle_phase_hold_until = 0
    state.battle_cd_received_at = 0
    if state.battle_runtime ~= nil then
        state.battle_runtime.last_snapshot_version = ""
        state.battle_runtime.last_snapshot_state = ""
    end
    reset_arming_countdown_anchor()
end

return battle_fetch
