--[[ Battle player resolution and merge helpers. ]]

local util = require("common.api.util")
local profile = require("common.api.profile")
local steam = require("common.api.steam")

local players = {}

local function parse_elo(p)
    if p == nil or type(p) ~= "table" then return nil end
    return tonumber(p.elo) or tonumber(p.mmr) or tonumber(p.rating)
end

function players.parse_elo(p)
    return parse_elo(p)
end

function players.placeholder_opponent()
    return {
        placeholder = true,
        name = "Looking for opponent",
        car_name = "",
        tier = 0,
        avatar_url = nil,
        role = "",
    }
end

function players.player_from_api(p)
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

function players.opponent_missing(opponent)
    if opponent == nil then return true end
    if opponent.placeholder == true then return true end
    if util.safe_str(opponent.steam_id) == "" and util.safe_str(opponent.name) == "" then
        return true
    end
    local name = util.safe_str(opponent.name)
    return name == "" or name == "?"
end

function players.resolve_sides(raw, local_steam_id)
    local p1 = players.player_from_api(raw.player1)
    local p2 = players.player_from_api(raw.player2)
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

function players.player_ui_fields(player)
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

function players.merge_player_ui(incoming, existing)
    incoming = incoming or {}
    if incoming.placeholder == true then return incoming end
    if existing == nil or existing.placeholder == true then
        return players.player_ui_fields(incoming)
    end

    local inc = players.player_ui_fields(incoming)
    local ex = players.player_ui_fields(existing)

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

function players.merge_players_from_previous(ui, prev_ui)
    if ui == nil or prev_ui == nil then return ui end
    ui.player_left = players.merge_player_ui(ui.player_left, prev_ui.player_left)
    ui.player_right = players.merge_player_ui(ui.player_right, prev_ui.player_right)
    return ui
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

function players.winner_name(raw, local_player, opponent)
    local from_fields = winner_name_from_fields(raw)
    if from_fields ~= nil and from_fields ~= "" then return from_fields end

    local winner_id = steam.normalize_steam_id(raw.winnerSteamId or raw.winner_steam_id)
    if winner_id ~= "" then
        local by_id = name_for_steam_id(winner_id, raw, local_player, opponent)
        if by_id ~= nil and by_id ~= "" then return by_id end
    end

    return winner_name_from_scores(raw, local_player, opponent)
end

function players.winner_player_for_name(name, local_player, opponent)
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

function players.resolve_winner_display(ui)
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

function players.lobby_from_profile(player_profile)
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
        player_right = players.placeholder_opponent(),
        event_label = "",
        event_ts = 0,
        points_log = {},
        is_lobby = true,
    }
end

return players
