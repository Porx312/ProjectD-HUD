--[[ Draw — leaderboard (legacy Top 10) ]]

local theme = require("common.theme")
local images = require("common.images")
local layout = require("common.layout")
local shared = require("common.draw.shared")

local M = {}

function M.leaderboard_panel(win_origin, win_size)
    local po, ps = layout.leaderboard_fit(win_size)
    local origin = win_origin + po
    local br = origin + ps
    local bg = images.get_leaderboard_panel()

    if bg ~= nil then
        ui.drawImage(bg, origin, br, theme.colors.bg_card)
    else
        ui.drawRectFilled(origin, br, theme.colors.bg_card, 8, layout.corners_all())
        ui.drawRect(origin, br, theme.colors.panel_border, 8, layout.corners_all(), 1)
    end

    local overlay = images.get_leaderboard_panel_overlay()
    if overlay ~= nil then
        ui.drawImage(overlay, origin, br, theme.colors.leaderboard_overlay)
    end

    return po, ps
end

function M.leaderboard_header(panel_o, panel_size, info)
    theme.ensure_fonts()
    info = info or {}
    local m = layout.leaderboard_header_metrics(panel_size)
    local title = info.title or m.title

    local function text_w(font, text, fs)
        ui.pushDWriteFont(font)
        local w = shared.measure_text(font, text, fs)
        ui.popDWriteFont()
        return w
    end

    local title_fs = m.title_fs
    local title_w = text_w(theme.fonts.bold, title, title_fs)
    local start_x = panel_o.x + (panel_size.x - title_w) * 0.5
    local content_h = m.header_h - m.sep_margin_bottom - m.sep_h
    local row_y = panel_o.y + (content_h - title_fs) * 0.5
    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(title, title_fs, vec2(start_x, row_y), theme.colors.white)
    ui.popDWriteFont()

    local sep_y = panel_o.y + m.header_h - m.sep_h
    local sep_l = panel_o.x + m.sep_margin_x
    local sep_r = panel_o.x + panel_size.x - m.sep_margin_x
    ui.drawLine(vec2(sep_l, sep_y), vec2(sep_r, sep_y), theme.colors.leaderboard_sep, m.sep_h)
end

return M
