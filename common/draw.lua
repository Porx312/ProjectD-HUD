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

local function measure_dwrite(font, text, size)
    ui.pushDWriteFont(font)
    local sz = ui.measureDWriteText(text, size)
    ui.popDWriteFont()
    return sz
end

function draw.flat_panel(origin, size)
    ui.drawRectFilled(origin, origin + size, theme.colors.bg, 6, layout.corners_all())
end

--- Panel Top 5: leaderboard_panel + overlay propio (opcional). Devuelve offset y tamaño del panel.
function draw.leaderboard_panel(win_origin, win_size)
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

--- Cabecera: "Top 10 Map - Layout - logo" + línea separadora.
function draw.leaderboard_header(panel_o, panel_size, info)
    theme.ensure_fonts()
    info = info or {}
    local m = layout.leaderboard_header_metrics(panel_size)
    local title = info.title or m.title
    local map_label = info.map or ""
    local layout_label = info.layout or ""
    local sep = " - "
    local logo_path = images.get_logo()
    local logo_w = m.logo_h

    if logo_path ~= nil then
        local ok, sz = pcall(ui.imageSize, logo_path)
        if ok and sz ~= nil and sz.y > 0 then
            logo_w = m.logo_h * (sz.x / sz.y)
        end
    end

    local function text_w(font, text, fs)
        ui.pushDWriteFont(font)
        local w = measure_text(font, text, fs)
        ui.popDWriteFont()
        return w
    end

    local title_fs = m.title_fs
    local meta_fs = m.meta_fs
    local sep_fs = meta_fs * 0.82

    local title_w = text_w(theme.fonts.bold, title, title_fs)
    local map_w = map_label ~= "" and text_w(theme.fonts.bold, map_label, meta_fs) or 0
    local layout_w = layout_label ~= "" and text_w(theme.fonts.reg, layout_label, meta_fs) or 0
    local sep_w = text_w(theme.fonts.reg, sep, sep_fs)

    local group_w = title_w
    if map_label ~= "" then
        group_w = group_w + m.header_gap + map_w
    end
    if layout_label ~= "" then
        group_w = group_w + sep_w + layout_w
    end
    if logo_path ~= nil then
        group_w = group_w + sep_w + logo_w
    end

    local max_w = panel_size.x - m.header_pad_x * 2
    if group_w > max_w and group_w > 0 then
        local shrink = max_w / group_w
        title_fs = title_fs * shrink
        meta_fs = meta_fs * shrink
        sep_fs = sep_fs * shrink
        logo_w = logo_w * shrink
        m.logo_h = m.logo_h * shrink

        title_w = text_w(theme.fonts.bold, title, title_fs)
        map_w = map_label ~= "" and text_w(theme.fonts.bold, map_label, meta_fs) or 0
        layout_w = layout_label ~= "" and text_w(theme.fonts.reg, layout_label, meta_fs) or 0
        sep_w = text_w(theme.fonts.reg, sep, sep_fs)

        group_w = title_w
        if map_label ~= "" then group_w = group_w + m.header_gap + map_w end
        if layout_label ~= "" then group_w = group_w + sep_w + layout_w end
        if logo_path ~= nil then group_w = group_w + sep_w + logo_w end
    end

    local start_x = panel_o.x + (panel_size.x - group_w) * 0.5
    local content_h = m.header_h - m.sep_margin_bottom - m.sep_h
    local row_y = panel_o.y + (content_h - m.logo_h) * 0.5
    local x = start_x

    local function draw_text(font, text, fs, color)
        local y = row_y + (m.logo_h - fs) * 0.5
        ui.pushDWriteFont(font)
        ui.dwriteDrawText(text, fs, vec2(x, y), color)
        ui.popDWriteFont()
        x = x + text_w(font, text, fs)
    end

    draw_text(theme.fonts.bold, title, title_fs, theme.colors.white)

    if map_label ~= "" then
        x = x + m.header_gap
        draw_text(theme.fonts.bold, map_label, meta_fs, theme.colors.accent)
    end

    if layout_label ~= "" then
        draw_text(theme.fonts.reg, sep, sep_fs, theme.colors.muted)
        draw_text(theme.fonts.reg, layout_label, meta_fs, theme.colors.white)
    end

    if logo_path ~= nil then
        draw_text(theme.fonts.reg, sep, sep_fs, theme.colors.muted)
        local logo_y = row_y + (m.logo_h - m.logo_h) * 0.5
        ui.drawImage(logo_path, vec2(x, row_y), vec2(x + logo_w, row_y + m.logo_h), theme.colors.white)
    end

    local sep_y = panel_o.y + m.header_h - m.sep_h
    local sep_l = panel_o.x + m.sep_margin_x
    local sep_r = panel_o.x + panel_size.x - m.sep_margin_x
    ui.drawLine(vec2(sep_l, sep_y), vec2(sep_r, sep_y), theme.colors.leaderboard_sep, m.sep_h)
