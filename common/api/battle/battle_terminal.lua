--[[ Battle terminal states: finished, cancelled, draw. ]]

local config = require("common.config")
local util = require("common.api.util")

local terminal = {}

local function format_reason_code(code)
    code = util.safe_str(code)
    if code == "" then return "" end
    return string.upper(code:gsub("_", " "))
end

local function event_label_from_entry(entry, local_steam_id, format_point_label)
    return format_point_label(entry, local_steam_id)
end

function terminal.format_reason_code(code)
    return format_reason_code(code)
end

function terminal.terminal_center_text(raw, state_name, status_name)
    local end_label = util.safe_str(raw.endLabel or raw.end_label)
    if status_name == "draw" then return "DRAW" end

    if state_name == "cancelled" or status_name == "cancelled" then
        local cr = util.safe_str(raw.cancelReason or raw.cancel_reason)
        if cr ~= "" then return format_reason_code(cr) end
        if end_label ~= "" then return end_label end
        return "CANCELLED"
    end

    if state_name == "finished" or status_name == "finished" then
        local er = util.safe_str(raw.endReason or raw.end_reason)
        if er ~= "" then return format_reason_code(er) end
        if end_label ~= "" then return end_label end
        return "FINISHED"
    end

    return "ENDED"
end

function terminal.terminal_toast_text(raw, state_name, status_name, last_event, local_steam_id, format_point_label)
    local end_label = util.safe_str(raw.endLabel or raw.end_label)
    local cancel = format_reason_code(raw.cancelReason or raw.cancel_reason)
    local end_reason = format_reason_code(raw.endReason or raw.end_reason)

    if state_name == "cancelled" or status_name == "cancelled" then
        if end_label ~= "" and end_label ~= terminal.terminal_center_text(raw, state_name, status_name) then
            return end_label
        end
        if cancel ~= "" then return cancel end
        return end_label
    end

    if state_name == "finished" or status_name == "finished" or status_name == "draw" then
        if end_label ~= "" then return end_label end
        if end_reason ~= "" then return end_reason end
        local finish_gap = tonumber(raw.finishGapM or raw.finish_gap_m)
        if finish_gap ~= nil and finish_gap > 0 then
            return string.format("FINISH GAP %dm", math.floor(finish_gap + 0.5))
        end
        if last_event ~= nil then
            local label = event_label_from_entry(last_event, local_steam_id, format_point_label)
            if label ~= "" then return label end
        end
    end

    return ""
end

function terminal.is_terminal_ui(ui)
    if ui == nil then return false end
    local state_name = string.lower(util.safe_str(ui.state))
    local status_name = string.lower(util.safe_str(ui.status))
    if state_name == "finished" or state_name == "cancelled" then return true end
    if status_name == "finished" or status_name == "cancelled" or status_name == "draw" then
        return true
    end
    return false
end

function terminal.is_terminal_raw(raw)
    if raw == nil or type(raw) ~= "table" then return false end
    local state_name = string.lower(util.safe_str(raw.state))
    local status_name = string.lower(util.safe_str(raw.status))
    if state_name == "finished" or state_name == "cancelled" then return true end
    if status_name == "finished" or status_name == "cancelled" or status_name == "draw" then
        return true
    end
    return false
end

function terminal.synthesize_end_ui(from_ui, reason_label, deep_copy_ui, is_terminal_ui)
    if from_ui == nil then return nil end
    local ui = deep_copy_ui(from_ui)
    if ui == nil then return nil end
    if is_terminal_ui(ui) then return ui end

    ui.state = "cancelled"
    ui.status = "cancelled"
    ui.center_text = util.safe_str(reason_label) ~= "" and reason_label or "CANCELLED"
    ui.mode = ui.center_text
    ui.end_label = ui.center_text
    ui.event_label = ui.center_text
    ui.show_gap = false
    ui.show_scores = true
    ui.looking_for_opponent = false
    if ui.player_right ~= nil and ui.player_right.placeholder == true then
        ui.player_right = {
            name = "?",
            tier = 0,
            avatar_url = nil,
            car_name = "",
            role = "",
            placeholder = false,
        }
    end
    return ui
end

function terminal.result_hold_sec(ui)
    if ui ~= nil then
        local state_name = string.lower(util.safe_str(ui.state))
        if state_name == "cancelled" then
            return config.BATTLE_CANCEL_HOLD_SEC or 2.5
        end
    end
    return config.BATTLE_RESULT_HOLD_SEC or 3
end

function terminal.start_result_hold(now, ui)
    return (now or os.clock()) + terminal.result_hold_sec(ui)
end

return terminal
