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

local function center_text_for(state_name, arming_countdown, local_player, last_event, looking)
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
        if last_event ~= nil and util.safe_str(last_event.label) ~= "" then
            return util.safe_str(last_event.label)
        end
        return "ACTIVE"
    end
    if state_name == "finished" then return "FINISHED" end
    if state_name == "cancelled" then return "CANCELLED" end
    return string.upper(state_name)
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
        is_lobby = true,
    }
end

function battle_parse.should_hold_result(state_name, now, hold_until)
    if state_name ~= "finished" and state_name ~= "cancelled" then
        return false
    end
    return (now or 0) < (hold_until or 0)
end

function battle_parse.start_result_hold(state_name, now)
    if state_name ~= "finished" and state_name ~= "cancelled" then
        return 0
    end
    local hold_sec = config.BATTLE_RESULT_HOLD_SEC or 4
    return (now or 0) + hold_sec
end

function battle_parse.to_ui(raw, local_steam_id)
    if raw == nil or type(raw) ~= "table" then return nil end

    local state_name = string.lower(util.safe_str(raw.state))
    if state_name == "" or state_name == "none" then return nil end

    local local_player, opponent = resolve_sides(raw, local_steam_id)
    local looking = opponent_missing(opponent)
    if looking then
        opponent = battle_parse.placeholder_opponent()
    end

    local last_event = type(raw.lastEvent) == "table" and raw.lastEvent or nil
    local event_ts = last_event ~= nil and tonumber(last_event.ts) or 0
    local gap = parse_gap(raw)
    local is_active = state_name == "active"
    local is_finished = state_name == "finished" or state_name == "cancelled"

    return {
        state = state_name,
        status = string.lower(util.safe_str(raw.status)),
        looking_for_opponent = looking,
        center_text = center_text_for(
            state_name,
            raw.armingCountdownSec,
            local_player,
            last_event,
            looking
        ),
        mode = center_text_for(
            state_name,
            raw.armingCountdownSec,
            local_player,
            last_event,
            looking
        ),
        score_left = tonumber(local_player.score) or 0,
        score_right = looking and 0 or (tonumber(opponent.score) or 0),
        player_left = player_ui_fields(local_player),
        player_right = player_ui_fields(opponent),
        arming_countdown = tonumber(raw.armingCountdownSec),
        event_label = last_event ~= nil and util.safe_str(last_event.label) or "",
        event_ts = event_ts,
        winner_name = winner_name(raw, local_player, looking and nil or opponent),
        show_gap = is_active and not looking,
        show_scores = is_active or is_finished,
        gap = gap,
        gap3d_m = gap.current,
        disappear_gap_m = gap.max,
        battle_id = util.safe_str(raw.battleId),
        version = util.safe_str(raw.version),
        is_prep = PREP_STATES[state_name] == true,
        is_lobby = false,
    }
end

function battle_parse.should_refresh_snapshot(ui, remote_version, applied_version, last_snapshot_at, now)
    remote_version = util.safe_str(remote_version)
    applied_version = util.safe_str(applied_version)
    now = now or 0

    if remote_version == "" or remote_version == "0" then
        return false
    end
    if remote_version ~= applied_version or applied_version == "" then
        return true
    end
    if ui == nil then return false end

    local state_name = string.lower(util.safe_str(ui.state))
    if state_name ~= "active" and not PREP_STATES[state_name] then
        return false
    end

    local interval_ms = battle_parse.poll_interval_ms(ui, remote_version)
    local age_ms = (now - (last_snapshot_at or 0)) * 1000
    return age_ms >= interval_ms
end

function battle_parse.poll_interval_ms(ui, version)
    version = util.safe_str(version)
    if version == "" or version == "0" then
        return config.BATTLE_POLL_IDLE_MS or 2000
    end
    if ui == nil then
        return config.BATTLE_POLL_PREP_MS or 1000
    end
    local state_name = string.lower(util.safe_str(ui.state))
    if state_name == "active" then
        return config.BATTLE_POLL_ACTIVE_MS or 500
    end
    if PREP_STATES[state_name] then
        return config.BATTLE_POLL_PREP_MS or 1000
    end
    if state_name == "finished" or state_name == "cancelled" then
        return config.BATTLE_POLL_IDLE_MS or 2000
    end
    return config.BATTLE_POLL_IDLE_MS or 2000
end

return battle_parse
