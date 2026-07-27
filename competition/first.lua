--[[ ProjectD — Competition ladder: rival above · you · rival below ]]

local theme = require("common.theme")
local layout = require("common.layout")
local data = require("common.data")
local state = require("common.api.state")
local draw = require("common.draw")
local images = require("common.images")
local competition_anim = require("common.competition_anim")
local mod = {}

local CAR_FILTER = "global"
local avatars_prefetched_for = ""

local function ladder_prefetch_key(ladder)
    if ladder == nil or ladder.slots == nil then return "" end
    local parts = { tostring(state.session_seq or 0) }
    for i = 0, layout.COMPETITION_ROW_COUNT - 1 do
        local e = ladder.slots[i]
        if e ~= nil then
            parts[#parts + 1] = tostring(i)
                .. ":" .. tostring(e.rank or 0)
                .. ":" .. tostring(e.lap_ms or e.best_lap_ms or 0)
                .. ":" .. tostring(e.name or "")
                .. ":" .. tostring(e.avatar_url or "")
        end
    end
    return table.concat(parts, "|")
end

function mod.init()
    images.init()
end

function mod.prefetch_avatars(ladder)
    if ladder == nil or ladder.slots == nil then return end
    for i = 0, layout.COMPETITION_ROW_COUNT - 1 do
        local e = ladder.slots[i]
        if e ~= nil then
            images.prefetch_avatar(e.name, e.avatar_url)
        end
    end
end

function mod.on_session_start()
    avatars_prefetched_for = ""
    competition_anim.reset()
end

function mod.on_open() end
function mod.on_close() end
function mod.update() end

function mod.main(dt)
    theme.ensure_fonts()
    if data.tick ~= nil then
        data.tick(CAR_FILTER)
    end

    local win = ui.windowSize()
    local po, ps = draw.competition_panel(vec2(0, 0), win)
    local panel_o = po
    local content = layout.competition_content(ps)

    local ladder = data.get_competition_ladder(CAR_FILTER)

    if data.is_account_restricted ~= nil and data.is_account_restricted() then
        draw.center_status_message(panel_o, ps, "Account restricted")
        return
    end

    local prefetch_key = ladder_prefetch_key(ladder)
    if ladder ~= nil and ladder.slots[1] ~= nil and avatars_prefetched_for ~= prefetch_key then
        avatars_prefetched_for = prefetch_key
        mod.prefetch_avatars(ladder)
    end

    if ladder == nil or ladder.slots[1] == nil then
        local msg = "No profile data"
        if data.is_loading ~= nil and data.is_loading() then
            msg = "Loading..."
        elseif data.get_status_message ~= nil then
            local custom = data.get_status_message("competition")
            if custom ~= nil then msg = custom end
        end
        draw.center_status_message(panel_o, ps, msg, { color = theme.colors.muted, fs = content.name_fs * 1.1 })
        return
    end

    competition_anim.tick(dt, ladder, content)
    local anim_state = competition_anim.get_draw_state(content)
    draw.competition_ladder(panel_o, ps, content, ladder, anim_state)
end

return mod
