--[[ Map ac-data /hud/battle snapshot to ProjectD Battle HUD UI model. ]]

local config = require("common.config")
local util = require("common.api.util")
local steam = require("common.api.steam")

local battle_parse = {}

local PREP_STATES = {
    pairing = true,
    arming = true,
    armed = true,
    launching = true,
}

local DEFAULT_DISAPPEAR_GAP_M = 250

function battle_parse.placeholder_opponent()
    return {
        placeholder = true,
        name = "Looking for opponent",
        car_name = "",
        tier = 0,
        avatar_url = nil,
        role = "",
    }
end

local function player_from_api(p)
    if p == nil or type(p) ~= "table" then
        return nil
    end
    local sid = steam.normalize_steam_id(p.steamId or p.steam_id)
    local name = util.safe_str(p.name)
    if sid == "" and name == "" then
        return nil
    end
    return {
        name = name ~= "" and name or "?",
        tier = tonumber(p.tier) or 0,
        avatar_url = p.avatar_url,
        car_name = util.safe_str(p.car_name),
        car_id = util.safe_str(p.car_id),
        role = string.lower(util.safe_str(p.role)),
        steam_id = sid,
        score = tonumber(p.score) or 0,
    }
end

local function opponent_missing(opponent)
    if opponent == nil then return true end
    if opponent.placeholder == true then return true end
    if util.safe_str(opponent.steam_id) == "" and util.safe_str(opponent.name) == "" then
        return true
    end
    local name = util.safe_str(opponent.name)
    return name == "" or name == "?"
end

local function resolve_sides(raw, local_steam_id)
    local p1 = player_from_api(raw.player1)
    local p2 = player_from_api(raw.player2)
    local me = steam.normalize_steam_id(local_steam_id)

    local local_player, opponent
    if me ~= "" and p1 ~= nil and p1.steam_id == me then
        local_player, opponent = p1, p2
    elseif me ~= "" and p2 ~= nil and p2.steam_id == me then
        local_player, opponent = p2, p1
    elseif p1 ~= nil then
        local_player, opponent = p1, p2
    else
        local_player, opponent = p2, p1
    end

    if local_player == nil then
        local_player = {
            name = "?",
            tier = 0,
            avatar_url = nil,
            car_name = "",
            car_id = "",
            role = "",
            steam_id = me,
            score = 0,
        }
    end

    return local_player, opponent
end

local function parse_gap(raw)
    local gap3d = tonumber(raw.gap3dM or raw.gap_3d_m or raw.gap3d_m)
    local disappear = tonumber(raw.disappearGapM or raw.disappear_gap_m or raw.disappear_gap_m)
    if disappear == nil or disappear <= 0 then
        disappear = DEFAULT_DISAPPEAR_GAP_M
    end
    if gap3d == nil then gap3d = 0 end
    return {
        current = math.max(0, gap3d),
        max = disappear,
    }
end

