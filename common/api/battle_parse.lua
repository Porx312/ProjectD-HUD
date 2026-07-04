--[[ Map ac-data battle snapshot (SSE) to ProjectD Battle HUD UI model. ]]

local config = require("common.config")
local util = require("common.api.util")
local profile = require("common.api.profile")
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

local function parse_elo(p)
    if p == nil or type(p) ~= "table" then return nil end
    return tonumber(p.elo) or tonumber(p.mmr) or tonumber(p.rating)
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
        tier = profile.tier_for_display(p),
        avatar_url = profile.avatar_from_raw(p),
        car_name = util.safe_str(p.car_name or p.carName),
        car_id = util.safe_str(p.car_id or p.carId or p.carModel),
        role = string.lower(util.safe_str(p.role)),
        steam_id = sid,
        score = tonumber(p.score) or 0,
        elo = parse_elo(p),
    }
end

local function merge_scalar_stat(incoming, existing, key)
    local inc = incoming[key]
    if key == "tier" then
        if profile.tier_for_display(incoming) > 0 then return inc end
        if profile.tier_for_display(existing) > 0 then return existing[key] end
        return inc
    end
    if key == "elo" then
        if inc ~= nil and tonumber(inc) > 0 then return inc end
        if existing ~= nil and tonumber(existing[key]) > 0 then return existing[key] end
        return inc
    end
    return inc
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

    local s1 = tonumber(raw.player1Score or raw.player1_score)
    local s2 = tonumber(raw.player2Score or raw.player2_score)
    if p1 ~= nil then
        if s1 ~= nil then p1.score = s1
        elseif p1.score == 0 then p1.score = tonumber(raw.player1 and raw.player1.score) or 0 end
    end
    if p2 ~= nil then
        if s2 ~= nil then p2.score = s2
        elseif p2.score == 0 then p2.score = tonumber(raw.player2 and raw.player2.score) or 0 end
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

local function format_reason_code(code)
    code = util.safe_str(code)
    if code == "" then return "" end
    return string.upper(code:gsub("_", " "))
end

local function format_point_label(entry, local_steam_id)
    if entry == nil or type(entry) ~= "table" then return "" end
    local label = util.safe_str(entry.label)
    if label ~= "" then return label end

    local reason = format_reason_code(entry.reason or entry.type or entry.event)
    if reason == "" then return "" end

    local points = tonumber(entry.points)
    if points == nil and entry.point ~= nil then
        points = tonumber(entry.point)
    end

    local scorer = steam.normalize_steam_id(entry.scorer or entry.steamId or entry.steam_id)
    local me = steam.normalize_steam_id(local_steam_id)
    if points ~= nil and points > 0 then
        if scorer ~= "" and me ~= "" and scorer == me then
            return reason .. " +" .. tostring(points)
        end
        if scorer ~= "" and me ~= "" and scorer ~= me then
            return reason .. " +" .. tostring(points)
        end
        return reason .. " +" .. tostring(points)
    end
    return reason
end

local function event_label_from_entry(entry, local_steam_id)
    return format_point_label(entry, local_steam_id)
end

local function raw_event_label(raw, last_event, local_steam_id)
    local direct = util.safe_str(raw.eventLabel or raw.event_label or raw.statusLabel or raw.status_label)
    if direct ~= "" then
        return format_reason_code(direct)
    end

    local from_event = event_label_from_entry(last_event, local_steam_id)
    if from_event ~= "" then return from_event end

    local status = string.lower(util.safe_str(raw.status))
    if status ~= "" and status ~= "active" and status ~= "idle" and status ~= "arming" and status ~= "armed" then
        return format_reason_code(status)
    end
    if status == "idle" then
        return "IDLE"
    end

    return ""
end

