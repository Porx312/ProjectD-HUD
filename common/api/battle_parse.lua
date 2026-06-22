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

local function player_from_api(p)
    if p == nil or type(p) ~= "table" then
        return {
            name = "?",
            tier = 0,
            avatar_url = nil,
            car_name = "",
            car_id = "",
            role = "",
            steam_id = "",
        }
    end
    return {
        name = util.safe_str(p.name ~= "" and p.name or "?"),
        tier = tonumber(p.tier) or 0,
        avatar_url = p.avatar_url,
        car_name = util.safe_str(p.car_name),
        car_id = util.safe_str(p.car_id),
        role = string.lower(util.safe_str(p.role)),
        steam_id = steam.normalize_steam_id(p.steamId or p.steam_id),
        score = tonumber(p.score) or 0,
    }
end

local function resolve_sides(raw, local_steam_id)
    local p1 = player_from_api(raw.player1)
    local p2 = player_from_api(raw.player2)
    local me = steam.normalize_steam_id(local_steam_id)

    if me ~= "" and p1.steam_id == me then
        return p1, p2
    end
    if me ~= "" and p2.steam_id == me then
        return p2, p1
    end
    return p1, p2
end

local function winner_name(raw, local_player, opponent)
    local winner_id = steam.normalize_steam_id(raw.winnerSteamId or raw.winner_steam_id)
    if winner_id == "" then return nil end
    if local_player.steam_id == winner_id then return local_player.name end
    if opponent.steam_id == winner_id then return opponent.name end
    if raw.player1 ~= nil and steam.normalize_steam_id(raw.player1.steamId) == winner_id then
        return util.safe_str(raw.player1.name)
    end
    if raw.player2 ~= nil and steam.normalize_steam_id(raw.player2.steamId) == winner_id then
        return util.safe_str(raw.player2.name)
    end
    return nil
end

local function mode_label(state_name, local_player, last_event)
    if state_name == "active" then
        local role = string.upper(local_player.role or "")
        if role == "LEAD" or role == "CHASE" then return role end
    end
    if last_event ~= nil and util.safe_str(last_event.label) ~= "" then
        return util.safe_str(last_event.label)
    end
    return state_name
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
    local last_event = type(raw.lastEvent) == "table" and raw.lastEvent or nil
    local event_ts = last_event ~= nil and tonumber(last_event.ts) or 0

    return {
        state = state_name,
        status = string.lower(util.safe_str(raw.status)),
        mode = mode_label(state_name, local_player, last_event),
        score_left = tonumber(local_player.score) or 0,
        score_right = tonumber(opponent.score) or 0,
        player_left = {
            name = local_player.name,
            tier = local_player.tier,
            avatar_url = local_player.avatar_url,
            car_name = local_player.car_name,
            role = local_player.role,
        },
        player_right = {
            name = opponent.name,
            tier = opponent.tier,
            avatar_url = opponent.avatar_url,
            car_name = opponent.car_name,
            role = opponent.role,
        },
        arming_countdown = tonumber(raw.armingCountdownSec),
        event_label = last_event ~= nil and util.safe_str(last_event.label) or "",
        event_ts = event_ts,
        winner_name = winner_name(raw, local_player, opponent),
        show_gap = false,
        battle_id = util.safe_str(raw.battleId),
        version = util.safe_str(raw.version),
        is_prep = PREP_STATES[state_name] == true,
    }
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
