--[[ ProjectD — Top 10 del servidor (template, datos falsos) ]]

local theme = require("common.theme")
local layout = require("common.layout")
local mock = require("common.mock_data")
local draw = require("common.draw")
local images = require("common.images")

local mod = {}

local selected_filter = "global"
local filter_storage = ac.storage("ProjectD-HUD:top5_filter", "global")

local function normalize_filter(id)
    if id == nil or id == "" then return "global" end
    for _, tab in ipairs(mock.get_leaderboard_filters()) do
        if tab.id == id then return id end
    end
    return "global"
end

function mod.init()
    images.init()
    selected_filter = normalize_filter(filter_storage:get())
    mod.prefetch_avatars()
end

function mod.prefetch_avatars()
    local rows = mock.get_top10(selected_filter)
    for i = 0, layout.TOP10_ROW_COUNT - 1 do
        local e = rows[i]
        if e ~= nil then
            images.request_avatar(images.resolve_url(e.name, e.avatar_url))
        end
    end
end

function mod.on_session_start()
    mod.prefetch_avatars()
end

function mod.on_open() end
function mod.on_close() end
function mod.update() end

function mod.main(dt)
    theme.ensure_fonts()
    local win = ui.windowSize()
    local filters = mock.get_leaderboard_filters()
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
        mod.prefetch_avatars()
    end

    local panel_origin = vec2(0, layout.TOP5_HEADER_H)
    local panel_size = vec2(win.x, win.y - layout.TOP5_HEADER_H)
    local po, ps = draw.leaderboard_panel(panel_origin, panel_size)
    local panel_o = panel_origin + po

    draw.leaderboard_header(panel_o, ps, mock.get_leaderboard_header())

    local content = layout.top5_content(ps)
    local pad = content.pad
    local rows = mock.get_top10(selected_filter)
    local row_count = content.row_count or layout.TOP10_ROW_COUNT

    local y = panel_o.y + content.list_top
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
        ui.dwriteDrawText(
            "No data", content.name_fs,
            vec2(panel_o.x + pad + 2, panel_o.y + content.list_top + 2),
            theme.colors.muted
        )
        ui.popDWriteFont()
    end
end

return mod
