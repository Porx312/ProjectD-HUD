--[[ AC session context: track, car, server name, steam id. ]]

local config = require("common.config")
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

local function read_sim_server_name(sim)
    if sim == nil then return "" end
    local keys = {
        "serverName", "onlineServerName", "acServerName", "serverTitle",
        "server_name", "onlineServer", "onlineServerTitle",
    }
    for _, key in ipairs(keys) do
        local name = util.normalize_server_name(sim[key])
        if name ~= "" then return name end
    end
    return ""
end

local function read_server_name(sim)
    local name = steam.server_name_from_race_ini()
    if name ~= "" then return name end

    name = read_sim_server_name(sim)
    if name ~= "" then return name end

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

function context.build_track_candidates(ctx)
    local seen, out = {}, {}
    local function push(track_id, layout_id)
        track_id = util.safe_str(track_id)
        layout_id = util.safe_str(layout_id)
        if track_id == "" then return end
        local key = string.lower(track_id) .. "|" .. string.lower(layout_id)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = { track_id = track_id, layout_id = layout_id }
    end

    local track_id = util.safe_str(ctx.track_id)
    local layout_id = util.safe_str(ctx.layout_id)
    local full_id = util.safe_str(ctx.track_full_id)

    push(track_id, layout_id)
    push(track_id, "")
    push(track_id, "default")
    if layout_id ~= "" and layout_id ~= "default" then
        push(track_id, layout_id:gsub("^layout_", ""))
    end

    local base, rest = util.split_track_and_layout(track_id, layout_id)
    if base ~= track_id or rest ~= layout_id then
        push(base, rest)
        push(base, "")
        push(base, "default")
    end

    if full_id ~= "" then
        local b, l = full_id:match("^([^|]+)|+(.+)$")
        if b ~= nil and l ~= nil then push(b, l); push(b, "") end
        b, l = full_id:match("^([^%-]+)%-(.+)$")
        if b ~= nil and l ~= nil then push(b, l); push(b, "") end
    end

    local lower_track = string.lower(track_id)
    if lower_track ~= track_id then
        push(lower_track, layout_id)
        push(lower_track, "")
    end

    if #out == 0 and track_id ~= "" then
        push(track_id, layout_id)
    end
    return out
end

function context.build_fetch_plans(ctx)
    local servers = context.build_server_name_candidates(ctx)
    local tracks = context.build_track_candidates(ctx)
    local plans = {}
    for _, server_name in ipairs(servers) do
        for _, track in ipairs(tracks) do
            plans[#plans + 1] = {
                server_name = server_name,
                track_id = track.track_id,
                layout_id = track.layout_id,
            }
        end
    end
    return plans
end

function context.build_server_name_candidates(ctx)
    local state = require("common.api.state")
    local seen, out = {}, {}
    local function push(name)
        name = util.normalize_server_name(name)
        if name == "" then return end
        local key = string.lower(name)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = name
    end

    push(state.server_override_storage:get())
    push(ctx.server_name)
    push(steam.server_name_from_race_ini())

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
