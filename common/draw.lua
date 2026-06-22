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

local leaderboard_car_name

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
        local time_w = measure_text(theme.fonts.medium, time_str, time_fs)
        local pair_gap = math.max(4, time_gap)
        local block_w = time_w + pair_gap + tier_sz
        local block_center_x = origin.x + content_w * 0.82
        local block_left = math.min(
            right - block_w,
            math.max(name_x + avatar_sz + 18, block_center_x - block_w * 0.5)
        )
        local time_x = block_left
        local tier_x = time_x + time_w + pair_gap
        local tier_y = origin.y + (row_h - tier_sz) * 0.5
        draw.tier_badge(vec2(tier_x, tier_y), entry.tier, tier_sz)

        ui.pushDWriteFont(theme.fonts.medium)
        local time_y = tier_y + (tier_sz - time_fs) * 0.5
        ui.dwriteDrawText(time_str, time_fs, vec2(time_x, time_y), theme.colors.accent)
        ui.popDWriteFont()

        ui.pushDWriteFont(theme.fonts.medium)
        ui.dwriteDrawText(leaderboard_car_name(entry), sub_fs, vec2(name_x, sub_y), theme.colors.white)
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

local function profile_car_name(entry)
    local car = entry.car_name
    if car == nil or car == "" then
        car = theme.format_car_short(entry.car_name, entry.car_id)
    end

    car = car:gsub("^%s+", ""):gsub("%s+$", "")
    car = car:gsub("%s+", " ")

    local first_word = car:match("^(%S+)")
    if first_word ~= nil and #first_word <= 10 then
        return first_word
    end

    if #car <= 10 then
        return car
    end

    return car:sub(1, 10)
end

local function car_line_prefix(entry, opts)
    local car = profile_car_name(entry)
    if opts.show_rank_on_car ~= false and entry.rank ~= nil then
        return "#" .. tostring(entry.rank) .. " " .. car
    end
    return car
end

leaderboard_car_name = function(entry)
    local car = entry.car_name
    if car == nil or car == "" then
        car = theme.format_car_short(entry.car_name, entry.car_id)
    end

    car = car:gsub("^%s+", ""):gsub("%s+$", "")
    car = car:gsub("%s+", " ")

    local first_word = car:match("^(%S+)")
    if first_word ~= nil and #first_word <= 6 then
        return first_word
    end

    if #car <= 6 then
        return car
    end

    return car:sub(1, 6)
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

