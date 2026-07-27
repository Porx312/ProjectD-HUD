--[[ Competition ladder — FLIP reorder by entity name (Y-only, no alpha) ]]

local layout = require("common.layout")

local anim = {}

local stable_ladder = nil

local active = false
local elapsed = 0
local duration = 0.9
local player_direction = nil
local flip_items = nil
local content_ref = nil

local function ease_out_cubic(t)
    t = math.max(0, math.min(1, t))
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function ladder_rank(ladder)
    if ladder == nil then return 0 end
    local rank = tonumber(ladder.player_rank)
    if rank ~= nil and rank > 0 then return rank end
    local center = ladder.slots and ladder.slots[1]
    if center ~= nil then
        return tonumber(center.rank) or 0
    end
    return 0
end

local function snapshot_entry(e)
    if e == nil then return nil end
    return {
        rank = e.rank,
        name = e.name,
        display_name = e.display_name,
        tier = e.tier,
        lap_ms = e.lap_ms,
        best_lap_ms = e.best_lap_ms,
        car_name = e.car_name,
        car_id = e.car_id,
        avatar_url = e.avatar_url,
        elo = e.elo,
        is_self = e.is_self,
    }
end

local function snapshot_ladder(ladder)
    if ladder == nil then return nil end
    local slots = {}
    if ladder.slots ~= nil then
        for i = 0, 2 do
            slots[i] = snapshot_entry(ladder.slots[i])
        end
    end
    return {
        slots = slots,
        player_rank = ladder.player_rank,
        profile = ladder.profile,
    }
end

local function entry_name(entry)
    if entry == nil then return nil end
    return entry.name
end

local function player_rank_delta(old, new)
    local old_r = ladder_rank(old)
    local new_r = ladder_rank(new)
    if old_r <= 0 or new_r <= 0 or old_r == new_r then return nil end
    return new_r < old_r and "up" or "down"
end

local function offscreen_y(content, side)
    if side == "top" then
        return -content.row_step
    end
    return content.block_h + content.row_gap
end

local function enter_side_for_slot(slot)
    if slot == 0 then return "top" end
    return "bottom"
end

local function exit_side_for_slot(slot)
    if slot == 0 then return "top" end
    return "bottom"
end

local function should_animate(old_ladder, new_ladder)
    if player_rank_delta(old_ladder, new_ladder) ~= nil then return true end
    for i = 0, 2 do
        if entry_name(old_ladder.slots[i]) ~= entry_name(new_ladder.slots[i]) then
            return true
        end
    end
    return false
end

local function duration_for_change(old_ladder, new_ladder)
    if player_rank_delta(old_ladder, new_ladder) ~= nil then
        return layout.COMPETITION_FLIP_SEC or 0.9
    end
    return layout.COMPETITION_FLIP_SEC_RIVAL or 0.55
end

local function build_flip_items(old, new, content)
    local names = {}
    local old_by_name = {}
    local new_by_name = {}

    for i = 0, 2 do
        local oe = old.slots[i]
        if oe ~= nil and oe.name ~= nil then
            old_by_name[oe.name] = { slot = i, entry = snapshot_entry(oe) }
            names[oe.name] = true
        end
        local ne = new.slots[i]
        if ne ~= nil and ne.name ~= nil then
            new_by_name[ne.name] = { slot = i, entry = snapshot_entry(ne) }
            names[ne.name] = true
        end
    end

    local items = {}
    for name, _ in pairs(names) do
        local old_info = old_by_name[name]
        local new_info = new_by_name[name]
        local from_slot = old_info and old_info.slot or nil
        local to_slot = new_info and new_info.slot or nil

        local from_y
        if from_slot ~= nil then
            from_y = layout.competition_slot_y(content, from_slot)
        else
            from_y = offscreen_y(content, enter_side_for_slot(to_slot))
        end

        local to_y
        if to_slot ~= nil then
            to_y = layout.competition_slot_y(content, to_slot)
        else
            to_y = offscreen_y(content, exit_side_for_slot(from_slot))
        end

        local entry = (new_info and new_info.entry) or old_info.entry
        items[#items + 1] = {
            key = name,
            entry = entry,
            from_y = from_y,
            to_y = to_y,
            is_self = entry.is_self == true,
            slot = to_slot or from_slot or 1,
        }
    end

    table.sort(items, function(a, b) return a.key < b.key end)
    return items
end

local function start_flip(old, new, content)
    content_ref = content
    flip_items = build_flip_items(old, new, content)
    player_direction = player_rank_delta(old, new)
    duration = duration_for_change(old, new)
    active = true
    elapsed = 0
end

function anim.reset()
    stable_ladder = nil
    active = false
    elapsed = 0
    player_direction = nil
    flip_items = nil
    content_ref = nil
end

function anim.tick(dt, ladder, content)
    if ladder == nil or ladder.slots == nil or ladder.slots[1] == nil then
        return
    end

    if content == nil then return end

    local snap = snapshot_ladder(ladder)

    if active then
        elapsed = elapsed + (dt or 0)
        if elapsed >= duration then
            active = false
            player_direction = nil
            flip_items = nil
            content_ref = nil
            stable_ladder = snap
        end
        return
    end

    if stable_ladder == nil then
        stable_ladder = snap
        return
    end

    if should_animate(stable_ladder, snap) then
        start_flip(stable_ladder, snap, content)
        return
    end

    stable_ladder = snap
end

function anim.get_draw_state(content)
    if not active or flip_items == nil then
        return nil
    end

    local c = content_ref or content
    if c == nil then return nil end

    local t = ease_out_cubic(elapsed / duration)
    local items = {}
    for _, item in ipairs(flip_items) do
        items[#items + 1] = {
            key = item.key,
            entry = item.entry,
            y = item.from_y + (item.to_y - item.from_y) * t,
            is_self = item.is_self,
            slot = item.slot,
        }
    end

    return {
        mode = "flip_reorder",
        progress = t,
        items = items,
        player_direction = player_direction,
    }
end

function anim.is_active()
    return active
end

return anim