local function parse_points_log(raw, local_steam_id)
    local log = raw.pointsLog or raw.points_log
    if type(log) ~= "table" then return {} end

    local entries = {}
    for i = 1, #log do
        if type(log[i]) == "table" then entries[#entries + 1] = log[i] end
    end
    if #entries == 0 then
        for _, entry in pairs(log) do
            if type(entry) == "table" then entries[#entries + 1] = entry end
        end
    end
    if #entries == 0 then return {} end

    local out = {}
    local start = math.max(1, #entries - 2)
    for i = start, #entries do
        local label = format_point_label(entries[i], local_steam_id)
        if label ~= "" then out[#out + 1] = label end
    end
    return out
end

local function resolve_last_event(raw)
    local last_event = raw.lastEvent or raw.last_event
    if type(last_event) == "table" then return last_event end
    local log = raw.pointsLog or raw.points_log
    if type(log) == "table" and #log > 0 and type(log[#log]) == "table" then
        return log[#log]
    end
    return nil
end

local function event_ts_from_entry(entry)
    if entry == nil then return 0 end
    local ts = tonumber(entry.ts) or tonumber(entry.at) or 0
    if ts > 1e11 then
        return ts / 1000
    end
    return ts
end

local function name_for_steam_id(winner_id, raw, local_player, opponent)
    if winner_id == "" then return nil end
    if local_player ~= nil and local_player.steam_id == winner_id then
        return util.safe_str(local_player.name)
    end
    if opponent ~= nil and opponent.steam_id == winner_id then
        return util.safe_str(opponent.name)
    end
    if raw.player1 ~= nil and steam.normalize_steam_id(raw.player1.steamId or raw.player1.steam_id) == winner_id then
        return util.safe_str(raw.player1.name)
    end
    if raw.player2 ~= nil and steam.normalize_steam_id(raw.player2.steamId or raw.player2.steam_id) == winner_id then
        return util.safe_str(raw.player2.name)
    end
    return nil
end

local function winner_name_from_fields(raw)
    local direct = util.safe_str(raw.winnerName or raw.winner_name)
    if direct ~= "" then return direct end

    local winner = raw.winner
    if type(winner) == "string" and winner ~= "" then return winner end
    if type(winner) == "table" then
        local name = util.safe_str(winner.name or winner.displayName or winner.display_name)
        if name ~= "" then return name end
        local wid = steam.normalize_steam_id(winner.steamId or winner.steam_id)
        if wid ~= "" then
            return name_for_steam_id(wid, raw, nil, nil)
        end
    end
    return nil
end

local function winner_name_from_scores(raw, local_player, opponent)
    local p1 = raw.player1
    local p2 = raw.player2
    if type(p1) == "table" and type(p2) == "table" then
        local s1 = tonumber(raw.player1Score or raw.player1_score or p1.score)
        local s2 = tonumber(raw.player2Score or raw.player2_score or p2.score)
        if s1 ~= nil and s2 ~= nil and s1 ~= s2 then
            if s1 > s2 then
                local n = util.safe_str(p1.name)
                if n ~= "" then return n end
            else
                local n = util.safe_str(p2.name)
                if n ~= "" then return n end
            end
        end
    end

    if local_player == nil or opponent == nil then return nil end
    local sl = tonumber(local_player.score) or 0
    local sr = tonumber(opponent.score) or 0
    if sl == sr then return nil end
    if sl > sr then return util.safe_str(local_player.name) end
    return util.safe_str(opponent.name)
end

local function winner_name(raw, local_player, opponent)
    local from_fields = winner_name_from_fields(raw)
    if from_fields ~= nil and from_fields ~= "" then return from_fields end

    local winner_id = steam.normalize_steam_id(raw.winnerSteamId or raw.winner_steam_id)
    if winner_id ~= "" then
        local by_id = name_for_steam_id(winner_id, raw, local_player, opponent)
        if by_id ~= nil and by_id ~= "" then return by_id end
    end

    return winner_name_from_scores(raw, local_player, opponent)
end

local function winner_player_for_name(name, local_player, opponent)
    name = util.safe_str(name)
    if name == "" then return nil end
    if local_player ~= nil and util.safe_str(local_player.name) == name then
        return local_player
    end
    if opponent ~= nil and util.safe_str(opponent.name) == name then
        return opponent
    end
    return { name = name }
end

--- Nombre del ganador para pantalla de resultado (UI ya normalizada).
function battle_parse.resolve_winner_display(ui)
    if ui == nil then return "" end

    local name = util.safe_str(ui.winner_name)
    if name == "" and type(ui.winner_player) == "table" then
        name = util.safe_str(ui.winner_player.name)
    end
    if name ~= "" then return name end

    local sl = tonumber(ui.score_left) or 0
    local sr = tonumber(ui.score_right) or 0
    if sl ~= sr then
        if sl > sr and ui.player_left ~= nil and ui.player_left.placeholder ~= true then
            name = util.safe_str(ui.player_left.name)
            if name ~= "" then return name end
        end
        if sr > sl and ui.player_right ~= nil and ui.player_right.placeholder ~= true then
            name = util.safe_str(ui.player_right.name)
            if name ~= "" then return name end
        end
    end

    return ""
end

local function arming_countdown_sec(raw)
    return tonumber(raw.armingCountdownSec or raw.arming_countdown_sec or raw.armingCountdown)
end

local function terminal_center_text(raw, state_name, status_name)
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

local function terminal_toast_text(raw, state_name, status_name, last_event, local_steam_id)
    local end_label = util.safe_str(raw.endLabel or raw.end_label)
    local cancel = format_reason_code(raw.cancelReason or raw.cancel_reason)
    local end_reason = format_reason_code(raw.endReason or raw.end_reason)

    if state_name == "cancelled" or status_name == "cancelled" then
        if end_label ~= "" and end_label ~= terminal_center_text(raw, state_name, status_name) then
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
            local label = event_label_from_entry(last_event, local_steam_id)
            if label ~= "" then return label end
        end
    end

    return ""
end

local function terminal_display_text(raw, state_name, status_name, last_event, local_steam_id)
    return terminal_center_text(raw, state_name, status_name)
end

local function center_text_for(state_name, status_name, arming_countdown, local_player, looking, raw, last_event, local_steam_id)
    local is_terminal = state_name == "finished" or state_name == "cancelled"
        or status_name == "finished" or status_name == "cancelled" or status_name == "draw"

    if is_terminal then
        return terminal_display_text(raw, state_name, status_name, last_event, local_steam_id)
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

local function player_ui_fields(player)
    return {
        name = player.name,
        tier = player.tier,
        avatar_url = player.avatar_url,
        car_name = player.car_name,
        car_id = player.car_id,
        role = player.role,
        elo = player.elo,
        placeholder = player.placeholder == true,
    }
end

local function incoming_is_full_player(incoming)
    if incoming == nil or type(incoming) ~= "table" then return false end
    if incoming.placeholder == true then return true end
    if util.safe_str(incoming.name) ~= "" and util.safe_str(incoming.name) ~= "?" then return true end
    if util.safe_str(incoming.car_name) ~= "" then return true end
    if incoming.avatar_url ~= nil and incoming.avatar_url ~= "" then return true end
    if util.safe_str(incoming.steam_id) ~= "" then return true end
    return false
end

function battle_parse.merge_player_ui(incoming, existing)
    incoming = incoming or {}
    if incoming.placeholder == true then return incoming end
    if existing == nil or existing.placeholder == true then
        return player_ui_fields(incoming)
    end

    local inc = player_ui_fields(incoming)
    local ex = player_ui_fields(existing)

    if not incoming_is_full_player(incoming) then
        local p = ex
        p.tier = merge_scalar_stat(inc, ex, "tier")
        p.elo = merge_scalar_stat(inc, ex, "elo")
        return p
    end

    local p = inc
    p.tier = merge_scalar_stat(inc, ex, "tier")
    p.elo = merge_scalar_stat(inc, ex, "elo")
    return p
end

function battle_parse.merge_players_from_previous(ui, prev_ui)
    if ui == nil or prev_ui == nil then return ui end
    ui.player_left = battle_parse.merge_player_ui(ui.player_left, prev_ui.player_left)
    ui.player_right = battle_parse.merge_player_ui(ui.player_right, prev_ui.player_right)
    return ui
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

function battle_parse.lobby_from_profile(player_profile, _ctx)
    player_profile = player_profile or {}
    local name = util.safe_str(player_profile.name)
    local left = {
        name = name ~= "" and name or "?",
        tier = profile.tier_for_display(player_profile),
        avatar_url = player_profile.avatar_url,
        car_name = util.safe_str(player_profile.car_name),
        car_id = util.safe_str(player_profile.car_id),
        role = "",
        elo = parse_elo(player_profile),
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

    local state_name = string.lower(util.safe_str(raw.state or raw.battleState or raw.battle_state))
    if state_name == "" or state_name == "none" or state_name == "idle" then
        if raw.ok == true and (raw.player1 ~= nil or raw.player2 ~= nil) then
            state_name = "pairing"
        else
            return nil
        end
    end

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

    local last_event = resolve_last_event(raw)
    local event_ts = event_ts_from_entry(last_event)
    local end_label = util.safe_str(raw.endLabel or raw.end_label)
    local gap = parse_gap(raw)
    local is_active = state_name == "active"
    local is_armed = state_name == "armed"
    local is_draw = status_name == "draw"
    local points_log = parse_points_log(raw, local_steam_id)
    local arming_cd = arming_countdown_sec(raw)

    local center = center_text_for(
        state_name,
        status_name,
        arming_cd,
        local_player,
        looking,
        raw,
        last_event,
        local_steam_id
    )

    local event_label = ""
    if is_terminal then
        event_label = terminal_toast_text(raw, state_name, status_name, last_event, local_steam_id)
        if event_label == center then
            event_label = ""
        end
    elseif is_active or is_armed or state_name == "launching" then
        event_label = raw_event_label(raw, last_event, local_steam_id)
        if event_label == "" and #points_log > 0 then
            event_label = points_log[#points_log]
        end
    end

    local resolved_winner = winner_name(raw, local_player, looking and nil or opponent)
    local winner_player = winner_player_for_name(resolved_winner, local_player, looking and nil or opponent)
    local final_score = util.safe_str(raw.finalScoreText or raw.final_score_text)
    if final_score == "" and is_terminal and not looking then
        final_score = string.format(
            "%d-%d",
            tonumber(local_player.score) or 0,
            looking and 0 or (tonumber(opponent.score) or 0)
        )
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
        arming_countdown = arming_cd,
        event_label = event_label,
        event_ts = event_ts,
        end_label = end_label,
        cancel_reason = util.safe_str(raw.cancelReason or raw.cancel_reason),
        end_reason = util.safe_str(raw.endReason or raw.end_reason),
        finish_gap_m = tonumber(raw.finishGapM or raw.finish_gap_m),
        position_fallback = raw.positionFallback == true or raw.position_fallback == true,
        winner_name = resolved_winner,
        winner_player = winner_player ~= nil and player_ui_fields(winner_player) or nil,
        final_score_text = final_score ~= "" and final_score or nil,
        show_gap = (is_active or is_armed) and not looking,
        show_scores = is_active,
        show_prep_scores = state_name == "pairing" and not looking,
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