local function battle_player_side(panel_o, panel_w, player, side, m)
    theme.ensure_fonts()
    player = player or {}
    local pad = m.pad
    local avatar_y = panel_o.y + (m.main_h - m.avatar) * 0.5

    if player.placeholder == true then
        local placeholder_name = "Looking for opponent"
        if side == "left" then
            local avatar_x = panel_o.x + pad
            ui.drawRectFilled(
                vec2(avatar_x, avatar_y),
                vec2(avatar_x + m.avatar, avatar_y + m.avatar),
                theme.colors.battle_gap_track,
                m.avatar * 0.5,
                layout.corners_all()
            )
            ui.drawRect(
                vec2(avatar_x, avatar_y),
                vec2(avatar_x + m.avatar, avatar_y + m.avatar),
                theme.colors.battle_border,
                m.avatar * 0.5,
                layout.corners_all(),
                1
            )
            local tx = avatar_x + m.avatar + 8
            local ty = panel_o.y + (m.main_h - m.name_fs) * 0.5
            ui.pushDWriteFont(theme.fonts.medium)
            ui.dwriteDrawText(placeholder_name, m.name_fs - 1, vec2(tx, ty), theme.colors.muted)
            ui.popDWriteFont()
        else
            local avatar_x = panel_o.x + panel_w - pad - m.avatar
            ui.drawRectFilled(
                vec2(avatar_x, avatar_y),
                vec2(avatar_x + m.avatar, avatar_y + m.avatar),
                theme.colors.battle_gap_track,
                m.avatar * 0.5,
                layout.corners_all()
            )
            ui.drawRect(
                vec2(avatar_x, avatar_y),
                vec2(avatar_x + m.avatar, avatar_y + m.avatar),
                theme.colors.battle_border,
                m.avatar * 0.5,
                layout.corners_all(),
                1
            )
            ui.pushDWriteFont(theme.fonts.medium)
            local name_w = measure_text(theme.fonts.medium, placeholder_name, m.name_fs - 1)
            ui.popDWriteFont()
            local ty = panel_o.y + (m.main_h - (m.name_fs - 1)) * 0.5
            local tx = avatar_x - 8 - name_w
            ui.pushDWriteFont(theme.fonts.medium)
            ui.dwriteDrawText(placeholder_name, m.name_fs - 1, vec2(tx, ty), theme.colors.muted)
            ui.popDWriteFont()
        end
        return
    end

    local url = images.resolve_url(player.name, player.avatar_url)
    local name = theme.format_display_name(player.name)
    local car = profile_car_name(player)

    if side == "left" then
        local avatar_x = panel_o.x + pad
        draw.avatar_circle(vec2(avatar_x, avatar_y), url, m.avatar)

        local tier_x = avatar_x + m.avatar - m.tier * 0.35
        local tier_y = avatar_y + m.avatar - m.tier * 0.65
        draw.tier_badge(vec2(tier_x, tier_y), player.tier, m.tier)

        local tx = avatar_x + m.avatar + 8
        local text_h = m.name_fs + 2 + m.car_fs
        local ty = panel_o.y + (m.main_h - text_h) * 0.5

        ui.pushDWriteFont(theme.fonts.bold)
        ui.dwriteDrawText(name, m.name_fs, vec2(tx, ty), theme.colors.white)
        ui.popDWriteFont()

        ui.pushDWriteFont(theme.fonts.medium)
        ui.dwriteDrawText(car, m.car_fs, vec2(tx, ty + m.name_fs + 2), theme.colors.muted)
        ui.popDWriteFont()
    else
        local avatar_x = panel_o.x + panel_w - pad - m.avatar
        draw.avatar_circle(vec2(avatar_x, avatar_y), url, m.avatar)

        local tier_x = avatar_x - m.tier * 0.65
        local tier_y = avatar_y + m.avatar - m.tier * 0.65
        draw.tier_badge(vec2(tier_x, tier_y), player.tier, m.tier)

        ui.pushDWriteFont(theme.fonts.bold)
        local name_w = measure_text(theme.fonts.bold, name, m.name_fs)
        ui.popDWriteFont()

        ui.pushDWriteFont(theme.fonts.medium)
        local car_w = measure_text(theme.fonts.medium, car, m.car_fs)
        ui.popDWriteFont()

        local text_h = m.name_fs + 2 + m.car_fs
        local ty = panel_o.y + (m.main_h - text_h) * 0.5
        local tx = avatar_x - 8 - math.max(name_w, car_w)

        ui.pushDWriteFont(theme.fonts.bold)
        ui.dwriteDrawText(name, m.name_fs, vec2(tx + math.max(name_w, car_w) - name_w, ty), theme.colors.white)
        ui.popDWriteFont()

        ui.pushDWriteFont(theme.fonts.medium)
        ui.dwriteDrawText(car, m.car_fs, vec2(tx + math.max(name_w, car_w) - car_w, ty + m.name_fs + 2), theme.colors.muted)
        ui.popDWriteFont()
    end
end

local function battle_parse_placeholder()
    return {
        placeholder = true,
        name = "Looking for opponent",
        car_name = "",
        tier = 0,
    }
end

