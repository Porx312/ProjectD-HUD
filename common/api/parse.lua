--[[ Session API response parsing and leaderboard entry copy. ]]

local state = require("common.api.state")
local steam = require("common.api.steam")
local profile = require("common.api.profile")

local parse = {}

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

function parse.response_is_ok(data)
    if data == nil or type(data) ~= "table" then return false end
    if data.error ~= nil then return false end
    if data.ok == false then return false end
    if data.ok == true then return true end
    if data.leaderboard ~= nil then return true end
    return false
end

function parse.normalize_session_response(data, steam_id)
    steam_id = steam.normalize_steam_id(steam_id)

    if not parse.response_is_ok(data) then
        if data ~= nil and data.error ~= nil then
            state.last_error = tostring(data.error)
        elseif data ~= nil and data.reason ~= nil then
            state.last_error = tostring(data.reason)
        end
        return nil
    end

    local player_list = iter_players(data.players)
    state.last_session_had_players = #player_list > 0

    local out = {
        ok = true,
        context = data.context,
        leaderboard = data.leaderboard,
        profile = profile.coalesce_profile(data.profile),
    }

    local player_profile, player_row = profile.pick_player_profile(data.players, steam_id)
    if player_row ~= nil then
        if player_row.context ~= nil then out.context = player_row.context end
        if player_profile ~= nil then out.profile = player_profile end
        profile.apply_player_lookup_error(player_row, out.profile, steam_id)
    elseif out.profile == nil and data.context ~= nil then
        state.last_error = "profile_unavailable"
    end

    if out.profile ~= nil and out.profile.rival == nil and out.leaderboard ~= nil then
        local derived = profile.derive_rival_from_leaderboard(out.profile, out.leaderboard)
        if derived ~= nil then
            out.profile.rival = derived
        end
    end

    if out.profile ~= nil then
        state.last_error = nil
    end

    return out
end

function parse.copy_entries(list)
    local out = {}
    if list == nil then return out end

    local function add(entry)
        if type(entry) ~= "table" then return end
        local i = 0
        while out[i] ~= nil do i = i + 1 end
        out[i] = {
            rank = entry.rank or 0,
            name = entry.name or "?",
            tier = tonumber(entry.tier) or 0,
            lap_ms = entry.lap_ms or entry.best_lap_ms or 0,
            car_name = entry.car_name or "",
            avatar_url = entry.avatar_url,
        }
    end

    for _, entry in ipairs(list) do add(entry) end
    if out[0] == nil then
        for _, entry in pairs(list) do add(entry) end
    end
    return out
end

return parse
