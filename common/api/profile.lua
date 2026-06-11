--[[ Player profile normalization and rival derivation. ]]

local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")

local profile = {}

local function is_profile_table(value)
    if value == nil or type(value) ~= "table" then return false end
    if value.name ~= nil or value.steam_id ~= nil or value.steamId ~= nil then return true end
    if type(value.rank) == "number" then return true end
    if tonumber(value.rank) ~= nil then return true end
    return false
end

function profile.normalize_profile(value)
    if not is_profile_table(value) then return nil end
    local name = util.safe_str(value.name)
    local sid = steam.normalize_steam_id(value.steam_id or value.steamId)
    local rank = tonumber(value.rank)
    if rank == nil and (name ~= "" or sid ~= "") then rank = 0 end
    if name == "" and sid == "" and rank == nil then return nil end
    return {
        name = name ~= "" and name or "?",
        rank = rank or 0,
        tier = tonumber(value.tier) or 0,
        best_lap_ms = tonumber(value.best_lap_ms) or tonumber(value.lap_ms) or 0,
        car_name = util.safe_str(value.car_name),
        car_id = util.safe_str(value.car_id),
        avatar_url = value.avatar_url,
        steam_id = sid ~= "" and sid or nil,
        steamId = sid ~= "" and sid or nil,
        rival = type(value.rival) == "table" and value.rival or nil,
    }
end

function profile.coalesce_profile(value)
    return profile.normalize_profile(value)
end

local function iter_players(players)
    local list = {}
    if players == nil or type(players) ~= "table" then return list end
    for _, player in ipairs(players) do
        list[#list + 1] = player
    end
    if #list == 0 then
        for _, player in pairs(players) do
            if type(player) == "table" then
                list[#list + 1] = player
            end
        end
    end
    return list
end

function profile.pick_player_profile(players, steam_id)
    local list = iter_players(players)
    if #list == 0 then return nil, nil end

    if #list == 1 then
        local row = list[1]
        local p = profile.coalesce_profile(row.profile)
        if p ~= nil then return p, row end
    end

    for _, player in ipairs(list) do
        if steam.steam_ids_equal(player.steamId or player.steam_id, steam_id) then
            return profile.coalesce_profile(player.profile), player
        end
    end

    for _, player in ipairs(list) do
        if player.ok == true then
            local p = profile.coalesce_profile(player.profile)
            if p ~= nil then return p, player end
        end
    end

    return nil, list[1]
end

function profile.derive_rival_from_leaderboard(p, leaderboard)
    if p == nil or leaderboard == nil or type(leaderboard) ~= "table" then return nil end
    local rank = tonumber(p.rank) or 0
    if rank <= 1 then return nil end

    local target_rank = rank - 1
    local entries = leaderboard.entries
    if entries == nil then return nil end

    local function match_entry(entry)
        if type(entry) ~= "table" then return nil end
        if tonumber(entry.rank) ~= target_rank then return nil end
        return {
            name = entry.name or "?",
            rank = tonumber(entry.rank) or target_rank,
            tier = tonumber(entry.tier) or 0,
            best_lap_ms = tonumber(entry.lap_ms) or tonumber(entry.best_lap_ms) or 0,
            car_name = entry.car_name or "",
            avatar_url = entry.avatar_url,
        }
    end

    for _, entry in ipairs(entries) do
        local rival = match_entry(entry)
        if rival ~= nil then return rival end
    end
    for _, entry in pairs(entries) do
        local rival = match_entry(entry)
        if rival ~= nil then return rival end
    end
    return nil
end

function profile.apply_player_lookup_error(player_row, p, steam_id)
    p = profile.coalesce_profile(p)
    if p ~= nil then
        state.last_error = nil
        return
    end
    if player_row == nil then return end
    if player_row.ok == false and player_row.reason ~= nil then
        state.last_error = tostring(player_row.reason)
        return
    end
    if player_row.ok == true and player_row.profile == nil and player_row.context == nil then
        state.last_error = "user_not_found"
        return
    end
    if steam.steam_ids_equal(player_row.steamId or player_row.steam_id, steam_id) then
        if player_row.context ~= nil then
            state.last_error = "profile_unavailable"
        elseif player_row.profile == nil then
            state.last_error = "user_not_found"
        else
            state.last_error = "profile_unavailable"
        end
    end
end

return profile
