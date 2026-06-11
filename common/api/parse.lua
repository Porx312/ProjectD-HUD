--[[ Session API response parsing and leaderboard entry copy. ]]

local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local profile = require("common.api.profile")

local parse = {}

--- ac-data may return entries at top level (redis top10) or under leaderboard (session bundle).
function parse.coalesce_leaderboard(data)
    if data == nil or type(data) ~= "table" then return nil end

    local lb = data.leaderboard
    if type(lb) ~= "table" then lb = nil end

    if lb == nil and (data.entries ~= nil or data.filters ~= nil) then
        lb = {
            title = data.title or "Top 10",
            map = data.map or data.track_name or "",
            layout = data.layout or data.layout_name or "",
            filters = data.filters or {},
            entries = data.entries or {},
        }
    end

    if type(lb) == "table" then
        if lb.entries == nil and data.entries ~= nil then
            lb.entries = data.entries
        end
        if (lb.filters == nil or #lb.filters == 0) and data.filters ~= nil then
            lb.filters = data.filters
        end
        if lb.title == nil or lb.title == "" then lb.title = "Top 10" end
    end

    return lb
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

    local leaderboard = parse.coalesce_leaderboard(data)

    local out = {
        ok = true,
        context = data.context,
        leaderboard = leaderboard,
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

function parse.count_ui_entries(list)
    return util.count_ui_rows(parse.copy_entries(list))
end

local function entry_sort_key(key, entry, fallback)
    if type(entry) == "table" and entry.rank ~= nil then
        return tonumber(entry.rank) or fallback
    end
    local n = tonumber(key)
    if n ~= nil then return n end
    return fallback
end

function parse.copy_entries(list)
    local out = {}
    if list == nil or type(list) ~= "table" then return out end

    local sorted = {}
    local n = 0
    for key, entry in pairs(list) do
        if type(entry) == "table" then
            n = n + 1
            sorted[n] = {
                key = key,
                entry = entry,
                order = entry_sort_key(key, entry, n),
            }
        end
    end

    if n == 0 then return out end

    table.sort(sorted, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        local ka = tonumber(a.key) or 0
        local kb = tonumber(b.key) or 0
        return ka < kb
    end)

    for i, item in ipairs(sorted) do
        local entry = item.entry
        out[i - 1] = {
            rank = tonumber(entry.rank) or i,
            name = entry.name or "?",
            tier = tonumber(entry.tier) or 0,
            lap_ms = tonumber(entry.lap_ms or entry.best_lap_ms) or 0,
            car_name = entry.car_name or "",
            avatar_url = entry.avatar_url,
        }
    end

    return out
end

return parse
