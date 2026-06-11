--[[ ProjectD — Top 10 del servidor (template, datos falsos) ]]

local theme = require("common.theme")
local layout = require("common.layout")
local data = require("common.data")
local draw = require("common.draw")
local images = require("common.images")
local hud_debug = require("common.hud_debug")

local mod = {}

local selected_filter = "global"
local filter_storage = ac.storage("ProjectD-HUD:top5_filter", "global")
local avatars_prefetched_for = ""

local function normalize_filter(id)
    if id == nil or id == "" then return "global" end
    for _, tab in ipairs(data.get_leaderboard_filters()) do
        if tab.id == id then return id end
    end
    return "global"
end

function mod.init()
    images.init()
    selected_filter = normalize_filter(filter_storage:get())
end

function mod.prefetch_avatars()
    local rows = data.get_top10(selected_filter)
    for i = 0, layout.TOP10_ROW_COUNT - 1 do
        local e = rows[i]
        if e ~= nil then
            images.request_avatar(images.resolve_url(e.name, e.avatar_url))
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
    local filters = data.get_leaderboard_filters()
    local side_pad = layout.TOP5_PAD

    local picked = draw.car_filter_combo(
        vec2(side_pad, 0),
        win.x - side_pad * 2,
        filters,
        selected_filter
    )

    if picked ~= nil and picked ~= selected_filter then
        selected_filter = picked
        filter_storage:set(selected_filter)
        if data.fetch_session ~= nil then data.fetch_session(selected_filter, true) end
        mod.prefetch_avatars()
    end

    local panel_origin = vec2(0, layout.TOP5_HEADER_H)
    local panel_size = vec2(win.x, win.y - layout.TOP5_HEADER_H)
    local po, ps = draw.leaderboard_panel(panel_origin, panel_size)
    local panel_o = panel_origin + po

    draw.leaderboard_header(panel_o, ps, data.get_leaderboard_header())

    local content = layout.top5_content(ps)
    local pad = content.pad
    local rows = data.get_top10(selected_filter)
    local row_count = content.row_count or layout.TOP10_ROW_COUNT

    local y = panel_o.y + content.list_top
    local prefetch_key = selected_filter .. ":" .. tostring(rows[0] ~= nil)
    if rows[0] ~= nil and avatars_prefetched_for ~= prefetch_key then
        avatars_prefetched_for = prefetch_key
        mod.prefetch_avatars()
    end

    for i = 0, row_count - 1 do
        local entry = rows[i]
        if entry == nil then break end

        local rank_color = theme.colors.white
        if entry.rank == 1 then rank_color = theme.colors.accent end

        draw.driver_row(vec2(panel_o.x + pad, y), entry, {
            draw_rank_number = true,
            show_rank_on_car = false,
            time_on_name_line = true,
            rank_color = rank_color,
            row_height = content.row_h,
            rank_col_width = content.rank_col,
            content_width = content.content_width,
            avatar_size = content.avatar,
            tier_size = content.tier,
            name_fs = content.name_fs,
            sub_fs = content.sub_fs,
            time_fs = content.time_fs,
            name_gap = content.name_gap,
            tier_gap = content.tier_gap,
            time_gap = content.time_gap,
            trailing_pad = content.trailing_pad,
        })

        y = y + content.row_h
    end

    if rows[0] == nil then
        ui.pushDWriteFont(theme.fonts.reg)
        local msg = "No data"
        if data.get_status_message ~= nil then
            local custom = data.get_status_message("leaderboard")
            if custom ~= nil then msg = custom end
        end
        ui.dwriteDrawText(
            msg, content.name_fs,
            vec2(panel_o.x + pad + 2, panel_o.y + content.list_top + 2),
            theme.colors.muted
        )
        ui.popDWriteFont()
    end

    hud_debug.draw(data, win, { max_lines = 16, font_size = 9 })
end

return mod