--- Battle HUD: two players, center phase label, scores, 3D separation bar.
function draw.battle_block(win_origin, win_size, battle)
    theme.ensure_fonts()
    battle = battle or {}
    local m = layout.BATTLE_DESIGN
    local panel_o = win_origin
    local panel_w = win_size.x
    local panel_h = win_size.y
    local state_name = string.lower(tostring(battle.state or "pairing"))

    local radius = math.min(panel_h * 0.5 - 0.5, m.main_h * 0.5)
    local main_br = vec2(panel_o.x + panel_w, panel_o.y + m.main_h)
    ui.drawRectFilled(panel_o, main_br, theme.colors.battle_bg, radius, layout.corners_all())
    ui.drawRect(panel_o, main_br, theme.colors.battle_border, radius, layout.corners_all(), 1)

    local left = battle.player_left or {}
    local right = battle.player_right or battle_parse_placeholder()
    battle_player_side(panel_o, panel_w, left, "left", m)
    battle_player_side(panel_o, panel_w, right, "right", m)

    local center_x = panel_o.x + panel_w * 0.5
    local center_text = tostring(battle.center_text or battle.mode or "BATTLE")
    local center_fs = m.mode_fs

    if state_name == "arming" then
        center_fs = 22
    elseif state_name == "launching" then
        center_fs = 18
    elseif state_name == "finished" or state_name == "cancelled" then
        center_fs = 11
    end

    ui.pushDWriteFont(theme.fonts.bold)
    local center_w = measure_text(theme.fonts.bold, center_text, center_fs)
    ui.popDWriteFont()

    local center_pad_x = 8
    local center_pad_y = 3
    local center_box_w = center_w + center_pad_x * 2
    local center_box_h = center_fs + center_pad_y * 2
    local center_x0 = center_x - center_box_w * 0.5
    local center_y0 = panel_o.y + 8

    ui.drawRectFilled(
        vec2(center_x0, center_y0),
        vec2(center_x0 + center_box_w, center_y0 + center_box_h),
        theme.colors.battle_mode_bg,
        4,
        layout.corners_all()
    )
    ui.pushDWriteFont(theme.fonts.bold)
    ui.dwriteDrawText(center_text, center_fs, vec2(center_x0 + center_pad_x, center_y0 + center_pad_y), theme.colors.white)
    ui.popDWriteFont()

    if battle.show_scores == true or state_name == "finished" or state_name == "cancelled" then
        local score_text = tostring(battle.score_left or 0) .. " vs " .. tostring(battle.score_right or 0)
        if state_name == "finished" and battle.winner_name ~= nil and battle.winner_name ~= "" then
            score_text = battle.winner_name .. "  " .. score_text
        end
        ui.pushDWriteFont(theme.fonts.bold)
        local score_w = measure_text(theme.fonts.bold, score_text, m.score_fs - 4)
        local score_y = panel_o.y + m.main_h - (m.score_fs - 4) - 8
        ui.dwriteDrawText(score_text, m.score_fs - 4, vec2(center_x - score_w * 0.5, score_y), theme.colors.white)
        ui.popDWriteFont()
    end

    local event_label = tostring(battle.event_label or "")
    if event_label ~= "" and state_name == "active" then
        ui.pushDWriteFont(theme.fonts.medium)
        local ev_w = measure_text(theme.fonts.medium, event_label, 9)
        local ev_y = center_y0 + center_box_h + 2
        ui.dwriteDrawText(event_label, 9, vec2(center_x - ev_w * 0.5, ev_y), theme.colors.accent)
        ui.popDWriteFont()
    end

    if battle.show_gap == true then
        local gap = battle.gap or {}
        local gap_current = math.max(0, tonumber(gap.current or battle.gap3d_m) or 0)
        local gap_max = math.max(1, tonumber(gap.max or battle.disappear_gap_m) or 250)
        local gap_ratio = math.min(1, gap_current / gap_max)

        local gap_w = math.min(panel_w * 0.88, 340)
        local gap_h = m.gap_h - 6
        local gap_x = center_x - gap_w * 0.5
        local gap_y = panel_o.y + m.main_h - m.gap_overlap
        local gap_br = vec2(gap_x + gap_w, gap_y + gap_h)

        ui.drawRectFilled(vec2(gap_x, gap_y), gap_br, theme.colors.battle_gap_track, 6, layout.corners_all())
        if gap_ratio > 0 then
            local fill_w = math.max(6, gap_w * gap_ratio)
            ui.drawRectFilled(
                vec2(gap_x, gap_y),
                vec2(gap_x + fill_w, gap_y + gap_h),
                theme.colors.battle_gap_fill,
                6,
                layout.corners_all()
            )
        end
        ui.drawRect(vec2(gap_x, gap_y), gap_br, theme.colors.battle_border, 6, layout.corners_all(), 1)

        local gap_label = string.format("%dm / %dm", math.floor(gap_current + 0.5), math.floor(gap_max + 0.5))
        ui.pushDWriteFont(theme.fonts.medium)
        local gap_label_w = measure_text(theme.fonts.medium, gap_label, m.gap_label_fs)
        local gap_label_y = gap_y + (gap_h - m.gap_label_fs) * 0.5
        ui.dwriteDrawText(gap_label, m.gap_label_fs, vec2(center_x - gap_label_w * 0.5, gap_label_y), theme.colors.white)
        ui.popDWriteFont()
    end
end

return draw
