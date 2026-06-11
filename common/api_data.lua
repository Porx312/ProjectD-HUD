--[[ ProjectD HUD — live data from ac-data API. Interface = mock_data.lua ]]

local config = require("common.config")
local api = {}

local cached_at = 0
local cached_filter = "global"
local cached_bundle = nil
local fetch_pending = false
local profile_fetch_pending = false
local last_http_status = nil
local last_error = nil
local last_fetch_at = 0
local last_attempt_at = 0
local last_profile_attempt_at = 0
local profile_fetch_started_at = 0
local fetch_attempt = 0
local profile_fetch_attempt = 0
local profile_candidates_exhausted = false
local server_name_candidates = nil
local profile_server_candidates = nil
local last_resolved_server_name = nil
local last_session_had_players = false

local debug_storage = ac.storage("ProjectD-HUD:debug", false)
local steam_override_storage = ac.storage("ProjectD-HUD:steam_id", "")
local steam_cache_storage = ac.storage("ProjectD-HUD:steam_cache", "")

local CONTEXT_RETRY_SEC = 0.5
local PROFILE_RETRY_SEC = 8
local PROFILE_FETCH_TIMEOUT_SEC = 12

local function safe_str(value)
    if value == nil then return "" end
    if type(value) == "string" then return value end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    local ok, text = pcall(tostring, value)
    if ok and text ~= nil then return text end
    return ""
end

local function safe_call(fn)
    local ok, value = pcall(fn)
    if not ok then return nil end
    return value
end

local function is_web_error(err)
    if err == nil or err == false then return false end
    if type(err) == "string" and err == "" then return false end
    return true
end

local function http_status_code(response)
    if response == nil or type(response) ~= "table" then return nil end
    return tonumber(response.status)
end

local function http_response_ok(response)
    if response == nil then return false end
    if type(response) == "string" then return true end
    local code = http_status_code(response)
    if code == nil then return true end
    return code == 200
end

local function response_body(response)
    if response == nil then return nil end
    if type(response) == "string" then return response end
    if type(response) == "table" then
        return response.body or response.text or response.content or response.data
    end
    return nil
end

local function decode_json(body)
    if type(body) == "table" then return body end
    if body == nil then return nil end
    body = safe_str(body)
    if body == "" then return nil end

    if JSON ~= nil and JSON.parse ~= nil then
        local ok, data = pcall(JSON.parse, body)
        if ok and type(data) == "table" then return data end
    end

    if __util ~= nil and __util.jsonParse ~= nil then
        local ok, data = pcall(__util.jsonParse, body)
        if ok and type(data) == "table" then return data end
    end

    local ok, mod = pcall(require, "lib_jsonparse")
    if ok and mod ~= nil then
        local ok2, data = pcall(mod, body)
        if ok2 and type(data) == "table" then return data end
    end

    last_error = "json_parse_failed"
    return nil
end

