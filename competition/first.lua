--[[ ProjectD — Competition ladder: rival above · you · rival below ]]

local theme = require("common.theme")
local layout = require("common.layout")
local data = require("common.data")
local state = require("common.api.state")
local draw = require("common.draw")
local images = require("common.images")
local mod = {}

local CAR_FILTER = "global"
local avatars_prefetched_for = ""

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
end

function mod.on_open() end
function mod.on_close() end
function mod.update() end

function mod.main(dt)
    theme.ensure_fonts()
    local win = ui.windowSize()
    local po, ps = draw.competition_panel(vec2(0, 0), win)
    local panel_o = po
    local content = layout.competition_content(ps)

    local pad = content.pad
    local ladder = data.get_competition_ladder(CAR_FILTER)

    if data.is_account_restricted ~= nil and data.is_account_restricted() then
        draw.center_status_message(panel_o, ps, "Account restricted")
        return
    end

    local center = ladder ~= nil and ladder.slots[1] or nil
    local prefetch_key = tostring(state.session_seq or 0) .. "|"
        .. (center ~= nil
        and (tostring(center.name) .. "|" .. tostring(center.avatar_url or ""))
        or "")
    if center ~= nil and avatars_prefetched_for ~= prefetch_key then
        avatars_prefetched_for = prefetch_key
        mod.prefetch_avatars(ladder)
    end

    local y = panel_o.y + content.list_top

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

    local row_x = panel_o.x + pad
    for i = 0, layout.COMPETITION_ROW_COUNT - 1 do
        local entry = ladder.slots[i]
        local row_h = content.row_heights[i] or content.side_row_h

        if entry ~= nil then
            local row_opts = layout.competition_row_opts(content)
            row_opts.row_id = "comp_" .. tostring(i) .. "_" .. tostring(entry.rank)
            draw.competition_row(vec2(row_x, y), entry, row_opts)
        end

        y = y + row_h + (content.row_gap or 0)
    end
end

return mod