end

local function point_in_rect(p, tl, sz)
    return p.x >= tl.x and p.x <= tl.x + sz.x and p.y >= tl.y and p.y <= tl.y + sz.y
end

--- Select de coche / ranking (Global, AE86, RX7…). Devuelve id nuevo o nil.
function draw.car_filter_combo(origin, width, filters, selected_id)
    theme.ensure_fonts()

    local labels = {}
    local selected_idx = 1
    for i, f in ipairs(filters) do
        labels[i] = f.label
        if f.id == selected_id then selected_idx = i end
    end

    ui.setCursor(origin)
    ui.pushItemWidth(width)
    ui.pushStyleVar(ui.StyleVar.FramePadding, vec2(10, 7))
    ui.pushStyleVar(ui.StyleVar.FrameRounding, 5)
    ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(0.12, 0.12, 0.14, 0.92))
    ui.pushStyleColor(ui.StyleColor.Button, rgbm(0.18, 0.18, 0.22, 0.95))
    ui.pushStyleColor(ui.StyleColor.Text, theme.colors.white)

    local choice, changed = ui.combo("##pd_car_filter", selected_idx, ui.ComboFlags.None, labels)

    ui.popStyleColor(3)
    ui.popStyleVar(2)
    ui.popItemWidth()

    if changed and filters[choice] ~= nil then
        return filters[choice].id
    end
    return nil
end

