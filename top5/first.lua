--[[ ProjectD — Top 5 del servidor (template, datos falsos) ]]

local theme = require("common.theme")
local layout = require("common.layout")
local mock = require("common.mock_data")
local draw = require("common.draw")
local images = require("common.images")

local mod = {}

local RANK_COL = 22

function mod.init()
    images.init()
    mod.prefetch_avatars()
end

function mod.prefetch_avatars()
    local top5 = mock.get_top5()
    for i = 0, 4 do
        local e = top5[i]
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
    local pad = layout.PAD_TOP5

    draw.flat_panel(vec2(0, 0), win)

    local ctx = mock.get_context()
    ui.pushDWriteFont(theme.fonts.small)
    ui.dwriteDrawText(
        string.format("TOP 5 · %s · %s/%s", ctx.server_id, ctx.track_id, ctx.layout_id),
        10,
        vec2(pad, pad),
        theme.colors.muted
    )
    ui.popDWriteFont()

    local top5 = mock.get_top5()
    local y = pad + 16

    for i = 0, 4 do
        local entry = top5[i]
        if entry == nil then break end

        local rank_color = theme.colors.white
        if entry.rank == 1 then rank_color = theme.colors.accent end

        draw.driver_row(vec2(pad, y), entry, {
            draw_rank_number = true,
            rank_color = rank_color,
            row_height = layout.ROW_H,
            rank_col_width = RANK_COL,
        })

        y = y + layout.ROW_H
    end

    if top5[0] == nil then
        ui.pushDWriteFont(theme.fonts.reg)
        ui.dwriteDrawText("No data", 14, vec2(pad + 4, pad + 28), theme.colors.muted)
        ui.popDWriteFont()
    end
end

return mod
