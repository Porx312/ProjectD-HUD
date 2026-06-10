--[[ Componentes visuales — tamaños fijos px ]]

local theme = require("common.theme")
local images = require("common.images")
local layout = require("common.layout")

local draw = {}

-- Top 5
local AVATAR_ROW = 36
local TIER_ROW = 20
local RANK_COL = 22

local function measure_text(font, text, size)
    ui.pushDWriteFont(font)
    local w = ui.measureDWriteText(text, size).x
    ui.popDWriteFont()
    return w
end

function draw.flat_panel(origin, size)
    ui.drawRectFilled(origin, origin + size, theme.colors.bg, 6, layout.corners_all())
end

--- Panel profile/rival: PNG sin estirar (proporción 1795×533), centrado en ventana.
function draw.cmrt_panel(win_origin, win_size)
    local po, ps = layout.panel_fit(win_size)
    local origin = win_origin + po
    local br = origin + ps
    local bg = images.get_card_panel()
    if bg ~= nil then
        ui.drawImage(bg, origin, br, theme.colors.bg_card)
        return po, ps
    end
    local radius = math.min(10, ps.y * 0.5 - 0.5)
    ui.drawRectFilled(origin, br, theme.colors.bg_card, radius, layout.corners_all())
    ui.drawRect(origin, br, theme.colors.panel_border, radius, layout.corners_all(), 1)
    return po, ps
end

function draw.avatar_circle(pos, url, size)
    theme.ensure_fonts()
    local center = pos + vec2(size / 2, size / 2)
    local radius = size / 2
    local br = pos + vec2(size, size)
    local corners = images.corners_all()
    local segs = math.max(32, math.floor(size * 0.5))

    ui.drawCircleFilled(center, radius, theme.colors.avatar_fill, segs)

    local tex = images.get_avatar(url)
    if tex ~= nil then
        local uv1, uv2 = images.cover_uv(tex)
        ui.drawImageRounded(tex, pos, br, theme.colors.white, uv1, uv2, radius, corners)
    else
        local initial = url ~= nil and "…" or "?"
        local fs = math.max(11, size * 0.28)
        ui.pushDWriteFont(theme.fonts.bold)
        local tw = measure_text(theme.fonts.bold, initial, fs)
        ui.dwriteDrawText(initial, fs, center - vec2(tw / 2, fs * 0.52), theme.colors.muted)
        ui.popDWriteFont()
    end

    ui.drawCircle(center, radius, theme.colors.avatar_ring, segs, math.max(1, size * 0.022))
end

function draw.tier_badge(pos, tier, tier_sz)
    theme.ensure_fonts()
    local path = images.get_tier_path(tier)

    if path ~= nil then
        ui.drawImage(path, pos, pos + vec2(tier_sz, tier_sz))
        return
    end

    local center = pos + vec2(tier_sz / 2, tier_sz / 2)
    ui.drawCircleFilled(center, tier_sz / 2, theme.colors.tier_fallback, 16)
    ui.drawCircle(center, tier_sz / 2, theme.colors.white, 16, 1)

    local label = tostring(tier)
    ui.pushDWriteFont(theme.fonts.bold)
    local tw = measure_text(theme.fonts.bold, label, 11)
    ui.dwriteDrawText(label, 11, pos + vec2((tier_sz - tw) / 2, (tier_sz - 11) / 2), theme.colors.white)
    ui.popDWriteFont()
end

--- Fila top 5: # | avatar | nombre | tier — tier alineado al nombre.
function draw.driver_row(origin, entry, opts)
    theme.ensure_fonts()
    opts = opts or {}

    local row_h = opts.row_height or layout.ROW_H
    local rank_col = opts.rank_col_width or RANK_COL
    local rank_color = opts.rank_color or theme.colors.white
    local name_fs = 15
    local sub_fs = 13
    local name_gap = 6

    local block_h = math.max(AVATAR_ROW, name_fs + name_gap + sub_fs)
    local y0 = origin.y + (row_h - block_h) * 0.5

    if opts.draw_rank_number then
        ui.pushDWriteFont(theme.fonts.bold)
        ui.dwriteDrawText("#" .. tostring(entry.rank), 15, vec2(origin.x, y0 + (name_fs - 15) * 0.5 + 1), rank_color)
        ui.popDWriteFont()
    end

    local avatar_x = origin.x + rank_col
    draw.avatar_circle(vec2(avatar_x, y0 + (block_h - AVATAR_ROW) * 0.5), images.resolve_url(entry.name, entry.avatar_url), AVATAR_ROW)

    local name_x = avatar_x + AVATAR_ROW + 8
    local name_y = y0
    local name_text = theme.format_display_name(entry.name)

    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(name_text, name_fs, vec2(name_x, name_y), theme.colors.white)
    ui.popDWriteFont()

    local name_w = measure_text(theme.fonts.bold, name_text, name_fs)
    local tier_x = name_x + name_w + 6
    local tier_y = name_y + (name_fs - TIER_ROW) * 0.5
    draw.tier_badge(vec2(tier_x, tier_y), entry.tier, TIER_ROW)

    local car = entry.car_name or "Car"
    local car_prefix = "#" .. tostring(entry.rank) .. " " .. car
    local time_str = theme.format_lap(entry.lap_ms or entry.best_lap_ms)
    local sub_y = name_y + name_fs + name_gap

    ui.pushDWriteFont(theme.fonts.reg)
    ui.dwriteDrawText(car_prefix .. " - ", sub_fs, vec2(name_x, sub_y), theme.colors.white)
    local prefix_w = measure_text(theme.fonts.reg, car_prefix .. " - ", sub_fs)
    ui.dwriteDrawText(time_str, sub_fs, vec2(name_x + prefix_w, sub_y), theme.colors.accent)
    ui.popDWriteFont()
