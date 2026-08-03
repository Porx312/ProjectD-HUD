--[[ Player profile normalization (time attack: profile + rivals.above/below). ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")

local profile = {}

local SKIP_ABSORB_KEYS = {
    ok = true,
    error = true,
    reason = true,
    context = true,
    leaderboard = true,
    players = true,
    entries = true,
    filters = true,
    version = true,
    lbVersion = true,
    boardVersion = true,
    playerVersions = true,
    rivals = true,
}

local NESTED_ABSORB_KEYS = {
    stats = true,
    player = true,
    user = true,
    data = true,
    profile = true,
}

local function pick_field(tbl, ...)
    if tbl == nil or type(tbl) ~= "table" then return nil end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local v = tbl[key]
        if v ~= nil and v ~= "" then return v end
    end
    return nil
end

function profile.parse_tier(value)
    if value == nil then return nil end
    if type(value) == "number" then
        local n = math.floor(value + 0.0001)
        if n >= 0 and n <= 10 then return n end
        return nil
    end
    if type(value) == "string" then
        local n = tonumber(value)
        if n ~= nil then return profile.parse_tier(n) end
        local digits = value:match("(%d+)")
        if digits ~= nil then return profile.parse_tier(tonumber(digits)) end
        return nil
    end
    if type(value) == "table" then
        return profile.parse_tier(pick_field(
            value,
            "tier", "tierLevel", "tier_level", "skillTier", "skill_tier",
            "level", "index", "value"
        ))
    end
    return nil
end

--- Tier para UI (0–10). 0 = sin dato del SSE / placeholder.
function profile.tier_for_display(value)
    if type(value) == "number" then
        local t = profile.parse_tier(value)
        if t ~= nil then return t end
        return 0
    end
    if value == nil then return 0 end
    if type(value) == "table" then
        local t = profile.parse_tier(value.tier) or profile.tier_from_raw(value)
        if t ~= nil then return t end
        return 0
    end
    return 0
end

--- Alias interno (compat).
function profile.effective_tier(value)
    return profile.tier_for_display(value)
end

function profile.tier_from_raw(tbl)
    if tbl == nil or type(tbl) ~= "table" then return nil end
    local t = profile.parse_tier(pick_field(
        tbl,
        "tier", "tierLevel", "tier_level", "skillTier", "skill_tier"
    ))
    if t ~= nil then return t end
    if type(tbl.profile) == "table" then
        return profile.tier_from_raw(tbl.profile)
    end
    if type(tbl.stats) == "table" then
        return profile.tier_from_raw(tbl.stats)
    end
    return nil
end

local function is_profile_table(value)
    if value == nil or type(value) ~= "table" then return false end
    if value.name ~= nil or value.steam_id ~= nil or value.steamId ~= nil then return true end
    if type(value.rank) == "number" then return true end
    if tonumber(value.rank) ~= nil then return true end
    return false
end

local function normalize_lap_ms(value)
    local v = tonumber(value)
    if v == nil or v <= 0 then return 0 end
    if v < 1000 then
        v = math.floor(v * 1000 + 0.5)
    end
    return v
end

local function pick_best_lap_ms(tbl)
    if tbl == nil or type(tbl) ~= "table" then return 0 end
    return normalize_lap_ms(pick_field(
        tbl,
        "best_lap_ms", "bestLapMs", "bestLap", "best_lap", "bestTimeMs", "bestTime"
    ))
end

local function pick_last_lap_ms(tbl)
    if tbl == nil or type(tbl) ~= "table" then return 0 end
    if pick_field(tbl, "last_lap_ms", "lastLapMs", "last_lap", "lastLap") ~= nil then
        return normalize_lap_ms(pick_field(tbl, "last_lap_ms", "lastLapMs", "last_lap", "lastLap"))
    end
    return normalize_lap_ms(pick_field(tbl, "lap_ms", "lapMs", "lap_time_ms", "lapTime", "time_ms", "time"))
end

--- Tiempo a mostrar en HUD: última vuelta si existe, si no el mejor tiempo.
function profile.display_lap_ms(value)
    local p = profile.coalesce_profile(value)
    if p == nil then return 0 end
    local last = tonumber(p.last_lap_ms) or 0
    if last > 0 then return last end
    return tonumber(p.best_lap_ms) or 0
end

local function resolve_avatar_url(url)
    if url == nil or url == "" then return nil end
    if type(url) == "table" then
        url = pick_field(url, "url", "href", "src", "imageUrl", "image_url", "avatarUrl", "avatar_url")
    end
    url = util.safe_str(url)
    if url == "" then return nil end
    if url:match("^https?://") or url:match("^data:") then return url end
    if url:sub(1, 1) == "/" then
        return config.API_BASE_URL .. url
    end
    return config.API_BASE_URL .. "/" .. url
end

local function pick_avatar_raw(tbl)
    if tbl == nil or type(tbl) ~= "table" then return nil end
    local direct = pick_field(
        tbl,
        "avatar_url", "avatarUrl", "photo_url", "photoUrl", "imageUrl", "image_url",
        "profileImageUrl", "profile_image_url", "picture", "photo", "image"
    )
    if direct ~= nil then return direct end
    for _, key in ipairs({ "avatar", "photo", "picture", "image", "profileImage", "user" }) do
        local nested = tbl[key]
        if type(nested) == "table" then
            local from_nested = pick_field(nested, "url", "href", "src", "imageUrl", "avatarUrl")
            if from_nested ~= nil then return from_nested end
        elseif type(nested) == "string" and nested ~= "" then
            return nested
        end
    end
    return nil
end

local function is_stats_entry(tbl)
    if tbl == nil or type(tbl) ~= "table" then return false end
    if type(tbl.rivals) == "table" then return true end
    if pick_field(tbl, "rank", "position", "tier", "tierLevel", "best_lap_ms", "bestLapMs", "last_lap_ms", "lastLapMs", "lap_ms", "elo") ~= nil then
        return true
    end
    return false
end

local function unwrap_stats_block(block)
    if block == nil or type(block) ~= "table" then return nil end
    if is_stats_entry(block) then return block end

    for _, key in ipairs({ "current", "self", "player", "me", "track", "car", "global", "board", "timeAttack" }) do
        local nested = block[key]
        if is_stats_entry(nested) then return nested end
    end

    local entries = block.entries or block.times or block.results or block.rows
    if type(entries) == "table" then
        for _, item in ipairs(entries) do
            local unwrapped = unwrap_stats_block(item)
            if unwrapped ~= nil then return unwrapped end
        end
        for _, item in pairs(entries) do
            if type(item) == "table" then
                local unwrapped = unwrap_stats_block(item)
                if unwrapped ~= nil then return unwrapped end
            end
        end
    end

    if block[1] ~= nil then
        for _, item in ipairs(block) do
            local unwrapped = unwrap_stats_block(item)
            if unwrapped ~= nil then return unwrapped end
        end
    end

    return block
end

local function fill_scalar(into, key, value)
    if into == nil or value == nil or value == "" then return end
    local cur = into[key]
    if cur == nil or cur == "" or (type(cur) == "number" and cur <= 0) then
        into[key] = value
    end
end

local function merge_stats_into(merged, stats)
    if merged == nil or stats == nil or type(stats) ~= "table" then return end

    fill_scalar(merged, "rank", tonumber(pick_field(stats, "rank", "position", "globalRank", "leaderboardRank", "lbRank")))
    fill_scalar(merged, "tier", profile.parse_tier(pick_field(stats, "tier", "tierLevel", "tier_level", "skillTier", "skill_tier")))
    fill_scalar(merged, "best_lap_ms", pick_best_lap_ms(stats))
    fill_scalar(merged, "last_lap_ms", pick_last_lap_ms(stats))
    fill_scalar(merged, "elo", tonumber(pick_field(stats, "elo", "mmr", "rating")))

    local car_name = util.safe_str(pick_field(stats, "car_name", "carName", "car", "vehicle", "vehicleName"))
    if car_name ~= "" and (merged.car_name == nil or merged.car_name == "") then
        merged.car_name = car_name
    end
    local car_id = util.safe_str(pick_field(stats, "car_id", "carId", "carModel", "vehicleId"))
    if car_id ~= "" and (merged.car_id == nil or merged.car_id == "") then
        merged.car_id = car_id
    end

    if type(stats.rivals) == "table" then
        merged.rivals = stats.rivals
    end
end

--- hud_session — profile del jugador sustituye rivals y tiempos (sin mezclar con bloques viejos).
local function overlay_session_profile_fields(merged, prof)
    if merged == nil or prof == nil or type(prof) ~= "table" then return end

    if type(prof.rivals) == "table" then
        merged.rivals = prof.rivals
        merged.rival = prof.rivals.above
    elseif prof.rival ~= nil then
        merged.rival = prof.rival
    end

    if pick_field(prof, "best_lap_ms", "bestLapMs", "bestLap", "best_lap") ~= nil then
        merged.best_lap_ms = pick_best_lap_ms(prof)
    end
    if pick_field(prof, "last_lap_ms", "lastLapMs", "last_lap", "lastLap", "lap_ms", "lapMs") ~= nil then
        merged.last_lap_ms = pick_last_lap_ms(prof)
    end

    local rank = tonumber(pick_field(prof, "rank", "position", "globalRank", "leaderboardRank", "lbRank"))
    if rank ~= nil then merged.rank = rank end

    local tier = profile.parse_tier(pick_field(prof, "tier", "tierLevel", "tier_level", "skillTier", "skill_tier"))
    if tier ~= nil then merged.tier = tier end

    if pick_field(prof, "elo", "mmr", "rating") ~= nil then
        merged.elo = tonumber(pick_field(prof, "elo", "mmr", "rating"))
    end

    local name = util.safe_str(pick_field(prof, "name", "displayName", "display_name", "playerName", "player_name"))
    if name ~= "" then merged.name = name end

    local avatar = resolve_avatar_url(pick_avatar_raw(prof))
    if avatar ~= nil then merged.avatar_url = avatar end

    local car_name = util.safe_str(pick_field(prof, "car_name", "carName", "car", "vehicle", "vehicleName"))
    if car_name ~= "" then merged.car_name = car_name end
    local car_id = util.safe_str(pick_field(prof, "car_id", "carId", "carModel", "vehicleId"))
    if car_id ~= "" then merged.car_id = car_id end
end

local function apply_time_attack_sources(merged, raw)
    if raw == nil or type(raw) ~= "table" then return raw end

    local track_stats = unwrap_stats_block(raw.times_on_track or raw.timesOnTrack)
    local global_stats = unwrap_stats_block(raw.global_times or raw.globalTimes)
    if track_stats ~= nil then merge_stats_into(merged, track_stats) end
    if global_stats ~= nil then merge_stats_into(merged, global_stats) end

    local rivals_source = raw
    if type(raw.profile) == "table" then
        if type(raw.profile.rivals) == "table" then
            rivals_source = raw.profile
        end
        merge_stats_into(merged, unwrap_stats_block(raw.profile))
    end
    if type(raw.rivals) == "table" then
        merged.rivals = raw.rivals
        rivals_source = raw
    end
    if track_stats ~= nil and type(track_stats.rivals) == "table" then
        merged.rivals = track_stats.rivals
        rivals_source = track_stats
    elseif global_stats ~= nil and type(global_stats.rivals) == "table" then
        merged.rivals = global_stats.rivals
        rivals_source = global_stats
    end
    if type(merged.rivals) == "table" then
        rivals_source = merged
    end
    if type(raw.profile) == "table" then
        overlay_session_profile_fields(merged, raw.profile)
        if type(raw.profile.rivals) == "table" then
            rivals_source = raw.profile
        end
    end
    return rivals_source
end

local function absorb_fields(into, source, depth)
    if type(source) ~= "table" or type(into) ~= "table" then return end
    depth = depth or 0
    if depth > 3 then return end

    for k, v in pairs(source) do
        if type(k) ~= "string" then goto continue end
        if SKIP_ABSORB_KEYS[k] then goto continue end

        if type(v) == "table" and NESTED_ABSORB_KEYS[k] then
            absorb_fields(into, v, depth + 1)
        elseif type(v) ~= "table" then
            if into[k] == nil or into[k] == "" then
                into[k] = v
            end
        end
        ::continue::
    end

    if depth < 2 then
        for _, nested_key in ipairs({ "stats", "player", "user", "data" }) do
            local nested = source[nested_key]
            if type(nested) == "table" then
                absorb_fields(into, nested, depth + 1)
            end
        end
    end
end

local function row_api_payload(row, session_raw)
    local payload = { ok = true }
    if type(session_raw) == "table" then
        payload.times_on_track = session_raw.times_on_track or session_raw.timesOnTrack
        payload.global_times = session_raw.global_times or session_raw.globalTimes
        payload.ok = session_raw.ok
    end
    if row == nil then return payload end
    if type(row.context) == "table" then
        payload.context = row.context
    end
    if type(row.profile) == "table" then
        payload.profile = row.profile
        for k, v in pairs(row) do
            if k ~= "profile" and k ~= "context" and type(v) ~= "table" then
                payload[k] = v
            end
        end
    else
        payload.profile = row
    end
    return payload
end

function profile.from_session_player(row, session_raw)
    if type(row) ~= "table" then
        return profile.coalesce_from_api(row_api_payload(row, session_raw))
    end
    if type(row.profile) == "table" then
        return profile.normalize_profile(row.profile, row.profile)
    end
    if is_profile_table(row) then
        return profile.normalize_profile(row, row)
    end
    return profile.coalesce_from_api(row_api_payload(row, session_raw))
end

function profile.avatar_from_raw(tbl)
    return resolve_avatar_url(pick_avatar_raw(tbl))
end

function profile.normalize_rival_entry(entry)
    if entry == nil or type(entry) ~= "table" then return nil end
    local name = util.safe_str(pick_field(entry, "name", "displayName", "display_name"))
    local rank = tonumber(pick_field(entry, "rank", "position"))
    if name == "" and rank == nil then return nil end
    return {
        rank = rank or 0,
        name = name ~= "" and name or "?",
        tier = profile.tier_for_display(entry),
        lap_ms = normalize_lap_ms(
            pick_field(entry, "lap_ms", "last_lap_ms", "lastLapMs", "best_lap_ms", "bestLapMs", "lapMs", "bestLap", "time")
        ),
        car_name = util.safe_str(pick_field(entry, "car_name", "carName", "car")),
        car_id = util.safe_str(pick_field(entry, "car_id", "carId", "carModel")),
        avatar_url = resolve_avatar_url(pick_avatar_raw(entry)),
        elo = tonumber(pick_field(entry, "elo", "mmr", "rating")),
    }
end

--- True when the API returned board stats (not just account name/avatar).
function profile.has_board_data(p)
    p = profile.coalesce_profile(p)
    if p == nil then return false end
    if (tonumber(p.rank) or 0) > 0 then return true end
    if (tonumber(p.best_lap_ms) or 0) > 0 then return true end
    if (tonumber(p.last_lap_ms) or 0) > 0 then return true end
    if (tonumber(p.tier) or 0) > 0 then return true end
    local rivals = p.rivals
    if rivals ~= nil and (rivals.above ~= nil or rivals.below ~= nil) then return true end
    return false
end

function profile.normalize_rivals(raw)
    if raw == nil or type(raw) ~= "table" then
        return { above = nil, below = nil }
    end
    local rivals = raw.rivals
    if rivals == nil or type(rivals) ~= "table" then
        local legacy = profile.normalize_rival_entry(raw.rival)
        if legacy ~= nil then
            return { above = legacy, below = nil }
        end
        return { above = nil, below = nil }
    end
    local above = profile.normalize_rival_entry(rivals.above)
    local below = profile.normalize_rival_entry(rivals.below)
    return { above = above, below = below }
end

function profile.normalize_profile(value, rivals_source)
    if not is_profile_table(value) then return nil end
    local name = util.safe_str(
        pick_field(value, "name", "displayName", "display_name", "playerName", "player_name")
    )
    local sid = steam.normalize_steam_id(
        pick_field(value, "steam_id", "steamId", "id")
    )
    local rank = tonumber(pick_field(value, "rank", "position", "leaderboardRank", "globalRank", "lbRank"))
    if rank == nil and (name ~= "" or sid ~= "") then rank = 0 end
    if name == "" and sid == "" and rank == nil then return nil end
    local best_lap = pick_best_lap_ms(value)
    local last_lap = pick_last_lap_ms(value)
    local tier = profile.parse_tier(pick_field(value, "tier", "tierLevel", "tier_level", "skillTier", "skill_tier"))
    if tier == nil and type(value.profile) == "table" then
        tier = profile.tier_from_raw(value.profile)
    end
    local avatar = resolve_avatar_url(pick_avatar_raw(value))
    local elo = tonumber(pick_field(value, "elo", "mmr", "rating"))
    local invalidated = value.isInvalidated == true or value.is_invalidated == true

    local src = rivals_source
    if src == nil and type(value.rivals) == "table" then src = value end
    local rivals = profile.normalize_rivals(src)

    return {
        name = name ~= "" and name or "?",
        rank = rank or 0,
        tier = tier or 0,
        best_lap_ms = best_lap or 0,
        last_lap_ms = last_lap or 0,
        car_name = util.safe_str(pick_field(value, "car_name", "carName", "car", "vehicle", "vehicleName")),
        car_id = util.safe_str(pick_field(value, "car_id", "carId", "carModel", "vehicleId")),
        avatar_url = avatar,
        steam_id = sid ~= "" and sid or nil,
        steamId = sid ~= "" and sid or nil,
        elo = elo,
        rival = rivals.above,
        isInvalidated = invalidated,
        rivals = rivals,
    }
end

function profile.coalesce_from_api(raw)
    if raw == nil or type(raw) ~= "table" then return nil end
    local merged = {}
    absorb_fields(merged, raw, 0)
    local rivals_source = apply_time_attack_sources(merged, raw)
    if type(raw.profile) == "table" then
        absorb_fields(merged, raw.profile, 0)
        if rivals_source == raw or rivals_source == nil then
            rivals_source = raw.profile
        end
    end
    if type(raw.player) == "table" then
        absorb_fields(merged, raw.player, 0)
        if type(raw.player.profile) == "table" then
            absorb_fields(merged, raw.player.profile, 0)
            if rivals_source == raw or rivals_source == nil then
                rivals_source = raw.player.profile
            end
        elseif rivals_source == raw or rivals_source == nil then
            rivals_source = raw.player
        end
    end
    if type(merged.rivals) == "table" then
        rivals_source = merged
    end
    return profile.normalize_profile(merged, rivals_source)
end

function profile.coalesce_profile(value)
    if value == nil or type(value) ~= "table" then return nil end
    return profile.normalize_profile(value, value)
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

function profile.pick_player_profile(players, steam_id, session_raw)
    local list = iter_players(players)
    if #list == 0 then return nil, nil end

    local function from_row(row)
        return profile.from_session_player(row, session_raw)
    end

    if #list == 1 then
        local row = list[1]
        local p = from_row(row)
        if p ~= nil then return p, row end
    end

    for _, player in ipairs(list) do
        if steam.steam_ids_equal(player.steamId or player.steam_id, steam_id) then
            return from_row(player), player
        end
    end

    for _, player in ipairs(list) do
        if player.ok == true then
            local p = from_row(player)
            if p ~= nil then return p, player end
        end
    end

    return nil, list[1]
end

function profile.apply_player_lookup_error(player_row, p, steam_id)
    p = profile.coalesce_profile(p)
    if p ~= nil then
        if p.isInvalidated == true then
            state.last_error = "user_invalidated"
            return
        end
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

function profile.merge_profiles(_existing, incoming)
    return profile.coalesce_profile(incoming)
end

return profile
