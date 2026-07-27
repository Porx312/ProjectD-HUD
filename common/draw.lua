--[[ Componentes visuales — tamaños fijos px ]]

local theme = require("common.theme")
local images = require("common.images")
local layout = require("common.layout")
local profile = require("common.api.profile")
local draw_text = require("common.draw_text")

local draw = {}

-- Top 5
local AVATAR_ROW = 36
local TIER_ROW = 20
local RANK_COL = 22

local function measure_text(font, text, size)
    return draw_text.measure(font, text, size)
end

local function measure_dwrite(font, text, size)
    return draw_text.measure_size(font, text, size)
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

--- Panel Competition: solo overlay_rivals a pantalla completa.
function draw.competition_panel(win_origin, win_size)
    local po, ps = layout.competition_fit(win_size)
    local origin = win_origin + po
    local br = origin + ps
    local tex = images.get_competition_rivals_overlay()

    if tex ~= nil then
        ui.drawImage(tex, origin, br, theme.colors.competition_rivals_overlay)
    else
        ui.drawRectFilled(origin, br, theme.colors.bg_card, 8, layout.corners_all())
        ui.drawRect(origin, br, theme.colors.panel_border, 8, layout.corners_all(), 1)
    end

    return po, ps
end

--- Cabecera: "TOP 10" + línea separadora.
function draw.leaderboard_header(panel_o, panel_size, info)
    theme.ensure_fonts()
    info = info or {}
    local m = layout.leaderboard_header_metrics(panel_size)
    local title = info.title or m.title

    local function text_w(font, text, fs)
        ui.pushDWriteFont(font)
        local w = measure_text(font, text, fs)
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

--- Mensaje de estado centrado y grande (p. ej. Account restricted).
function draw.center_status_message(origin, size, text, opts)
    theme.ensure_fonts()
    opts = opts or {}
    text = tostring(text or "")
    if text == "" then return end

    local min_dim = math.min(tonumber(size.x) or 0, tonumber(size.y) or 0)
    local fs = opts.fs
    if fs == nil then
        fs = math.max(16, math.min(56, min_dim * 0.28))
        local len = #text
        if len > 18 then fs = fs * 0.82 end
        if len > 26 then fs = fs * 0.72 end
    end

    local font = opts.font or theme.fonts.bold
    local color = opts.color or theme.colors.rival_tag
    local cy = opts.cy or 0.5
    local pt = origin + vec2(size.x * 0.5, size.y * cy)

    ui.pushDWriteFont(font)
    local tw = ui.measureDWriteText(text, fs).x
    ui.dwriteDrawText(text, fs, vec2(pt.x - tw * 0.5, pt.y - fs * 0.52), color)
    ui.popDWriteFont()
end

function draw.avatar_circle(pos, url, size)
    if pos == nil then return end
    size = math.max(4, math.floor(tonumber(size) or 32) + 0.5)
    theme.ensure_fonts()
    local center = pos + vec2(size * 0.5, size * 0.5)
    local radius = size * 0.5
    local segs = math.max(32, math.floor(size * 0.5))

    ui.drawCircleFilled(center, radius, theme.colors.avatar_fill, segs)

    local tex = images.get_avatar(url)
    if tex ~= nil then
        if images.draw_texture_circle(center, radius, tex, theme.colors.white) == false then
            local br = pos + vec2(size, size)
            local uv1, uv2 = images.cover_uv(tex)
            ui.drawImageRounded(tex, pos, br, theme.colors.white, uv1, uv2, radius, images.corners_all())
        end
    else
        local initial = url ~= nil and "…" or "?"
        local fs = math.max(11, size * 0.28)
        ui.pushDWriteFont(theme.fonts.bold)
        local tw = measure_text(theme.fonts.bold, initial, fs)
        ui.dwriteDrawText(initial, fs, center - vec2(tw * 0.5, fs * 0.52), theme.colors.muted)
        ui.popDWriteFont()
    end

    ui.drawCircle(center, radius, theme.colors.avatar_ring, segs, math.max(1, size * 0.022))
end

function draw.tier_badge(pos, tier, tier_sz)
    images.draw_tier_badge(pos, tier, tier_sz)
end

local function truncate_text(text, font, fs, max_w)
    text = tostring(text or "")
    if max_w <= 0 then return "", fs end
    ui.pushDWriteFont(font)
    if ui.measureDWriteText(text, fs).x <= max_w then
        ui.popDWriteFont()
        return text, fs
    end
    local suffix = "…"
    while #text > 0 do
        text = text:sub(1, -2)
        if text == "" then break end
        if ui.measureDWriteText(text .. suffix, fs).x <= max_w then
            ui.popDWriteFont()
            return text .. suffix, fs
        end
    end
    ui.popDWriteFont()
    return suffix, fs