--- Panel profile/rival: panel_card + overlay opcional.
function draw.card_panel(win_origin, win_size)
    local po, ps = layout.panel_fit(win_size)
    local origin = win_origin + po
    local br = origin + ps
    local bg = images.get_card_panel()

    if bg ~= nil then
        ui.drawImage(bg, origin, br, theme.colors.bg_card)
    else
        local radius = math.min(10, ps.y * 0.5 - 0.5)
        ui.drawRectFilled(origin, br, theme.colors.bg_card, radius, layout.corners_all())
        ui.drawRect(origin, br, theme.colors.panel_border, radius, layout.corners_all(), 1)
    end

    local overlay = images.get_card_panel_overlay()
    if overlay ~= nil then
        ui.drawImage(overlay, origin, br, theme.colors.panel_overlay)
    end

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
    tier = tonumber(tier) or 0
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
    local avatar_sz = opts.avatar_size or AVATAR_ROW
    local tier_sz = opts.tier_size or TIER_ROW
    local name_fs = opts.name_fs or 15
    local sub_fs = opts.sub_fs or 13
    local time_fs = opts.time_fs or name_fs
    local name_gap = opts.name_gap or 6
    local tier_gap = opts.tier_gap or 6
    local time_gap = opts.time_gap or 6
    local trailing_pad = opts.trailing_pad or 8
    local content_w = opts.content_width

    local block_h = math.max(avatar_sz, name_fs + name_gap + sub_fs)
    local y0 = origin.y + (row_h - block_h) * 0.5
    local name_y = y0
    local rank_y = origin.y + (row_h - name_fs) * 0.5

    if opts.draw_rank_number then
        local rank_text = "#" .. tostring(entry.rank)
        ui.pushDWriteFont(theme.fonts.bold)
        local rank_w = measure_text(theme.fonts.bold, rank_text, name_fs)
        ui.dwriteDrawText(rank_text, name_fs, vec2(origin.x + (rank_col - rank_w) * 0.5, rank_y), rank_color)
        ui.popDWriteFont()
    end

    local avatar_x = origin.x + rank_col
    draw.avatar_circle(
        vec2(avatar_x, y0 + (block_h - avatar_sz) * 0.5),
        images.resolve_url(entry.name, entry.avatar_url),
        avatar_sz
    )

    local name_x = avatar_x + avatar_sz + 6
    local name_text = theme.format_display_name(entry.display_name or entry.name)
    local car = entry.car_name or "Car"
    local time_str = theme.format_lap(entry.lap_ms or entry.best_lap_ms)
    local show_rank_on_car = opts.show_rank_on_car == true
    local time_on_name_line = opts.time_on_name_line == true

    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(name_text, name_fs, vec2(name_x, name_y), theme.colors.white)
    ui.popDWriteFont()

    local sub_y = name_y + name_fs + name_gap

    if time_on_name_line and content_w ~= nil then
        local right = origin.x + content_w - trailing_pad
        local tier_x = right - tier_sz
        local tier_y = name_y + (name_fs - tier_sz) * 0.5
        draw.tier_badge(vec2(tier_x, tier_y), entry.tier, tier_sz)

        ui.pushDWriteFont(theme.fonts.medium)
        local time_w = measure_text(theme.fonts.medium, time_str, time_fs)
        local time_x = tier_x - time_gap - time_w
        local time_y = name_y + (name_fs - time_fs) * 0.5
        ui.dwriteDrawText(time_str, time_fs, vec2(time_x, time_y), theme.colors.accent)
        ui.popDWriteFont()

        ui.pushDWriteFont(theme.fonts.medium)
        ui.dwriteDrawText(car, sub_fs, vec2(name_x, sub_y), theme.colors.white)
        ui.popDWriteFont()
    else
        local name_w = measure_text(theme.fonts.bold, name_text, name_fs)
        local tier_x = name_x + name_w + tier_gap
        local tier_y = name_y + (name_fs - tier_sz) * 0.5
        draw.tier_badge(vec2(tier_x, tier_y), entry.tier, tier_sz)

        ui.pushDWriteFont(theme.fonts.medium)
        if show_rank_on_car then
            local car_prefix = "#" .. tostring(entry.rank) .. " " .. car
            ui.dwriteDrawText(car_prefix .. " - ", sub_fs, vec2(name_x, sub_y), theme.colors.white)
            local prefix_w = measure_text(theme.fonts.medium, car_prefix .. " - ", sub_fs)
            ui.dwriteDrawText(time_str, sub_fs, vec2(name_x + prefix_w, sub_y), theme.colors.accent)
        else
            ui.dwriteDrawText(car .. " - ", sub_fs, vec2(name_x, sub_y), theme.colors.white)
            local prefix_w = measure_text(theme.fonts.medium, car .. " - ", sub_fs)
            ui.dwriteDrawText(time_str, sub_fs, vec2(name_x + prefix_w, sub_y), theme.colors.accent)
        end
        ui.popDWriteFont()
    end
end

local function profile_name_text(entry)
    return theme.format_display_name(entry.display_name or entry.name)
end

local function car_line_prefix(entry, opts)
    local car = theme.format_car_short(entry.car_name, entry.car_id)
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

    local name_sz = measure_dwrite(theme.fonts.bold, name_text, m.name_fs)
    local sub_sz = measure_dwrite(theme.fonts.medium, car_prefix .. " - " .. time_str, m.sub_fs)
    local name_row_w = name_sz.x + m.name_tier_gap + m.tier
    local text_w = math.max(name_row_w, sub_sz.x)
    local text_h = name_sz.y + m.line_gap + sub_sz.y

    return text_w, text_h, name_text, car_prefix, time_str, name_sz, sub_sz
end

function draw.profile_card(panel_o, panel_size, entry, opts)
    theme.ensure_fonts()
    opts = opts or {}
    local m = profile_metrics_from_opts(opts)
    local url = images.resolve_url(entry.name, entry.avatar_url)
    local pad = layout.CARD_EDGE_PAD

    local text_w, text_h, name_text, car_prefix, time_str, name_sz, sub_sz =
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

    local tier_x = tx + name_sz.x + m.name_tier_gap
    local name_center_y = text_y + name_sz.y * 0.5
    local tier_y = name_center_y - m.tier * 0.5
    draw.tier_badge(vec2(tier_x, tier_y), entry.tier, m.tier)

    local sub_y = text_y + name_sz.y + m.line_gap

    ui.pushDWriteFont(theme.fonts.medium)
    ui.dwriteDrawText(car_prefix .. " - ", m.sub_fs, vec2(tx, sub_y), theme.colors.white)
    local pw = measure_text(theme.fonts.medium, car_prefix .. " - ", m.sub_fs)
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
