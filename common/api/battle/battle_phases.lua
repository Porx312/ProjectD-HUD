--[[ Battle phase resolution and display model for the HUD. ]]

local util = require("common.api.util")

local phases = {}

local PREP_LIVE = {
    arming = true,
    armed = true,
    launching = true,
    active = true,
}

local function battle_has_battle_id(ui)
    local id = ui.battle_id
    return id ~= nil and tostring(id) ~= ""
end

local function resolve_terminal(ui)
    local prep = string.lower(tostring(ui.prep_state or ui.state or "pairing"))
    local display = string.lower(tostring(ui.state or prep))
    local status_name = string.lower(tostring(ui.status or ""))
    local is_draw = status_name == "draw"

    if display == "finished" or display == "cancelled" then
        return true, display, status_name, is_draw
    end
    if prep == "finished" or prep == "cancelled" then
        return true, prep, status_name, is_draw
    end
    if status_name == "finished" or status_name == "cancelled" or is_draw then
        if status_name == "cancelled" then
            return true, "cancelled", status_name, is_draw
        end
        return true, "finished", status_name, is_draw
    end
    return false, prep, status_name, is_draw
end

local function center_image_key(ui, phase_state, is_terminal, is_draw)
    if is_terminal then
        if is_draw then return "draw" end
        if phase_state == "finished" then return "result" end
        if phase_state == "cancelled" then return "cancelled" end
        return nil
    end
    if ui.is_lobby == true or ui.looking_for_opponent == true then
        return "matchmaking"
    end
    if phase_state == "arming" or phase_state == "launching" then
        return "countdown"
    end
    local cd = tonumber(ui.arming_countdown)
    if phase_state == "pairing" and cd ~= nil and cd > 0 then
        return "countdown"
    end
    if phase_state == "arming" and cd ~= nil and cd == 0 then
        return "countdown"
    end
    if phase_state == "active" then
        return "points"
    end
    if phase_state == "armed" then
        return "vs"
    end
    if phase_state == "pairing" then
        return "matchmaking"
    end
    return nil
end

local function countdown_label(ui, phase_state)
    local cd = tonumber(ui.arming_countdown)
    if cd ~= nil and cd >= 0 then
        if cd > 0 then return tostring(math.floor(cd + 0.5)) end
        if phase_state == "launching" or phase_state == "arming" then return "GO!" end
    end
    local center_text = tostring(ui.center_text or ui.mode or "")
    if center_text ~= "" and tonumber(center_text) ~= nil then
        return center_text
    end
    if center_text == "GO!" then return center_text end
    if phase_state == "launching" then return "GO!" end
    if phase_state == "arming" then return "READY" end
    return "…"
end

function phases.arming_countdown_sec(raw)
    return tonumber(
        raw.armingCountdownSec
            or raw.arming_countdown_sec
            or raw.armingCountdown
            or raw.arming_countdown
            or raw.countdownSec
            or raw.countdown_sec
            or raw.countdown
    )
end

function phases.countdown_hint_from_raw(raw)
    return util.safe_str(
        raw.countdownHint
            or raw.countdown_hint
            or raw.armingHint
            or raw.arming_hint
    )
end

function phases.center_text_for(state_name, status_name, arming_countdown, local_player, looking, raw, last_event, local_steam_id, terminal_display_text)
    local is_terminal = state_name == "finished" or state_name == "cancelled"
        or status_name == "finished" or status_name == "cancelled" or status_name == "draw"

    if is_terminal then
        return terminal_display_text(raw, state_name, status_name, last_event, local_steam_id)
    end
    if looking then return "LOOKING" end
    if state_name == "pairing" then return "" end
    if state_name == "arming" then
        local n = tonumber(arming_countdown)
        if n ~= nil and n > 0 then return tostring(math.floor(n)) end
        return "READY"
    end
    if state_name == "armed" then return "ARMED" end
    if state_name == "launching" then return "GO!" end
    if state_name == "active" then
        local role = string.upper(util.safe_str(local_player and local_player.role))
        if role == "LEAD" or role == "CHASE" then return role end
        return "ACTIVE"
    end
    return string.upper(state_name)
end

function phases.parse_gap(raw, local_player, default_disappear_gap_m)
    local gap3d = tonumber(raw.gap3dM or raw.gap_3d_m or raw.gap3d_m)
    local disappear = tonumber(raw.disappearGapM or raw.disappear_gap_m or raw.disappear_gap_m)
    if disappear == nil or disappear <= 0 then
        disappear = default_disappear_gap_m or 250
    end
    if gap3d == nil then gap3d = 0 end
    local abs_m = math.max(0, gap3d)
    local role = string.upper(util.safe_str(local_player and local_player.role))
    local opponent_ahead = nil
    local signed = 0
    if role == "LEAD" then
        opponent_ahead = false
        signed = abs_m
    elseif role == "CHASE" then
        opponent_ahead = true
        signed = -abs_m
    end
    return {
        current = abs_m,
        max = disappear,
        signed = signed,
        opponent_ahead = opponent_ahead,
    }
end

function phases.build_display(ui, resolve_winner_display)
    if ui == nil then return nil end

    local is_terminal, terminal_state, status_name, is_draw = resolve_terminal(ui)
    local phase_state = is_terminal and terminal_state
        or string.lower(tostring(ui.prep_state or ui.state or "pairing"))
    local center_key = center_image_key(ui, phase_state, is_terminal, is_draw)

    local show_searching = false
    if ui.is_lobby == true then
        show_searching = true
    elseif ui.looking_for_opponent == true and not battle_has_battle_id(ui) and PREP_LIVE[phase_state] ~= true then
        show_searching = true
    end

    local show_center_scores = false
    if not is_terminal and phase_state ~= "pairing" then
        if ui.show_scores == true then
            show_center_scores = true
        elseif ui.show_prep_scores == true and (center_key == "vs" or center_key == "points") then
            show_center_scores = true
        elseif phase_state == "active" then
            show_center_scores = true
        end
    end

    local show_phase_label = true
    if phase_state == "pairing" and center_key ~= "matchmaking" then
        show_phase_label = false
    end

    local center_text = tostring(ui.center_text or ui.mode or "")
    if center_text == "" and not is_terminal then
        center_text = string.upper(phase_state)
    end

    local center_label = ""
    if center_key == "countdown" then
        center_label = countdown_label(ui, phase_state)
        if center_label == "" or center_label == "…" then
            local fallback = tostring(ui.center_text or ui.mode or "")
            if fallback ~= "" then center_label = fallback end
        end
    end

    return {
        phase_state = phase_state,
        status_name = status_name,
        is_terminal = is_terminal,
        is_draw = is_draw,
        center_key = center_key,
        center_label = center_label,
        center_text = center_text,
        show_center_scores = show_center_scores,
        show_phase_label = show_phase_label,
        show_searching = show_searching,
        show_live_event_top = not is_terminal
            and (phase_state == "active" or phase_state == "armed" or phase_state == "launching"),
        winner_display_name = resolve_winner_display ~= nil and resolve_winner_display(ui) or "",
        show_countdown_hint = (phase_state == "arming" or phase_state == "armed")
            and util.safe_str(ui.countdown_hint) ~= "",
    }
end

function phases.attach_display(ui, resolve_winner_display)
    if ui == nil then return nil end
    ui.display = phases.build_display(ui, resolve_winner_display)
    return ui
end

return phases
