--[[ Profile widget — stale display + highlight only tier / rank / lap changes ]]

local profile_mod = require("common.api.profile")
local state = require("common.api.state")
local util = require("common.api.util")

local display = {}

local HIGHLIGHT_SEC = 1.2

local last_good = nil
local stable = nil
local highlights = { tier = 0, rank = 0, time = 0 }

local function lap_ms(entry)
    if entry == nil then return 0 end
    return tonumber(entry.lap_ms or entry.last_lap_ms or entry.best_lap_ms) or 0
end

local function snapshot(entry)
    if entry == nil then return nil end
    return {
        name = entry.name,
        display_name = entry.display_name,
        avatar_url = entry.avatar_url,
        car_name = entry.car_name,
        car_id = entry.car_id,
        tier = profile_mod.tier_for_display(entry),
        rank = tonumber(entry.rank) or 0,
        lap_ms = lap_ms(entry),
    }
end

local function decay_highlights(dt)
    local step = (dt or 0) / HIGHLIGHT_SEC
    for key, alpha in pairs(highlights) do
        if alpha > 0 then
            highlights[key] = math.max(0, alpha - step)
        end
    end
end

local function mark_changes(prev, next)
    if prev == nil or next == nil then return end
    if prev.tier ~= next.tier then highlights.tier = 1 end
    if prev.rank ~= next.rank then highlights.rank = 1 end
    if prev.lap_ms ~= next.lap_ms then highlights.time = 1 end
end

function display.reset()
    last_good = nil
    stable = nil
    highlights.tier = 0
    highlights.rank = 0
    highlights.time = 0
end

function display.resolve_profile(get_profile_fn, is_restricted_fn)
    local p = get_profile_fn()
    if p ~= nil then
        last_good = p
        return p
    end
    if is_restricted_fn ~= nil and is_restricted_fn() then
        return nil
    end
    if state.cached_bundle == nil then
        return nil
    end
    local wait_reason = util.safe_str(state.hud_waiting_reason)
    if wait_reason ~= "" then
        return nil
    end
    if state.last_error ~= nil and state.last_error ~= "" and not util.should_ignore_error(state.last_error) then
        return nil
    end
    return last_good
end

function display.tick(dt, entry)
    decay_highlights(dt)
    if entry == nil then return end

    local snap = snapshot(entry)
    if stable == nil then
        stable = snap
        return
    end

    mark_changes(stable, snap)
    stable = snap
end

function display.get_highlights()
    return highlights
end

function display.avatar_prefetch_key(entry)
    if entry == nil then return "" end
    return tostring(entry.name or "") .. "|" .. tostring(entry.avatar_url or "")
end

return display