end

local function profile_name_text(entry)
    return theme.format_display_name(entry.display_name or entry.name)
end

local function car_line_prefix(entry, opts)
    local car = entry.car_name or "Car"
    if opts.show_rank_on_car ~= false and entry.rank ~= nil then
        return "#" .. tostring(entry.rank) .. " " .. car
    end
    return car
end

local function draw_rival_tag(avatar_pos, avatar_size, fs)
    theme.ensure_fonts()
    local label = "rival"
    ui.pushDWriteFont(theme.fonts.bold)
    local tw = measure_text(theme.fonts.bold, label, fs)
    ui.popDWriteFont()

    local pad = layout.CARD_EDGE_PAD
    local pos = vec2(avatar_pos.x + pad, avatar_pos.y + pad)
    local br = pos + vec2(tw + pad * 2, fs + pad * 1.2)
    ui.drawRectFilled(pos, br, theme.colors.rival_tag, math.min(3, pad + 1), layout.corners_all())

    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(label, fs, pos + vec2(pad, pad * 0.35), theme.colors.white)
    ui.popDWriteFont()
end

local function profile_metrics_from_opts(opts)
    if opts.metrics ~= nil then return opts.metrics end
    local panel_size = opts.panel_size or layout.SIZE.profile
    return layout.profile_metrics(panel_size)
end

local function measure_text_column(entry, opts, m)
    local name_text = profile_name_text(entry)
    local car_prefix = car_line_prefix(entry, opts)
    local time_str = theme.format_lap(entry.best_lap_ms or entry.lap_ms)

    local name_w = measure_text(theme.fonts.bold, name_text, m.name_fs)
    local name_row_w = name_w + m.name_tier_gap + m.tier
    local sub_w = measure_text(theme.fonts.reg, car_prefix .. " - " .. time_str, m.sub_fs)
    local text_w = math.max(name_row_w, sub_w)
    local text_h = m.name_fs + m.line_gap + m.sub_fs

    return text_w, text_h, name_text, car_prefix, time_str
end

function draw.profile_card(panel_o, panel_size, entry, opts)
    theme.ensure_fonts()
    opts = opts or {}
    local m = profile_metrics_from_opts(opts)
    local url = images.resolve_url(entry.name, entry.avatar_url)
    local pad = layout.CARD_EDGE_PAD

    local text_w, text_h, name_text, car_prefix, time_str =
        measure_text_column(entry, opts, m)

    local avatar_pos = vec2(panel_o.x + pad, panel_o.y + pad + layout.AVATAR_Y_EXTRA)
    local tx = panel_o.x + pad + m.avatar + m.avatar_gap
    local text_y = panel_o.y + (panel_size.y - text_h) * 0.5

    draw.avatar_circle(avatar_pos, url, m.avatar)

    if opts.rival_tag then
        draw_rival_tag(avatar_pos, m.avatar, m.rival_label_fs)
    end

    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(name_text, m.name_fs, vec2(tx, text_y), theme.colors.white)
    ui.popDWriteFont()

    local nw = measure_text(theme.fonts.bold, name_text, m.name_fs)
    local tier_y = text_y + (m.name_fs - m.tier) * 0.5
    draw.tier_badge(vec2(tx + nw + m.name_tier_gap, tier_y), entry.tier, m.tier)

    local sub_y = text_y + m.name_fs + m.line_gap

    ui.pushDWriteFont(theme.fonts.reg)
    ui.dwriteDrawText(car_prefix .. " - ", m.sub_fs, vec2(tx, sub_y), theme.colors.white)
    local pw = measure_text(theme.fonts.reg, car_prefix .. " - ", m.sub_fs)
    ui.dwriteDrawText(time_str, m.sub_fs, vec2(tx + pw, sub_y), theme.colors.accent)
    ui.popDWriteFont()
end

function draw.rival_block(win_origin, win_size, rival)
    draw.profile_block(win_origin, win_size, rival, { rival_tag = true })
end

function draw.profile_block(win_origin, win_size, entry, extra)
    extra = extra or {}
    local po, ps = layout.panel_fit(win_size)
    local panel_o = win_origin + po
    local opts = {
        show_rank_on_car = true,
        metrics = layout.profile_metrics(ps),
        rival_tag = extra.rival_tag == true,
    }
    draw.profile_card(panel_o, ps, entry, opts)
end

return draw
