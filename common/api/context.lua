--[[ AC session context: track, car, server name, steam id. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")

local context = {}

local function read_track_full_id()
    if ac.getTrackFullID == nil then return "" end
    for _, sep in ipairs({ "|||", "-", "[]" }) do
        local full_id = util.safe_str(util.safe_call(function() return ac.getTrackFullID(sep) end))
        if full_id ~= "" then return full_id end
    end
    return ""
end

local function parse_track_full_id(full_id)
    full_id = util.safe_str(full_id)
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

local function read_server_name(sim)
    local name = steam.server_name_from_race_ini()
    if name ~= "" then return name end

    if sim ~= nil then
        name = util.normalize_server_name(util.safe_call(function() return sim.serverName end))
        if name ~= "" then return name end
        name = util.normalize_server_name(util.safe_call(function() return sim.onlineServerName end))
        if name ~= "" then return name end
    end

    return steam.server_slug_from_race_ini()
end

function context.read_session_context()
    local sim = util.safe_call(function() return ac.getSim() end)
    local full_id = read_track_full_id()

    local track_id = util.safe_str(util.safe_call(function() return ac.getTrackID() end))
    local layout_id = util.safe_str(util.safe_call(function() return ac.getTrackLayout() end))

    if track_id == "" and full_id ~= "" then
        track_id, layout_id = parse_track_full_id(full_id)
    elseif layout_id == "" and full_id ~= "" then
        local parsed_track, parsed_layout = parse_track_full_id(full_id)
        if track_id == "" then track_id = parsed_track end
        if layout_id == "" then layout_id = parsed_layout end
    end

    track_id, layout_id = util.split_track_and_layout(track_id, layout_id)

    return {
        track_id = track_id,
        track_name = util.safe_str(util.safe_call(function() return ac.getTrackName() end)),
        layout_id = layout_id,
        layout_name = layout_id,
        car_id = util.safe_str(util.safe_call(function() return ac.getCarID(0) end)),
        car_name = util.safe_str(util.safe_call(function() return ac.getCarName(0) end)),
        player_steam_id = steam.read_player_steam_id(sim),
        server_name = read_server_name(sim),
        track_full_id = full_id,
    }
end

function context.context_is_ready(ctx)
    return ctx ~= nil
        and steam.normalize_steam_id(ctx.player_steam_id) ~= ""
        and util.safe_str(ctx.track_id) ~= ""
end

function context.build_server_name_candidates(ctx)
    local seen, out = {}, {}
    local function push(name)
        name = util.normalize_server_name(name)
        if name == "" then return end
        local key = string.lower(name)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = name
    end

    if state.last_resolved_server_name ~= nil and state.last_resolved_server_name ~= "" then
        push(state.last_resolved_server_name)
    end
    push(steam.server_name_from_race_ini())
    push(ctx.server_name)

    local full_name = util.safe_str(ctx.server_name)
    if full_name ~= "" then
        local prefix = full_name:match("^([^|]+)")
        if prefix ~= nil then push(prefix:gsub("%s+$", "")) end
    end

    push(steam.server_slug_from_race_ini())
    for _, slug in ipairs(config.SERVER_SLUG_FALLBACKS or {}) do push(slug) end
    return out
end

return context