end

--- Fila competition: posición · foto · nombre/coche apilados · tiempo · tier.
function draw.competition_row(origin, entry, opts)
    theme.ensure_fonts()
    opts = opts or {}
    local row_h = opts.row_height or layout.ROW_H
    local rank_col = opts.rank_col_width or RANK_COL
    local content_w = opts.content_width or 200
    local row_id = opts.row_id or ("row_" .. tostring(entry.rank))
    local avatar_sz = math.min(opts.avatar_size or AVATAR_ROW, row_h - 2)
    local tier_sz = math.max(12, math.min(opts.tier_size or TIER_ROW, row_h - 2))
    local name_fs = opts.name_fs or 13
    local car_fs = opts.car_fs or name_fs
    local time_fs = opts.time_fs or name_fs
    local gap = opts.text_gap or 3
    local line_gap = opts.text_line_gap or 1
    local trailing_pad = opts.trailing_pad or 4
    local row_alpha = opts.alpha or 1
    local row_size = vec2(content_w, row_h)

    if opts.no_input ~= true then
        ui.setCursor(origin)
        ui.invisibleButton(row_id, row_size)
        local hovered = ui.itemHovered()
        if hovered then
            ui.drawRectFilled(origin, origin + row_size, rgbm(1, 1, 1, 0.06 * row_alpha), 4, layout.corners_all())
        end
    end

    local is_self = entry.is_self == true

    local border_style = opts.border_style or "gray"
    local fill_col, border_col
    if border_style == "up" then
        fill_col = theme.colors.competition_rank_up_fill
        border_col = theme.colors.competition_rank_up
    elseif border_style == "down" then
        fill_col = theme.colors.competition_rank_down_fill
        border_col = theme.colors.competition_rank_down
    else
        fill_col = theme.colors.competition_row_fill
        border_col = theme.colors.competition_row_border
    end

    ui.drawRectFilled(origin, origin + row_size, rgbm(fill_col.r, fill_col.g, fill_col.b, fill_col.mult * row_alpha), 4, layout.corners_all())
    ui.drawRect(origin, origin + row_size, rgbm(border_col.r, border_col.g, border_col.b, border_col.mult * row_alpha), 4, layout.corners_all(), 1)

    local dim = opts.dimmed == true and 0.82 or 1.0
    local text_alpha = row_alpha * dim
    local rank_color = theme.colors.white
    if entry.rank == 1 then rank_color = theme.colors.accent end
    rank_color = rgbm(rank_color.r, rank_color.g, rank_color.b, rank_color.mult * text_alpha)

    local cy = origin.y + row_h * 0.5
    local tier_x = origin.x + content_w - trailing_pad - tier_sz
    local time_str = theme.format_lap(entry.lap_ms or entry.best_lap_ms)

    ui.pushDWriteFont(theme.fonts.bold)
    local time_w = measure_text(theme.fonts.bold, time_str, time_fs)
    ui.popDWriteFont()

    local time_x = tier_x - gap - time_w
    local text_right = time_x - gap

    local rank_text = "#" .. tostring(entry.rank or "?")
    ui.pushDWriteFont(theme.fonts.bold)
    local rank_w = measure_text(theme.fonts.bold, rank_text, name_fs)
    ui.dwriteDrawText(
        rank_text, name_fs,
        vec2(origin.x + (rank_col - rank_w) * 0.5, cy - name_fs * 0.5),
        rank_color
    )
    ui.popDWriteFont()

    local x = origin.x + rank_col
    draw.avatar_circle(
        vec2(x, cy - avatar_sz * 0.5),
        images.resolve_url(entry.name, entry.avatar_url),
        avatar_sz
    )
    x = x + avatar_sz + gap

    local flex_w = math.max(0, text_right - x)
    local name_text = theme.format_display_name(entry.display_name or entry.name)
    local car_text = theme.format_car_label(entry.car_name, entry.car_id)

    ui.pushDWriteFont(theme.fonts.bold)
    name_text, name_fs = truncate_text(name_text, theme.fonts.bold, name_fs, flex_w)
    ui.popDWriteFont()

    ui.pushDWriteFont(theme.fonts.medium)
    car_text, car_fs = truncate_text(car_text, theme.fonts.medium, car_fs, flex_w)
    ui.popDWriteFont()

    local text_block_h = name_fs + line_gap + car_fs
    local text_top = cy - text_block_h * 0.5

    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(name_text, name_fs, vec2(x, text_top), rgbm(1, 1, 1, text_alpha))
    ui.popDWriteFont()

    ui.pushDWriteFont(theme.fonts.medium)
    ui.dwriteDrawText(car_text, car_fs, vec2(x, text_top + name_fs + line_gap), rgbm(0.55, 0.55, 0.58, text_alpha))
    ui.popDWriteFont()

    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(time_str, time_fs, vec2(time_x, cy - time_fs * 0.5), rgbm(0.35, 0.78, 1.0, text_alpha))
    ui.popDWriteFont()

    draw.tier_badge(vec2(tier_x, cy - tier_sz * 0.5), profile.tier_for_display(entry), tier_sz)

    if opts.draw_separator == true then
        local sep_y = origin.y + row_h
        ui.drawLine(
            vec2(origin.x, sep_y),
            vec2(origin.x + content_w, sep_y),
            rgbm(1, 1, 1, 0.22 * row_alpha),
            1
        )
    end