local function url_encode(str)
    str = safe_str(str)
    if str == "" then return "" end
    return string.gsub(str, "([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

local function normalize_server_name(name)
    name = safe_str(name)
    if name == "" then return "" end
    name = name:gsub("[%s%p]*[ℹiI]%d+%s*$", "")
    name = name:gsub("%s+$", "")
    return name
end

local function split_track_and_layout(track_id, layout_id)
    track_id = safe_str(track_id)
    layout_id = safe_str(layout_id)
    if layout_id ~= "" then return track_id, layout_id end
    local base, rest = track_id:match("^([^%-]+)%-(.+)$")
    if base ~= nil and rest ~= nil and rest ~= "" then
        return base, rest
    end
    return track_id, layout_id
end

--- SteamID64 exceeds IEEE double precision; never tonumber() a 17-digit string.
local function normalize_steam_id(value)
    if value == nil then return "" end

    local id = safe_str(value)
    if id ~= "" and id ~= "0" then
        id = id:gsub("%s+", "")
        id = id:gsub("^https?://steamcommunity%.com/profiles/", "")
        local digits_only = id:match("^(%d+)")
        if digits_only ~= nil and #digits_only >= 15 then return digits_only end
        local embedded = id:match("(%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d+)")
        if embedded ~= nil then return embedded end
    end

    if type(value) == "number" and value > 0 then
        return string.format("%.0f", value)
    end

    return ""
end

local function read_track_full_id()
    if ac.getTrackFullID == nil then return "" end
    for _, sep in ipairs({ "|||", "-", "[]" }) do
        local full_id = safe_str(safe_call(function() return ac.getTrackFullID(sep) end))
        if full_id ~= "" then return full_id end
    end
    return ""
end

local function parse_track_full_id(full_id)
    full_id = safe_str(full_id)
    if full_id == "" then return "", "" end

    local base, layout = full_id:match("^([^|]+)|+(.+)$")
    if base ~= nil and layout ~= nil and layout ~= "" then
        return base, layout
    end

    base, layout = full_id:match("^([^%-]+)%-(.+)$")
    if base ~= nil and layout ~= nil and layout ~= "" then
        return base, layout
    end

    base, layout = full_id:match("^([^%[]+)%[(.+)%]$")
    if base ~= nil and layout ~= nil and layout ~= "" then
        return base, layout
    end

    return full_id, ""
end

local STEAM_BRIDGE_KEY = "ProjectD:playerSteamId"

local race_ini_cache = { at = 0, ini = nil }

local function race_ini_path()
    local docs = safe_call(function() return ac.getFolder(ac.FolderID.Documents) end)
    if safe_str(docs) == "" then return "" end
    return docs .. "/Assetto Corsa/cfg/race.ini"
end

local function get_race_ini()
    local now = os.clock()
    if race_ini_cache.ini ~= nil and (now - race_ini_cache.at) < 2 then
        return race_ini_cache.ini
    end
    race_ini_cache.ini = nil
    race_ini_cache.at = now

    local path = race_ini_path()
    if path == "" then return nil end
    if ac.INIConfig == nil or ac.INIConfig.load == nil or ac.INIFormat == nil then return nil end

    local ok, ini = pcall(ac.INIConfig.load, path, ac.INIFormat.Extended)
    if ok and ini ~= nil then
        race_ini_cache.ini = ini
        return ini
    end
    return nil
end

local function race_remote_active(ini)
    if ini == nil then return false end
    return tonumber(ini:get("REMOTE", "ACTIVE", 0)) == 1
end

local function read_race_ini_raw()
    local path = race_ini_path()
    if path == "" then return "" end
    local ok, content = pcall(function()
        local file = io.open(path, "r")
        if file == nil then return nil end
        local data = file:read("*a")
        file:close()
        return data
    end)
    if ok and type(content) == "string" then return content end
    return ""
end

--- CSP Lua apps cannot call ac.getUserSteamID() online; Steam ID64 is in race.ini [REMOTE] GUID.
local function steam_from_race_ini_raw(content, require_remote)
    if content == "" then return "" end

    local in_remote = false
    for line in content:gmatch("[^\r\n]+") do
        local section = line:match("^%[([^%]]+)%]")
        if section ~= nil then
            in_remote = section == "REMOTE"
        elseif in_remote or not require_remote then
            local guid = line:match("^GUID%s*=%s*(%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d+)")
            if guid ~= nil then return guid end
        end
    end

    if not require_remote then
        local any_guid = content:match("GUID%s*=%s*(%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d+)")
        if any_guid ~= nil then return any_guid end
    end

    return ""
end

local function steam_from_race_ini()
    local content = read_race_ini_raw()
    if content ~= "" then
        local id = steam_from_race_ini_raw(content, true)
        if id ~= "" then return id end
        id = steam_from_race_ini_raw(content, false)
        if id ~= "" then return id end
    end

    local ini = get_race_ini()
    if ini ~= nil then
        if race_remote_active(ini) then
            local id = normalize_steam_id(ini:get("REMOTE", "GUID", ""))
            if id ~= "" then return id end
        end
        for _, section in ipairs({ "REMOTE", "RACE" }) do
            local id = normalize_steam_id(ini:get(section, "GUID", ""))
            if id ~= "" then return id end
        end
    end

    return ""
end

--- Server display name for online sessions lives in race.ini [REMOTE] SERVER_NAME (sim.serverName is often empty in apps).
local function server_name_from_race_ini()
    local ini = get_race_ini()
    if ini ~= nil and race_remote_active(ini) then
        local name = normalize_server_name(ini:get("REMOTE", "SERVER_NAME", ""))
        if name ~= "" then return name end
    end

    local content = read_race_ini_raw()
    if content == "" then return "" end

    local in_remote = false
    for line in content:gmatch("[^\r\n]+") do
        local section = line:match("^%[([^%]]+)%]")
        if section ~= nil then
            in_remote = section == "REMOTE"
        elseif in_remote then
            local server_name = line:match("^SERVER_NAME%s*=%s*(.+)$")
            if server_name ~= nil then
                return normalize_server_name(server_name)
            end
        end
    end

    return ""
end

local function server_slug_from_race_ini()
    local ini = get_race_ini()
    if ini ~= nil and race_remote_active(ini) then
        return normalize_server_name(ini:get("REMOTE", "NAME", ""))
    end
    return ""
end

local function steam_from_online_bridge()
    local value = safe_call(function() return ac.load(STEAM_BRIDGE_KEY) end)
    return normalize_steam_id(value)
end

local function remember_steam_id(id)
    id = normalize_steam_id(id)
    if id ~= "" then
        steam_cache_storage:set(id)
    end
    return id
end

local function read_player_steam_id(_sim)
    local override = normalize_steam_id(steam_override_storage:get())
    if override ~= "" then return remember_steam_id(override) end

    local sources = {
        steam_from_race_ini,
        steam_from_online_bridge,
        function()
            if ac.getUserSteamID == nil then return "" end
            return normalize_steam_id(safe_call(ac.getUserSteamID))
        end,
        function()
            return normalize_steam_id(steam_cache_storage:get())
        end,
    }

    for _, read in ipairs(sources) do
        local id = safe_call(read) or ""
        if id ~= "" then return remember_steam_id(id) end
    end

    return ""
end

local function read_server_name(sim)
    local name = server_name_from_race_ini()
    if name ~= "" then return name end

    if sim ~= nil then
        name = normalize_server_name(safe_call(function() return sim.serverName end))
        if name ~= "" then return name end
        name = normalize_server_name(safe_call(function() return sim.onlineServerName end))
        if name ~= "" then return name end
    end

    return server_slug_from_race_ini()
end

local function read_session_context()
    local sim = safe_call(function() return ac.getSim() end)
    local full_id = read_track_full_id()

    local track_id = safe_str(safe_call(function() return ac.getTrackID() end))
    local layout_id = safe_str(safe_call(function() return ac.getTrackLayout() end))

    if track_id == "" and full_id ~= "" then
        track_id, layout_id = parse_track_full_id(full_id)
    elseif layout_id == "" and full_id ~= "" then
        local parsed_track, parsed_layout = parse_track_full_id(full_id)
        if track_id == "" then track_id = parsed_track end
        if layout_id == "" then layout_id = parsed_layout end
    end

    track_id, layout_id = split_track_and_layout(track_id, layout_id)

    return {
        track_id = track_id,
        track_name = safe_str(safe_call(function() return ac.getTrackName() end)),
        layout_id = layout_id,
        layout_name = layout_id,
        car_id = safe_str(safe_call(function() return ac.getCarID(0) end)),
        car_name = safe_str(safe_call(function() return ac.getCarName(0) end)),
        player_steam_id = read_player_steam_id(sim),
        server_name = read_server_name(sim),
        track_full_id = full_id,
    }
end

local function context_is_ready(ctx)
    return ctx ~= nil
        and normalize_steam_id(ctx.player_steam_id) ~= ""
        and safe_str(ctx.track_id) ~= ""
end

local function build_server_name_candidates(ctx)
    local seen, out = {}, {}
    local function push(name)
        name = normalize_server_name(name)
        if name == "" then return end
        local key = string.lower(name)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = name
    end

    push(ctx.server_name)
    push(server_name_from_race_ini())

    local full_name = safe_str(ctx.server_name)
    if full_name ~= "" then
        local prefix = full_name:match("^([^|]+)")
        if prefix ~= nil then push(prefix:gsub("%s+$", "")) end
    end

    push(server_slug_from_race_ini())
    for _, slug in ipairs(config.SERVER_SLUG_FALLBACKS or {}) do push(slug) end
    return out
end

local function response_is_ok(data)
    if data == nil or type(data) ~= "table" then return false end
    if data.error ~= nil then return false end
    if data.ok == false then return false end
    if data.ok == true then return true end
    if data.leaderboard ~= nil then return true end
    return false
end

local function steam_ids_equal(a, b)
    local na = normalize_steam_id(a)
    local nb = normalize_steam_id(b)
    return na ~= "" and nb ~= "" and na == nb
end

local function is_profile_table(value)
    if value == nil or type(value) ~= "table" then return false end
    if value.name ~= nil or value.steam_id ~= nil or value.steamId ~= nil then return true end
    if type(value.rank) == "number" then return true end
    if tonumber(value.rank) ~= nil then return true end
    return false
end

--- Normalize API profile (rank 0 / no lap time is valid for linked users).
local function normalize_profile(value)
    if not is_profile_table(value) then return nil end
    local name = safe_str(value.name)
    local steam = normalize_steam_id(value.steam_id or value.steamId)
    local rank = tonumber(value.rank)
    if rank == nil and (name ~= "" or steam ~= "") then rank = 0 end
    if name == "" and steam == "" and rank == nil then return nil end
    return {
        name = name ~= "" and name or "?",
        rank = rank or 0,
        tier = tonumber(value.tier) or 0,
        best_lap_ms = tonumber(value.best_lap_ms) or tonumber(value.lap_ms) or 0,
        car_name = safe_str(value.car_name),
        car_id = safe_str(value.car_id),
        avatar_url = value.avatar_url,
        steam_id = steam ~= "" and steam or nil,
        steamId = steam ~= "" and steam or nil,
        rival = type(value.rival) == "table" and value.rival or nil,
    }
end

local function coalesce_profile(value)
    return normalize_profile(value)
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

local function pick_player_profile(players, steam_id)
    local list = iter_players(players)
    if #list == 0 then return nil, nil end

    -- Session requests one steamId; lone player row is the usual case.
    if #list == 1 then
        local row = list[1]
        local profile = coalesce_profile(row.profile)
        if profile ~= nil then return profile, row end
    end

    for _, player in ipairs(list) do
        if steam_ids_equal(player.steamId or player.steam_id, steam_id) then
            return coalesce_profile(player.profile), player
        end
    end

    for _, player in ipairs(list) do
        if player.ok == true then
            local profile = coalesce_profile(player.profile)
            if profile ~= nil then return profile, player end
        end
    end

    return nil, list[1]
end

local function derive_rival_from_leaderboard(profile, leaderboard)
    if profile == nil or leaderboard == nil or type(leaderboard) ~= "table" then return nil end
    local rank = tonumber(profile.rank) or 0
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

local function apply_player_lookup_error(player_row, profile, steam_id)
    profile = coalesce_profile(profile)
    if profile ~= nil then
        last_error = nil
        return
    end
    if player_row == nil then return end
    if player_row.ok == false and player_row.reason ~= nil then
        last_error = tostring(player_row.reason)
        return
    end
    -- API: unlinked user = ok:true, profile:null, context:null
    if player_row.ok == true and player_row.profile == nil and player_row.context == nil then
        last_error = "user_not_found"
        return
    end
    if steam_ids_equal(player_row.steamId or player_row.steam_id, steam_id) then
        if player_row.context ~= nil then
            last_error = "profile_unavailable"
        elseif player_row.profile == nil then
            last_error = "user_not_found"
        else
            last_error = "profile_unavailable"
        end
    end
end

local function normalize_session_response(data, steam_id)
    steam_id = normalize_steam_id(steam_id)

    if not response_is_ok(data) then
        if data ~= nil and data.error ~= nil then
            last_error = tostring(data.error)
        elseif data ~= nil and data.reason ~= nil then
            last_error = tostring(data.reason)
        end
        return nil
    end

    local player_list = iter_players(data.players)
    last_session_had_players = #player_list > 0

    local out = {
        ok = true,
        context = data.context,
        leaderboard = data.leaderboard,
        profile = coalesce_profile(data.profile),
    }

    local player_profile, player_row = pick_player_profile(data.players, steam_id)
    if player_row ~= nil then
        if player_row.context ~= nil then out.context = player_row.context end
        if player_profile ~= nil then out.profile = player_profile end
        apply_player_lookup_error(player_row, out.profile, steam_id)
    elseif out.profile == nil and data.context ~= nil then
        last_error = "profile_unavailable"
    end

    if out.profile ~= nil and out.profile.rival == nil and out.leaderboard ~= nil then
        local derived = derive_rival_from_leaderboard(out.profile, out.leaderboard)
        if derived ~= nil then
            out.profile.rival = derived
        end
    end

    if out.profile ~= nil then
        last_error = nil
    end

    return out
end

local function copy_entries(list)
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

local function apply_bundle(bundle, car_filter)
    if bundle == nil or bundle.ok ~= true then return false end
    cached_bundle = bundle
    cached_filter = car_filter or "global"
    cached_at = os.clock()
    fetch_attempt = 0
    server_name_candidates = nil
    return true
end

local function bundle_needs_profile()
    if cached_bundle == nil or cached_bundle.ok ~= true then return false end
    if coalesce_profile(cached_bundle.profile) ~= nil then return false end
    if last_error == "user_not_found" then return false end
    return true
end

local function merge_profile_into_bundle(profile)
    profile = coalesce_profile(profile)
    if cached_bundle == nil or profile == nil then return false end
    cached_bundle.profile = profile
    if profile.rival == nil and cached_bundle.leaderboard ~= nil then
        local derived = derive_rival_from_leaderboard(profile, cached_bundle.leaderboard)
        if derived ~= nil then
            cached_bundle.profile.rival = derived
        end
    end
    return true
end

--- Fallback when session Redis blob has no players[] (legacy cache).
local function profile_fetch_url(ctx, server_name)
    return string.format(
        "%s%s?steamId=%s&serverName=%s&track=%s&trackConfig=%s&carModel=%s",
        config.API_BASE_URL,
        config.PLAYER_PATH or "/hud/player",
        url_encode(ctx.player_steam_id),
        url_encode(server_name),
        url_encode(ctx.track_id),
        url_encode(ctx.layout_id),
        url_encode(ctx.car_id)
    )
end

local function profile_server_list(ctx)
    if profile_server_candidates ~= nil and #profile_server_candidates > 0 then
        return profile_server_candidates
    end
    local list = {}
    local function push(name)
        name = normalize_server_name(name)
        if name == "" then return end
        list[#list + 1] = name
    end
    if last_resolved_server_name ~= nil and last_resolved_server_name ~= "" then
        push(last_resolved_server_name)
        profile_server_candidates = list
        return list
    end
    if cached_bundle ~= nil and cached_bundle.context ~= nil then
        push(cached_bundle.context.server_name)
    end
    push(server_name_from_race_ini())
    push(ctx.server_name)
    profile_server_candidates = list
    return list
end

local function mark_profile_candidates_exhausted(reason)
    profile_candidates_exhausted = true
    profile_server_candidates = nil
    profile_fetch_attempt = 0
    if reason ~= nil and reason ~= "" then
        last_error = tostring(reason)
    elseif last_error == nil then
        last_error = "profile_unavailable"
    end
end

local function start_profile_fetch(ctx, force_new_cycle, chain_next)
    if not bundle_needs_profile() then
        profile_candidates_exhausted = false
        return
    end
    if profile_fetch_pending then return end
    if fetch_pending and not chain_next then return end

    ctx.player_steam_id = normalize_steam_id(ctx.player_steam_id)
    if ctx.player_steam_id == "" or safe_str(ctx.track_id) == "" then return end

    local now = os.clock()
    if not chain_next and not force_new_cycle and profile_candidates_exhausted then
        if (now - last_profile_attempt_at) < PROFILE_RETRY_SEC then return end
        profile_candidates_exhausted = false
    end
    if not chain_next and not force_new_cycle and (now - last_profile_attempt_at) < PROFILE_RETRY_SEC then
        return
    end

    if force_new_cycle or profile_server_candidates == nil then
        profile_server_candidates = nil
        profile_fetch_attempt = 0
        profile_candidates_exhausted = false
    end

    local candidates = profile_server_list(ctx)
    if #candidates == 0 then
        mark_profile_candidates_exhausted("missing_server_name")
        return
    end

    profile_fetch_attempt = profile_fetch_attempt + 1
    local server_name = candidates[profile_fetch_attempt]
    if server_name == nil then
        mark_profile_candidates_exhausted("profile_unavailable")
        return
    end

    last_profile_attempt_at = now
    profile_fetch_pending = true
    profile_fetch_started_at = now
    local url = profile_fetch_url(ctx, server_name)
    if api.is_debug() then
        ac.debug("ProjectD-HUD profile GET", url)
    end

    web.get(url, function(err, response)
        profile_fetch_pending = false

        local function try_next(reason)
            if profile_fetch_attempt < #candidates then
                start_profile_fetch(ctx, false, true)
                return
            end
            mark_profile_candidates_exhausted(reason)
        end

        if is_web_error(err) then
            try_next("network_error")
            return
        end

        last_http_status = http_status_code(response) or last_http_status

        if not http_response_ok(response) then
            local code = http_status_code(response)
            if code == 404 and profile_fetch_attempt < #candidates then
                start_profile_fetch(ctx, false, true)
                return
            end
            try_next("http_" .. tostring(code or "nil"))
            return
        end

        local raw = decode_json(response_body(response))
        if raw == nil and type(response) == "table" then
            raw = response
        end
        if raw == nil then
            try_next("json_parse_failed")
            return
        end

        if raw.ok == false then
            local reason = tostring(raw.reason or "user_not_found")
            if reason == "server_not_found" or reason == "track_not_found" then
                try_next(reason)
            else
                last_error = reason
                profile_candidates_exhausted = true
            end
            return
        end

        local profile = coalesce_profile(raw.profile)
        if profile ~= nil then
            last_resolved_server_name = server_name
            profile_server_candidates = nil
            profile_fetch_attempt = 0
            profile_candidates_exhausted = false
            last_session_had_players = true
            merge_profile_into_bundle(profile)
            last_error = nil
            return
        end

        if raw.context ~= nil then
            last_error = "profile_unavailable"
        else
            last_error = "user_not_found"
        end
        profile_candidates_exhausted = true
    end)
end

local function session_url(ctx, server_name, car_filter)
    return string.format(
        "%s%s?steamIds=%s&serverName=%s&track=%s&trackConfig=%s&carFilter=%s&carModel=%s",
        config.API_BASE_URL,
        config.SESSION_PATH,
        url_encode(ctx.player_steam_id),
        url_encode(server_name),
        url_encode(ctx.track_id),
        url_encode(ctx.layout_id),
        url_encode(car_filter),
        url_encode(ctx.car_id)
    )
end

local function start_fetch(ctx, car_filter, force_new_cycle)
    if fetch_pending then return end
    if profile_fetch_pending then return end

    ctx.player_steam_id = normalize_steam_id(ctx.player_steam_id)
    if safe_str(ctx.track_id) == "" then
        last_error = "missing_track"
        return
    end
    if ctx.player_steam_id == "" then
        last_error = "missing_steam"
        return
    end

    if force_new_cycle or server_name_candidates == nil then
        server_name_candidates = build_server_name_candidates(ctx)
        fetch_attempt = 0
    end

    if server_name_candidates == nil or #server_name_candidates == 0 then
        last_error = "missing_server_name"
        return
    end

    fetch_attempt = fetch_attempt + 1
    local server_name = server_name_candidates[fetch_attempt]
    if server_name == nil then
        fetch_attempt = 0
        return
    end

    local url = session_url(ctx, server_name, car_filter)
    fetch_pending = true
    last_fetch_at = os.clock()
    last_session_had_players = false

    web.get(url, function(err, response)
        fetch_pending = false
        last_http_status = http_status_code(response) or (response and response.status) or nil

        if is_web_error(err) then
            last_error = "network_error"
            if fetch_attempt < #server_name_candidates then
                start_fetch(ctx, car_filter, false)
            end
            return
        end

        if not http_response_ok(response) then
            last_error = "http_" .. tostring(http_status_code(response) or "nil")
            if fetch_attempt < #server_name_candidates then
                start_fetch(ctx, car_filter, false)
            end
            return
        end

        local raw = decode_json(response_body(response))
        if raw == nil and type(response) == "table" then
            raw = response
        end
        if raw == nil then
            if fetch_attempt < #server_name_candidates then
                start_fetch(ctx, car_filter, false)
            end
            return
        end

        local data = normalize_session_response(raw, ctx.player_steam_id)
        if data == nil then
            if fetch_attempt < #server_name_candidates then
                start_fetch(ctx, car_filter, false)
            end
            return
        end

        last_resolved_server_name = server_name
        apply_bundle(data, car_filter)
        profile_candidates_exhausted = false
        if bundle_needs_profile() then
            start_profile_fetch(ctx, true, true)
        else
            profile_server_candidates = nil
            profile_fetch_attempt = 0
        end
    end)
end

function api.fetch_session(car_filter, force)
    car_filter = car_filter or "global"
    local now = os.clock()

    if profile_fetch_pending then return end

    if not force and cached_bundle ~= nil and cached_filter == car_filter then
        if (now - cached_at) < config.CACHE_TTL_SEC then
            if bundle_needs_profile() then
                local ok_ctx, ctx = pcall(read_session_context)
                if ok_ctx then start_profile_fetch(ctx, false, false) end
            end
            return
        end
    end

    local ok, ctx = pcall(read_session_context)
    if not ok then
        last_error = "context_error"
        ac.debug("ProjectD-HUD context", safe_str(ctx))
        return
    end

    local retry_sec = context_is_ready(ctx) and config.CACHE_TTL_SEC or CONTEXT_RETRY_SEC
    if not force and cached_bundle == nil and (now - last_attempt_at) < retry_sec then
        return
    end
    last_attempt_at = now

    start_fetch(ctx, car_filter, force == true)
end

local function watchdog_profile_fetch(ctx)
    if not profile_fetch_pending then return end
    if (os.clock() - profile_fetch_started_at) < PROFILE_FETCH_TIMEOUT_SEC then return end
    profile_fetch_pending = false
    ac.debug("ProjectD-HUD profile", "fetch timeout")
    if profile_server_candidates ~= nil and profile_fetch_attempt < #profile_server_candidates then
        start_profile_fetch(ctx, false, true)
    else
        mark_profile_candidates_exhausted("profile_timeout")
    end
end

function api.tick(car_filter)
    local ok_ctx, ctx = pcall(read_session_context)
    if ok_ctx then watchdog_profile_fetch(ctx) end

    local ok, err = pcall(api.fetch_session, car_filter or cached_filter, false)
    if not ok then
        last_error = "tick_error"
        ac.debug("ProjectD-HUD tick", safe_str(err))
        return
    end
    if ok_ctx and bundle_needs_profile() and not profile_fetch_pending then
        pcall(start_profile_fetch, ctx, false, false)
    end
end

function api.is_loading()
    return fetch_pending or profile_fetch_pending
end

function api.get_status()
    local ok, ctx = pcall(read_session_context)
    if not ok then ctx = {} end
    return {
        loading = fetch_pending,
        error = last_error,
        http_status = last_http_status,
        has_bundle = cached_bundle ~= nil,
        entry_count = cached_bundle
            and cached_bundle.leaderboard
            and cached_bundle.leaderboard.entries
            and #cached_bundle.leaderboard.entries
            or 0,
        steam_id = safe_str(ctx.player_steam_id),
        server_name = safe_str(ctx.server_name),
        track_id = safe_str(ctx.track_id),
        layout_id = safe_str(ctx.layout_id),
        context_ready = context_is_ready(ctx),
    }
end

local function profile_missing_message()
    if profile_fetch_pending then return "Loading profile..." end
    if last_error == "user_not_found" then
        return "Link Steam in ProjectD"
    end
    if last_error == "missing_steam" then return "Waiting for Steam ID" end
    if last_error == "network_error" then return "Network error (profile)" end
    if last_error == "server_not_found" then return "Server not found" end
    if last_error == "profile_unavailable" then return "Profile unavailable" end
    if last_error ~= nil and string.sub(last_error, 1, 4) == "http" then
        return "Profile unavailable"
    end
    if last_error ~= nil then return tostring(last_error) end
    if fetch_pending then return "Loading profile..." end
    if bundle_needs_profile() and not profile_candidates_exhausted then
        return "Loading profile..."
    end
    return "Profile unavailable"
end

function api.get_status_message(kind)
    local st = api.get_status()
    if st.loading then return "Loading..." end
    if st.has_bundle then
        local n = st.entry_count or 0
        if kind == "leaderboard" and n > 0 then return nil end
        if kind == "leaderboard" and n == 0 then return "No times on this track" end
        if kind == "profile" and coalesce_profile(cached_bundle.profile) == nil then
            return profile_missing_message()
        end
        if kind == "rival" then
            local p = coalesce_profile(cached_bundle.profile)
            if p == nil then return profile_missing_message() end
            local rank = tonumber(p.rank) or 0
            if rank == 1 then return "You're #1 — no rival" end
            if rank == 0 then return "No time yet — no rival" end
            if p.rival == nil then return "No rival data" end
        end
    end
    if last_error == "json_parse_failed" then return "JSON parse error" end
    if last_error == "missing_server_name" then return "No server name" end
    if last_error == "missing_steam" then return "Waiting for Steam ID" end
    if last_error == "missing_track" then return "Waiting for track" end
    if last_error == "missing_steam_or_track" then return "Waiting for Steam / track" end
    if last_error == "network_error" then return "Network error" end
    if last_error == "context_error" then return "AC context error" end
    if last_error ~= nil and string.sub(last_error, 1, 4) == "http" then
        return "API " .. tostring(last_http_status or "?")
    end
    if last_error ~= nil then return tostring(last_error) end
    if not st.has_bundle then return "Waiting for API..." end
    return "No data"
end

function api.is_debug()
    return debug_storage:get() == true
end

function api.get_debug_lines()
    if not api.is_debug() then return {} end
    local ok, ctx = pcall(read_session_context)
    if not ok then ctx = {} end
    local st = api.get_status()
    return {
        "steam=" .. safe_str(ctx.player_steam_id),
        "server=" .. safe_str(ctx.server_name),
        "race_server=" .. server_name_from_race_ini(),
        "race_slug=" .. server_slug_from_race_ini(),
        "race.ini=" .. steam_from_race_ini(),
        "bridge=" .. steam_from_online_bridge(),
        "track=" .. safe_str(ctx.track_id) .. "/" .. safe_str(ctx.layout_id),
        "full=" .. safe_str(ctx.track_full_id),
        "car=" .. safe_str(ctx.car_id),
        "http=" .. tostring(st.http_status),
        "err=" .. tostring(st.error),
        "bundle=" .. tostring(st.has_bundle),
        "entries=" .. tostring(st.entry_count),
        "profile=" .. tostring(coalesce_profile(cached_bundle and cached_bundle.profile) ~= nil),
        "rank=" .. tostring(cached_bundle and cached_bundle.profile and cached_bundle.profile.rank or "?"),
        "rival=" .. tostring(cached_bundle ~= nil and cached_bundle.profile ~= nil and cached_bundle.profile.rival ~= nil),
        "srv=" .. safe_str(last_resolved_server_name),
        "prof_load=" .. tostring(profile_fetch_pending),
        "prof_done=" .. tostring(profile_candidates_exhausted),
        "prof_try=" .. tostring(profile_fetch_attempt),
        "players=" .. tostring(last_session_had_players),
    }
end

function api.get_context()
    if cached_bundle ~= nil and cached_bundle.context ~= nil then
        local c = cached_bundle.context
        return {
            server_id = safe_str(c.server_id),
            track_id = safe_str(c.track_id),
            track_name = safe_str(c.track_name),
            layout_id = safe_str(c.layout_id),
            layout_name = safe_str(c.layout_name),
            car_id = safe_str(c.car_id),
            car_name = safe_str(c.car_name),
            player_steam_id = safe_str(c.player_steam_id),
        }
    end
    local ok, ctx = pcall(read_session_context)
    if not ok then return {} end
    return {
        track_id = ctx.track_id,
        track_name = ctx.track_name,
        layout_id = ctx.layout_id,
        layout_name = ctx.layout_name,
        car_id = ctx.car_id,
        car_name = ctx.car_name,
        player_steam_id = ctx.player_steam_id,
    }
end

function api.get_leaderboard_filters()
    if cached_bundle ~= nil and cached_bundle.leaderboard ~= nil and cached_bundle.leaderboard.filters ~= nil then
        local filters = cached_bundle.leaderboard.filters
        if #filters > 0 then return filters end
    end
    return { { id = "global", label = "Global ranking" } }
end

function api.get_leaderboard_header()
    if cached_bundle ~= nil and cached_bundle.leaderboard ~= nil then
        local lb = cached_bundle.leaderboard
        return { title = lb.title or "Top 10", map = lb.map or "", layout = lb.layout or "" }
    end
    local ctx = api.get_context()
    return {
        title = "Top 10",
        map = ctx.track_name or ctx.track_id or "",
        layout = ctx.layout_name or ctx.layout_id or "",
    }
end

function api.get_top10(car_filter)
    car_filter = car_filter or "global"
    if cached_filter ~= car_filter or cached_bundle == nil then
        api.fetch_session(car_filter, cached_bundle == nil)
    end
    if cached_bundle ~= nil and cached_bundle.leaderboard ~= nil then
        return copy_entries(cached_bundle.leaderboard.entries)
    end
    return {}
end

function api.get_top8(car_filter) return api.get_top10(car_filter) end
function api.get_top5(car_filter) return api.get_top10(car_filter) end

function api.get_player_profile()
    local p = coalesce_profile(cached_bundle and cached_bundle.profile)
    if p ~= nil then
        return {
            name = p.name or "?",
            rank = tonumber(p.rank) or 0,
            tier = tonumber(p.tier) or 0,
            best_lap_ms = tonumber(p.best_lap_ms) or 0,
            car_name = p.car_name or "",
            car_id = p.car_id or "",
            avatar_url = p.avatar_url,
            steam_id = p.steam_id or p.steamId,
        }
    end
    return nil
end

function api.get_rival()
    local profile = coalesce_profile(cached_bundle and cached_bundle.profile)
    if profile == nil then return nil end

    local r = profile.rival
    if r == nil and cached_bundle ~= nil and cached_bundle.leaderboard ~= nil then
        r = derive_rival_from_leaderboard(profile, cached_bundle.leaderboard)
    end
    if r == nil then return nil end

    return {
        name = r.name or "?",
        rank = tonumber(r.rank) or 0,
        tier = tonumber(r.tier) or 0,
        best_lap_ms = tonumber(r.best_lap_ms) or tonumber(r.lap_ms) or 0,
        car_name = r.car_name or "",
        avatar_url = r.avatar_url,
    }
end

function api.init()
    api.fetch_session("global", true)
end

return api