local function parse_points_log(raw)
    local log = raw.pointsLog
    if type(log) ~= "table" then return {} end
    local out = {}
    local start = math.max(1, #log - 2)
    for i = start, #log do
        local entry = log[i]
        if type(entry) == "table" then
            local label = event_label_from_entry(entry)
            if label ~= "" then
                out[#out + 1] = label
            end
        end
    end
    return out
end

local function winner_name(raw, local_player, opponent)
    local winner_id = steam.normalize_steam_id(raw.winnerSteamId or raw.winner_steam_id)
    if winner_id == "" then return nil end
    if local_player ~= nil and local_player.steam_id == winner_id then return local_player.name end
    if opponent ~= nil and opponent.steam_id == winner_id then return opponent.name end
    if raw.player1 ~= nil and steam.normalize_steam_id(raw.player1.steamId) == winner_id then
        return util.safe_str(raw.player1.name)
    end
    if raw.player2 ~= nil and steam.normalize_steam_id(raw.player2.steamId) == winner_id then
        return util.safe_str(raw.player2.name)
    end
    return nil
end

local function format_reason_code(code)
    code = util.safe_str(code)
    if code == "" then return "" end
    return string.upper(code:gsub("_", " "))
end

local function event_label_from_entry(entry)
    if entry == nil or type(entry) ~= "table" then return "" end
    local label = util.safe_str(entry.label)
    if label ~= "" then return label end
    return format_reason_code(entry.reason)
end

local function terminal_display_text(raw, state_name, status_name, last_event)
    local end_label = util.safe_str(raw.endLabel or raw.end_label)
    if end_label ~= "" then return end_label end

    if status_name == "draw" then return "DRAW" end

    if state_name == "cancelled" or status_name == "cancelled" then
        local cr = util.safe_str(raw.cancelReason or raw.cancel_reason)
        if cr ~= "" then return format_reason_code(cr) end
    end

    if state_name == "finished" or status_name == "finished" then
        local er = util.safe_str(raw.endReason or raw.end_reason)
        if er ~= "" then return format_reason_code(er) end
    end

    if last_event ~= nil then
        local label = event_label_from_entry(last_event)
        if label ~= "" then return label end
    end

    if state_name == "finished" or status_name == "finished" then return "FINISHED" end
    if state_name == "cancelled" or status_name == "cancelled" then return "CANCELLED" end
    return "ENDED"
end

local function center_text_for(state_name, status_name, arming_countdown, local_player, looking, raw, last_event)
    local is_terminal = state_name == "finished" or state_name == "cancelled"
        or status_name == "finished" or status_name == "cancelled" or status_name == "draw"

    if is_terminal then
        return terminal_display_text(raw, state_name, status_name, last_event)
    end
    if looking then return "LOOKING" end
    if state_name == "pairing" then return "PAIRING" end
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

function battle_parse.synthesize_end_ui(from_ui, reason_label)
    if from_ui == nil then return nil end
    local ui = battle_parse.deep_copy_ui(from_ui)
    if ui == nil then return nil end
    if battle_parse.is_terminal_ui(ui) then return ui end

    ui.state = "cancelled"
    ui.status = "cancelled"
    ui.center_text = util.safe_str(reason_label) ~= "" and reason_label or "CANCELLED"
    ui.mode = ui.center_text
    ui.end_label = ui.center_text
    ui.event_label = ui.center_text
    ui.show_gap = false
    ui.show_scores = (tonumber(ui.score_left) or 0) > 0 or (tonumber(ui.score_right) or 0) > 0
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

local function player_ui_fields(player)
    return {
        name = player.name,
        tier = player.tier,
        avatar_url = player.avatar_url,
        car_name = player.car_name,
        role = player.role,
        placeholder = player.placeholder == true,
    }
end

function battle_parse.is_terminal_ui(ui)
    if ui == nil then return false end
    local state_name = string.lower(util.safe_str(ui.state))
    local status_name = string.lower(util.safe_str(ui.status))
    if state_name == "finished" or state_name == "cancelled" then return true end
    if status_name == "finished" or status_name == "cancelled" or status_name == "draw" then
        return true
    end
    return false
end

function battle_parse.is_terminal_raw(raw)
    if raw == nil or type(raw) ~= "table" then return false end
    local state_name = string.lower(util.safe_str(raw.state))
    local status_name = string.lower(util.safe_str(raw.status))
    if state_name == "finished" or state_name == "cancelled" then return true end
    if status_name == "finished" or status_name == "cancelled" or status_name == "draw" then
        return true
    end
    return false
end

function battle_parse.lobby_from_profile(profile, ctx)
    profile = profile or {}
    ctx = ctx or {}
    local left = {
        name = util.safe_str(profile.name ~= "" and profile.name or "?"),
        tier = tonumber(profile.tier) or 0,
        avatar_url = profile.avatar_url,
        car_name = util.safe_str(profile.car_name ~= "" and profile.car_name or ctx.car_name),
        role = "",
    }
    return {
        state = "pairing",
        status = "idle",
        looking_for_opponent = true,
        center_text = "LOOKING",
        mode = "LOOKING",
        score_left = 0,
        score_right = 0,
        show_scores = false,
        show_gap = false,
        player_left = left,
        player_right = battle_parse.placeholder_opponent(),
        event_label = "",
        event_ts = 0,
        points_log = {},
        is_lobby = true,
    }
end

function battle_parse.result_hold_sec(ui)
    if ui ~= nil then
        local state_name = string.lower(util.safe_str(ui.state))
        if state_name == "cancelled" then
            return config.BATTLE_CANCEL_HOLD_SEC or 2.5
        end
    end
    return config.BATTLE_RESULT_HOLD_SEC or 3
end

function battle_parse.start_result_hold(now, ui)
    return (now or os.clock()) + battle_parse.result_hold_sec(ui)
end

function battle_parse.to_ui(raw, local_steam_id)
    if raw == nil or type(raw) ~= "table" then return nil end

    local state_name = string.lower(util.safe_str(raw.state))
    if state_name == "" or state_name == "none" then return nil end

    local status_name = string.lower(util.safe_str(raw.status))
    local local_player, opponent = resolve_sides(raw, local_steam_id)
    local is_terminal = battle_parse.is_terminal_raw(raw)
    local looking = not is_terminal and opponent_missing(opponent)
    if looking then
        opponent = battle_parse.placeholder_opponent()
    elseif is_terminal and opponent_missing(opponent) then
        opponent = {
            name = "?",
            tier = 0,
            avatar_url = nil,
            car_name = "",
            car_id = "",
            role = "",
            steam_id = "",
            score = 0,
        }
    end

    local last_event = type(raw.lastEvent) == "table" and raw.lastEvent or nil
    local event_ts = last_event ~= nil and tonumber(last_event.ts) or 0
    local end_label = util.safe_str(raw.endLabel or raw.end_label)
    local gap = parse_gap(raw)
    local is_active = state_name == "active"
    local is_draw = status_name == "draw"
    local points_log = parse_points_log(raw)

    local center = center_text_for(
        state_name,
        status_name,
        raw.armingCountdownSec,
        local_player,
        looking,
        raw,
        last_event
    )

    local event_label = ""
    if is_terminal then
        event_label = end_label ~= "" and end_label or event_label_from_entry(last_event)
    elseif is_active then
        event_label = event_label_from_entry(last_event)
        if event_label == "" and #points_log > 0 then
            event_label = points_log[#points_log]
        end
    end

    return {
        state = state_name,
        status = status_name,
        looking_for_opponent = looking,
        center_text = center,
        mode = center,
        score_left = tonumber(local_player.score) or 0,
        score_right = looking and 0 or (tonumber(opponent.score) or 0),
        player_left = player_ui_fields(local_player),
        player_right = player_ui_fields(opponent),
        arming_countdown = tonumber(raw.armingCountdownSec),
        event_label = event_label,
        event_ts = event_ts,
        end_label = end_label,
        cancel_reason = util.safe_str(raw.cancelReason or raw.cancel_reason),
        end_reason = util.safe_str(raw.endReason or raw.end_reason),
        finish_gap_m = tonumber(raw.finishGapM or raw.finish_gap_m),
        position_fallback = raw.positionFallback == true or raw.position_fallback == true,
        winner_name = winner_name(raw, local_player, looking and nil or opponent),
        show_gap = is_active and not looking,
        show_scores = is_active or is_terminal or is_draw,
        gap = gap,
        gap3d_m = gap.current,
        disappear_gap_m = gap.max,
        battle_id = util.safe_str(raw.battleId),
        version = util.safe_str(raw.version),
        points_log = points_log,
        is_prep = PREP_STATES[state_name] == true,
        is_lobby = false,
    }
end

function battle_parse.has_api_key()
    local key = ac.storage("ProjectD-HUD:api_key", ""):get()
    return util.safe_str(key) ~= ""
end

function battle_parse.should_refresh_snapshot(remote_version, applied_version)
    remote_version = util.safe_str(remote_version)
    applied_version = util.safe_str(applied_version)
    if remote_version == "" or remote_version == "0" then
        return false
    end
    return remote_version ~= applied_version or applied_version == ""
end

function battle_parse.poll_interval_ms(ui, version)
    version = util.safe_str(version)
    local has_key = battle_parse.has_api_key()
    if version == "" or version == "0" then
        if has_key then
            return config.BATTLE_POLL_LOBBY_MS or 1000
        end
        return config.BATTLE_POLL_LOBBY_MS_SLOW or 2000
    end
    if ui == nil then
        if has_key then
            return config.BATTLE_POLL_PREP_MS or 500
        end
        return config.BATTLE_POLL_PREP_MS_SLOW or 1000
    end
    local state_name = string.lower(util.safe_str(ui.state))
    if state_name == "active" then
        if has_key then
            return config.BATTLE_POLL_ACTIVE_MS or 500
        end
        return config.BATTLE_POLL_ACTIVE_MS_SLOW or 2000
    end
    if PREP_STATES[state_name] then
        if has_key then
            return config.BATTLE_POLL_PREP_MS or 500
        end
        return config.BATTLE_POLL_PREP_MS_SLOW or 1000
    end
    if state_name == "finished" or state_name == "cancelled" then
        return config.BATTLE_POLL_PREP_MS or 500
    end
    return config.BATTLE_POLL_IDLE_MS or 2000
end

function battle_parse.deep_copy_ui(ui)
    if ui == nil then return nil end
    local out = {}
    for k, v in pairs(ui) do
        if type(v) == "table" then
            local inner = {}
            for k2, v2 in pairs(v) do
                inner[k2] = v2
            end
            out[k] = inner
        else
            out[k] = v
        end
    end
    return out
end

return battle_parse
