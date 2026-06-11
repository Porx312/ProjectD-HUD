--[[ Tamaños fijos — sin auto-scale (FIXED_SIZE en manifest) ]]

local layout = {}

layout.PAD_TOP10 = 4
layout.TOP10_PAD = 2
layout.TOP10_SELECT_H = 28
layout.TOP10_SELECT_GAP = 4
layout.TOP10_HEADER_H = layout.TOP10_SELECT_H + layout.TOP10_SELECT_GAP
layout.TOP10_ROW_COUNT = 10
layout.TOP10_ROW_SCALE = 1.5
--- Legacy aliases
layout.PAD_TOP5 = layout.PAD_TOP10
layout.TOP5_PAD = layout.TOP10_PAD
layout.TOP5_SELECT_H = layout.TOP10_SELECT_H
layout.TOP5_SELECT_GAP = layout.TOP10_SELECT_GAP
layout.TOP5_HEADER_H = layout.TOP10_HEADER_H
layout.TOP5_ROW_SCALE = layout.TOP10_ROW_SCALE
layout.ROW_H = 40
layout.CARD_EDGE_PAD = 4
layout.AVATAR_Y_EXTRA = 2

--- Overlay profile/rival: solo si existe assets/panel_overlay.png (u panel_gradient.png).

--- Overlay leaderboard: solo si existe assets/leaderboard_overlay.png.

--- leaderboard_panel.png — proporción real del asset vertical (1566×2720).
layout.LEADERBOARD_NATIVE = vec2(1566, 2720)
layout.LEADERBOARD_ASPECT = layout.LEADERBOARD_NATIVE.x / layout.LEADERBOARD_NATIVE.y

--- Cabecera del leaderboard (coords del canvas 1566×2720).
layout.LEADERBOARD_DESIGN = {
    header_h = 204,
    header_pad_x = 48,
    header_gap = 20,
    title = "Top 10",
    title_fs = 108,
    meta_fs = 92,
    logo_h = 128,
    sep_h = 2,
    sep_margin_x = 40,
    sep_margin_bottom = 14,
}

--- panel_card.png — proporción real del asset horizontal.
layout.PANEL_NATIVE = vec2(1795, 533.17)
layout.PANEL_ASPECT = layout.PANEL_NATIVE.x / layout.PANEL_NATIVE.y

--- Medidas profile/rival (canvas 1795×533) — no tocar al cambiar Top 5.
layout.PROFILE_DESIGN = {
    avatar = 465.7,
    name_fs = 188,
    sub_fs = 132,
    tier = 228,
    avatar_gap = 52,
    name_tier_gap = 38,
    line_gap = 32,
    rival_label_fs = 70,
}

function layout.panel_scale(panel_size)
    return panel_size.x / layout.PANEL_NATIVE.x
end

function layout.profile_metrics(panel_size)
    local s = layout.panel_scale(panel_size)
    local d = layout.PROFILE_DESIGN
    return {
        avatar = d.avatar * s,
        name_fs = d.name_fs * s,
        sub_fs = d.sub_fs * s,
        tier = d.tier * s,
        avatar_gap = d.avatar_gap * s,
        name_tier_gap = d.name_tier_gap * s,
        line_gap = d.line_gap * s,
        rival_label_fs = d.rival_label_fs * s,
    }
end

layout.SIZE = {
    top10   = vec2(300, 554),
    top5    = vec2(300, 554),
    profile = vec2(280, 84),
    rival   = vec2(280, 84),
}

--- Alias leaderboard row count.
layout.TOP8_ROW_COUNT = layout.TOP10_ROW_COUNT
layout.TOP5_ROW_COUNT = layout.TOP10_ROW_COUNT

--- Rect del panel profile dentro de la ventana.
function layout.panel_fit(win_size)
    local aspect = layout.PANEL_ASPECT
    local draw_w, draw_h

    if win_size.x / win_size.y > aspect then
        draw_h = win_size.y
        draw_w = draw_h * aspect
    else
        draw_w = win_size.x
        draw_h = draw_w / aspect
    end

    local ox = (win_size.x - draw_w) * 0.5
    local oy = (win_size.y - draw_h) * 0.5
    return vec2(ox, oy), vec2(draw_w, draw_h)
end

--- Rect del leaderboard dentro de la ventana (sin estirar el PNG).
function layout.leaderboard_fit(win_size)
    local aspect = layout.LEADERBOARD_ASPECT
    local draw_w, draw_h

    if win_size.x / win_size.y > aspect then
        draw_h = win_size.y
        draw_w = draw_h * aspect
    else
        draw_w = win_size.x
        draw_h = draw_w / aspect
    end

    local ox = (win_size.x - draw_w) * 0.5
    local oy = (win_size.y - draw_h) * 0.5
    return vec2(ox, oy), vec2(draw_w, draw_h)
end

function layout.leaderboard_scale(panel_size)
    return panel_size.x / layout.LEADERBOARD_NATIVE.x
end

function layout.leaderboard_header_metrics(panel_size)
    local s = layout.leaderboard_scale(panel_size)
    local d = layout.LEADERBOARD_DESIGN
    return {
        header_h = d.header_h * s,
        header_pad_x = d.header_pad_x * s,
        header_gap = d.header_gap * s,
        title = d.title,
        title_fs = d.title_fs * s,
        meta_fs = d.meta_fs * s,
        logo_h = d.logo_h * s,
        sep_h = math.max(1, d.sep_h * s),
        sep_margin_x = d.sep_margin_x * s,
        sep_margin_bottom = d.sep_margin_bottom * s,
    }
end

function layout.corners_all()
    return 15
end

--- Métricas Top 10: cabecera + listado dentro del panel.
function layout.top10_content(panel_size)
    local pad = layout.TOP10_PAD
    local rows = layout.TOP10_ROW_COUNT
    local header = layout.leaderboard_header_metrics(panel_size)
    local list_top = header.header_h + pad
    local list_h = panel_size.y - list_top - pad
    local row_h = list_h / rows
    local scale = layout.TOP10_ROW_SCALE
    local rh = row_h / 46

    local name_fs = math.min(17, math.max(12, math.floor(15 * scale * rh)))
    local sub_fs = math.min(14, math.max(11, math.floor(13 * scale * rh)))
    local time_fs = name_fs
    local name_gap = math.max(2, math.floor(3 * rh))
    local avatar = math.floor(row_h * 0.76)
    local tier = math.floor(row_h * 0.64)
    local rank_col = math.max(22, math.floor(24 * scale))
    local tier_gap = 6
    local time_gap = 6
    local trailing_pad = 8

    return {
        pad = pad,
        list_top = list_top,
        row_h = row_h,
        row_count = rows,
        header = header,
        content_width = panel_size.x - pad * 2,
        avatar = avatar,
        rank_col = rank_col,
        name_fs = name_fs,
        sub_fs = sub_fs,
        time_fs = time_fs,
        name_gap = name_gap,
        tier = tier,
        tier_gap = tier_gap,
        time_gap = time_gap,
        trailing_pad = trailing_pad,
    }
end

layout.top5_content = layout.top10_content

return layout