end

local function flip_item_border(item, anim_state)
    if item.is_self ~= true or anim_state.player_direction == nil then
        return "gray"
    end
    return anim_state.player_direction
end

local function draw_competition_row_at_y(panel_o, content, row_x, list_top, entry, y_rel, border_style)
    if entry == nil then return end
    local y = panel_o.y + list_top + y_rel
    local is_self = entry.is_self == true
    local row_opts = layout.competition_row_opts(content, is_self)
    row_opts.row_id = "comp_" .. tostring(entry.name or entry.rank)
    row_opts.alpha = 1
    row_opts.dimmed = not is_self
    row_opts.draw_separator = false
    row_opts.border_style = border_style or "gray"
    draw.competition_row(vec2(row_x, y), entry, row_opts)
end

--- Lista competition con animación FLIP al reordenar slots.
function draw.competition_ladder(panel_o, panel_size, content, ladder, anim_state)
    local ins = content.clip_inset or { top = 7, bottom = 7, left = 6, right = 6 }
    local list_top = content.list_top
    local row_x = panel_o.x + ins.left + content.pad
    local clip_tl = vec2(panel_o.x + ins.left, panel_o.y + ins.top)
    local clip_br = vec2(panel_o.x + panel_size.x - ins.right, panel_o.y + panel_size.y - ins.bottom)

    ui.pushClipRect(clip_tl, clip_br)

    if anim_state ~= nil and anim_state.mode == "flip_reorder" and anim_state.items ~= nil then
        local sorted = {}
        for _, item in ipairs(anim_state.items) do
            sorted[#sorted + 1] = item
        end
        table.sort(sorted, function(a, b) return a.y < b.y end)
        for _, item in ipairs(sorted) do
            if item.entry ~= nil then
                draw_competition_row_at_y(
                    panel_o, content, row_x, list_top, item.entry, item.y,
                    flip_item_border(item, anim_state)
                )
            end
        end
    elseif ladder ~= nil and ladder.slots ~= nil then
        for i = 0, layout.COMPETITION_ROW_COUNT - 1 do
            local entry = ladder.slots[i]
            if entry ~= nil then
                local y = layout.competition_slot_y(content, i)
                draw_competition_row_at_y(panel_o, content, row_x, list_top, entry, y, "gray")
            end
        end
    end

    ui.popClipRect()
end

local function profile_name_text(entry)
    return theme.format_display_name(entry.display_name or entry.name)
end

local function profile_car_name(entry)
    return theme.format_car_label(entry.car_name, entry.car_id)
end

local function car_line_prefix(entry, opts)
    local car = profile_car_name(entry)
    if opts.show_rank_on_car ~= false and entry.rank ~= nil then
        return "#" .. tostring(entry.rank) .. " " .. car
    end
    return car
end

local function profile_metrics_from_opts(opts)
    if opts.metrics ~= nil then return opts.metrics end
    local panel_size = opts.panel_size or layout.SIZE.profile
    return layout.profile_metrics(panel_size)
end

local function measure_text_column(entry, opts, m)
    local name_text = profile_name_text(entry)
    local car_name = profile_car_name(entry)
    local rank_str = entry.rank ~= nil and ("#" .. tostring(entry.rank) .. " ") or ""
    local car_mid = car_name .. " - "
    local time_str = theme.format_lap(entry.lap_ms or entry.last_lap_ms or entry.best_lap_ms)

    local name_sz = measure_dwrite(theme.fonts.bold, name_text, m.name_fs)
    local sub_sz = measure_dwrite(theme.fonts.medium, rank_str .. car_mid .. time_str, m.sub_fs)
    local tier_w = math.max(14, m.tier) + m.name_tier_gap
    local name_row_w = name_sz.x + tier_w
    local text_w = math.max(name_row_w, sub_sz.x)
    local text_h = name_sz.y + m.line_gap + sub_sz.y

    return text_w, text_h, name_text, rank_str, car_mid, time_str, name_sz, sub_sz
end

local function blend_toward_accent(base, pulse)
    if pulse == nil or pulse <= 0 then return base end
    local h = theme.colors.accent
    local t = pulse * pulse
    return rgbm(
        base.r + (h.r - base.r) * t,
        base.g + (h.g - base.g) * t,
        base.b + (h.b - base.b) * t,
        base.mult
    )
end

function draw.profile_card(panel_o, panel_size, entry, opts)
    theme.ensure_fonts()
    opts = opts or {}
    local m = profile_metrics_from_opts(opts)
    local url = images.resolve_url(entry.name, entry.avatar_url)
    local pad = layout.CARD_EDGE_PAD
    local hl = opts.highlights or {}

    local text_w, text_h, name_text, rank_str, car_mid, time_str, name_sz, sub_sz =
        measure_text_column(entry, opts, m)

    local avatar_pos = vec2(panel_o.x + pad, panel_o.y + pad + layout.AVATAR_Y_EXTRA)
    local tx = panel_o.x + pad + m.avatar + m.avatar_gap
    local text_y = panel_o.y + (panel_size.y - text_h) * 0.5

    draw.avatar_circle(avatar_pos, url, m.avatar)

    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(name_text, m.name_fs, vec2(tx, text_y), theme.colors.white)
    ui.popDWriteFont()

    local tier_n = profile.tier_for_display(entry)
    local tier_x = tx + name_sz.x + m.name_tier_gap
    local name_center_y = text_y + name_sz.y * 0.5
    local tier_y = name_center_y - m.tier * 0.5
    local tier_sz = math.max(14, m.tier)

    if (hl.tier or 0) > 0 then
        local pad_h = 2
        ui.drawRectFilled(
            vec2(tier_x - pad_h, tier_y - pad_h),
            vec2(tier_x + tier_sz + pad_h, tier_y + tier_sz + pad_h),
            rgbm(0.35, 0.78, 1.0, 0.18 * hl.tier),
            3,
            layout.corners_all()
        )
    end
    draw.tier_badge(vec2(tier_x, tier_y), tier_n, tier_sz)

    local sub_y = text_y + name_sz.y + m.line_gap
    local sub_x = tx

    ui.pushDWriteFont(theme.fonts.medium)
    if rank_str ~= "" then
        ui.dwriteDrawText(rank_str, m.sub_fs, vec2(sub_x, sub_y), blend_toward_accent(theme.colors.white, hl.rank))
        sub_x = sub_x + measure_text(theme.fonts.medium, rank_str, m.sub_fs)
    end
    ui.dwriteDrawText(car_mid, m.sub_fs, vec2(sub_x, sub_y), theme.colors.white)
    sub_x = sub_x + measure_text(theme.fonts.medium, car_mid, m.sub_fs)
    ui.dwriteDrawText(time_str, m.sub_fs, vec2(sub_x, sub_y), blend_toward_accent(theme.colors.accent, hl.time))
    ui.popDWriteFont()
end

function draw.profile_block(win_origin, win_size, entry, extra)
    extra = extra or {}
    local po, ps = layout.panel_fit(win_size)
    local panel_o = win_origin + po
    local opts = {
        show_rank_on_car = true,
        metrics = layout.profile_metrics(ps),
        highlights = extra.highlights,
    }
    draw.profile_card(panel_o, ps, entry, opts)
end

local draw_battle_mod

local function draw_battle()
    if draw_battle_mod == nil then
        draw_battle_mod = require("common.draw_battle")
    end
    return draw_battle_mod
end

--- Fondo battle escalado (bg.png) sobre el rect de la barra.
function draw.battle_panel(bar_origin, bar_size)
    return draw_battle().battle_panel(bar_origin, bar_size)
end

--- Capas battle sobre la barra; gap debajo si opts.gap_h > 0.
function draw.battle_block(panel_o, panel_size, battle, opts)
    draw_battle().battle_block(panel_o, panel_size, battle, opts)
end

return draw
