--[[ Tamaños fijos — sin auto-scale (FIXED_SIZE en manifest) ]]

local layout = {}

layout.PAD_COMPETITION = 4
layout.COMPETITION_PAD = 6
layout.COMPETITION_ROW_COUNT = 3
layout.COMPETITION_CENTER_SCALE = 1.0
layout.COMPETITION_ROW_SCALE = 1.0
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
    title = "COMPETITION",
    title_fs = 108,
    meta_fs = 92,
    sep_h = 2,
    sep_margin_x = 40,
    sep_margin_bottom = 14,
}

--- panel_card.png — proporción real del asset horizontal.
layout.PANEL_NATIVE = vec2(1795, 533.17)
layout.PANEL_ASPECT = layout.PANEL_NATIVE.x / layout.PANEL_NATIVE.y

--- Medidas profile (canvas 1795×533).
layout.PROFILE_DESIGN = {
    avatar = 465.7,
    name_fs = 188,
    sub_fs = 104,
    tier = 228,
    avatar_gap = 52,
    name_tier_gap = 38,
    line_gap = 20,
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
    }
end

layout.SIZE = {
    competition = vec2(300, 280),
    profile = vec2(280, 84),
    battle  = vec2(800, 142),
}

--- battle/bg.png — canvas nativo del bar (editar posiciones en BATTLE_DESIGN).
layout.BATTLE_NATIVE = vec2(3010, 469)
layout.BATTLE_ASPECT = layout.BATTLE_NATIVE.x / layout.BATTLE_NATIVE.y
layout.BATTLE_GAP_H = 58
layout.BATTLE_GAP_MARGIN = 11

--- Coordenadas en canvas 3010×469 — solo cambiar números aquí para mover elementos.
layout.BATTLE_DESIGN = {
    --- Marco exterior (container.png) — suele cubrir todo el panel.
    container = { x = 0, y = 0, w = 3010, h = 469 },

    --- Fondo interior / watermark (bg.png) — encima del container.
    bg = { x = 0, y = 0, w = 3010, h = 469 },

    --- Slot común para center_*.png (contain; solo matchmaking usa center_matchmaking_scale)
    center = { x = 0, y = 0, w = 1050, h = 469, anchor = "center" },
    center_matchmaking_scale = 0.76,

    --- Jugador izquierdo — slot 442×442; foto más pequeña dentro (avatar_circle_size)
    left_avatar = { x = 175, y = 13, w = 442, h = 442 },

    --- Jugador derecho — mismo margen que izquierda (anchor right)
    right_avatar = { x = 175, y = 13, w = 442, h = 442, anchor = "right" },

    --- Círculo de foto de perfil / looking (px nativos; margen dentro del slot)
    avatar_circle_size = 427,
    avatar_circle_offset_y = 3.4,
    --- Overlay matchmaking — PNG 697×442; ? escala con avatar_circle_size + offset
    searching_native = vec2(697, 442),

    --- Texto al lado del avatar (draw_battle)
    text_avatar_gap = 18,

    ---[[ Texto dinámico sobre center_*.png — solo posición, no mueve los PNG.
    --- Marco: slot `center` (1050×469, centrado en canvas 3010×469).
    --- Fórmula (layout.battle_center_point):
    ---   x = centro_x + ancho_centro/2 + cx * scale
    ---   y = centro_y + alto_centro * cy + ty * scale
    ---   scale = ancho_panel / 3010
    ---
    --- cx  — px nativos desde el centro horizontal del slot. Negativo = izq, positivo = der.
    --- cy  — fracción 0..1 del alto del slot (0 = arriba, 0.5 = mitad, 1 = abajo).
    --- ty  — ajuste fino vertical en px nativos (negativo = subir, positivo = bajar). Opcional.
    ---
    --- Tamaño de fuente: score_fs, countdown_fs, role_fs, event_fs, hint_fs (más abajo).
    --- Probar sin API: ac.storage("ProjectD-HUD:battle_mock_state", "active"|"countdown"|…)
    --]]
    center_role = { cx = 0, cy = 0.11, ty = 6 },           -- LEAD / CHASE (sin PNG)
    center_event_top = { cx = 0, cy = 0.09, ty = 2 },      -- SEPARATED, IDLE, OVERTAKE…
    center_event = { cx = 0, cy = 0.85, ty = -6 },         -- toast inferior (puntos)
    center_score_left = { cx = -168, cy = 0.46, ty = -2.5 },
    center_score_right = { cx = 168, cy = 0.46, ty = -2.5 },
    center_score_vs = { cx = 0, cy = 0.46, ty = -2.5 },
    --- center_points.png — VS en el PNG; dígitos a los lados, rol arriba, evento abajo
    center_points_role = { cx = 0, cy = 0.20, ty = 2 },
    center_points_score_left = { cx = -132, cy = 0.50, ty = -4 },
    center_points_score_right = { cx = 132, cy = 0.50, ty = -4 },
    center_points_event = { cx = 0, cy = 0.86, ty = 0 },
    center_countdown = { cx = 0, cy = 0.40 },              -- 5→1 / GO!
    countdown_hint = { cx = 0, cy = 0.72 },                -- hint bajo countdown

    --- Barra gap 3D (estilo CMRT deltabar) — fracción del ancho del panel
    gap_bar_x_start = 0.05,
    gap_bar_x_end = 0.52,
    gap_bar_pad = 2,

    --- center-result.png — caja azul: avatar, nombre, puntuación (ej. 1-0)
    center_result_avatar = { cx = -200, cy = 0.60, ty = 4 },
    center_result_name = { cx = -50, cy = 0.60, ty = 4 },
    center_result_score = { cx = 200, cy = 0.60, ty = 4 },

    --- Empate — solo texto grande (sin PNG center_draw)
    center_draw_label = { cx = 0, cy = 0.42 },
    center_draw_score = { cx = 0, cy = 0.58 },

    result_avatar_size = 80,
    result_name_fs = 104,
    result_score_fs = 128,
    draw_label_fs = 280,
    draw_score_fs = 180,

    name_fs = 105,
    car_fs = 94,
    score_fs = 190,
    score_vs_fs = 88,
    mode_fs = 72,
    countdown_fs = 240,
    role_fs = 68,
    hint_fs = 28,
    distance_fs = 38,
    event_fs = 68,
    tier_size = 152,
    name_car_gap = 14,

    --- Chip tier + ELO dentro del avatar (esquina interior)
    avatar_chip_tier_sz = 96,
    avatar_chip_elo_fs = 52,
    avatar_chip_pad = 10,
    avatar_chip_inner_gap = 10,
    avatar_chip_radius = 22,
    avatar_chip_inset = 12,
    avatar_chip_bottom_inset = 4,
}

function layout.battle_scale(panel_size)
    if panel_size == nil then return -1 end
    local pw = tonumber(panel_size.x) or tonumber(panel_size[-1]) or 0
    if pw <= 0 then return -1 end
    return pw / layout.BATTLE_NATIVE.x
end

function layout.battle_fit(win_size)
    local aspect = layout.BATTLE_ASPECT
    
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

--- Barra principal + franja gap debajo (fuera del PNG del bar).
function layout.battle_frame_fit(win_size, include_gap)
    if include_gap ~= true then
        local po, ps = layout.battle_fit(win_size)
        return po, ps, 0, 0
    end

    local s = win_size.x / layout.BATTLE_NATIVE.x
    local bar_h = layout.BATTLE_NATIVE.y * s
    local gap_margin = 0
    local gap_h = 0
    if include_gap == true then
        gap_margin = layout.BATTLE_GAP_MARGIN * s
        gap_h = layout.BATTLE_GAP_H * s
    end
    local total_h = bar_h + gap_margin + gap_h
    local oy = 0
    if win_size.y > total_h then
        oy = (win_size.y - total_h) * 0.5
    end
    return vec2(0, oy), vec2(win_size.x, bar_h), gap_margin, gap_h
end

function layout.battle_gap_rect(bar_origin, bar_size, gap_margin, gap_h)
    local d = layout.BATTLE_DESIGN
    local x0 = tonumber(d.gap_bar_x_start) or 0.05
    local x1 = tonumber(d.gap_bar_x_end) or 0.50
    if x1 < x0 then x0, x1 = x1, x0 end
    local gx = bar_origin.x + bar_size.x * x0
    local gw = bar_size.x * (x1 - x0)
    local gy = bar_origin.y + bar_size.y + gap_margin
    return vec2(gx, gy), vec2(gw, gap_h)
end

--- Convierte slot BATTLE_DESIGN → origen + tamaño en píxeles de pantalla.
function layout.battle_slot(panel_o, panel_size, slot)
    local s = layout.battle_scale(panel_size)
    local w = (slot.w or slot.size or 0) * s
    local h = (slot.h or slot.size or w) * s
    local x = slot.x * s
    local y = slot.y * s
    local anchor = slot.anchor or "left"
    local px

    if anchor == "right" then
        px = panel_o.x + panel_size.x - x - w
    elseif anchor == "center" then
        px = panel_o.x + (panel_size.x - w) * 0.5 + x
    else
        px = panel_o.x + x
    end

    return vec2(px, panel_o.y + y), vec2(w, h)
end

--- Punto ancla para texto (center/right/left).
function layout.battle_point(panel_o, panel_size, slot)
    local s = layout.battle_scale(panel_size)
    local anchor = slot.anchor or "left"
    local px

    if anchor == "right" then
        px = panel_o.x + panel_size.x - slot.x * s
    elseif anchor == "center" then
        px = panel_o.x + panel_size.x * 0.5 + slot.x * s
    else
        px = panel_o.x + slot.x * s
    end

    return vec2(px, panel_o.y + slot.y * s)
end

--- Rect de dibujo para center_*.png (escala solo en matchmaking).
function layout.battle_center_rect(panel_o, panel_size, center_key)
    local d = layout.BATTLE_DESIGN
    local o, sz = layout.battle_slot(panel_o, panel_size, d.center)
    local scale = 1
    if center_key == "matchmaking" then
        scale = tonumber(d.center_matchmaking_scale) or 1
    end
    if scale >= 0.999 and scale <= 1.001 then
        return o, sz
    end
    scale = math.max(0.5, math.min(1, scale))
    local nw = sz.x * scale
    local nh = sz.y * scale
    return vec2(o.x + (sz.x - nw) * 0.5, o.y + (sz.y - nh) * 0.5), vec2(nw, nh)
end

--- Círculo de foto de perfil (más pequeño que el slot; margen superior vía offset_y).
function layout.battle_avatar_circle(panel_o, panel_size, side)
    local d = layout.BATTLE_DESIGN
    local slot = side == "right" and d.right_avatar or d.left_avatar
    local av_o, av_sz = layout.battle_slot(panel_o, panel_size, slot)
    local s = layout.battle_scale(panel_size)
    local diam_native = tonumber(d.avatar_circle_size) or slot.w or slot.h or 442
    local size = math.max(4, math.floor(diam_native * s + 0.5))
    local ox = av_o.x + (av_sz.x - size) * 0.5
    local oy = av_o.y + (av_sz.y - size) * 0.5 + (tonumber(d.avatar_circle_offset_y) or 0) * s
    return vec2(ox, oy), size
end

--- Origen del chip tier+ELO dentro del círculo del avatar (esquina interior).
function layout.battle_avatar_chip_origin(circle_o, circle_sz, side, chip_w, chip_h, scale)
    local d = layout.BATTLE_DESIGN
    scale = scale or 1
    local h_inset = math.max((d.avatar_chip_inset or 12) * scale, circle_sz * 0.05)
    local bottom_inset = math.max((d.avatar_chip_bottom_inset or 4) * scale, circle_sz * 0.02)
    local y = circle_o.y + circle_sz - chip_h - bottom_inset
    if side == "right" then
        return vec2(circle_o.x + h_inset, y)
    end
    return vec2(circle_o.x + circle_sz - chip_w - h_inset, y)
end

--- Overlay looking: mismo tamaño/offset que battle_avatar_circle (perfil derecho).
function layout.battle_searching_rect(panel_o, panel_size)
    local d = layout.BATTLE_DESIGN
    local circle_o, circle_sz = layout.battle_avatar_circle(panel_o, panel_size, "right")
    local native = d.searching_native or vec2(697, 442)
    local circle_w = math.max(1, d.searching_circle_w or 442)
    local scale = circle_sz / circle_w
    local nw = math.max(4, math.floor(native.x * scale + 0.5))
    local nh = math.max(4, math.floor(native.y * scale + 0.5))
    local ox = circle_o.x + circle_sz - nw
    local oy = circle_o.y + (circle_sz - nh) * 0.5
    return vec2(ox, oy), vec2(nw, nh)
end

--- Punto ancla para texto dinámico del centro (ver comentario cx/cy/ty en BATTLE_DESIGN).
--- cx, ty: píxeles nativos (3010) escalados; cy: fracción 0..1 del alto del slot center.
function layout.battle_center_point(panel_o, panel_size, pt)
    local d = layout.BATTLE_DESIGN
    local c_o, c_sz = layout.battle_slot(panel_o, panel_size, d.center)
    local s = layout.battle_scale(panel_size)
    local cx_off = (pt.cx or 0) * s
    local cy_frac = pt.cy or 0.5
    local ty_off = (pt.ty or 0) * s
    return vec2(c_o.x + c_sz.x * 0.5 + cx_off, c_o.y + c_sz.y * cy_frac + ty_off)
end

function layout.battle_metrics(panel_size)
    local s = layout.battle_scale(panel_size)
    local d = layout.BATTLE_DESIGN
    return {
        scale = s,
        name_fs = d.name_fs * s,
        car_fs = d.car_fs * s,
        score_fs = d.score_fs * s,
        score_vs_fs = d.score_vs_fs * s,
        mode_fs = d.mode_fs * s,
        countdown_fs = d.countdown_fs * s,
        role_fs = d.role_fs * s,
        hint_fs = d.hint_fs * s,
        distance_fs = d.distance_fs * s,
        event_fs = d.event_fs * s,
        tier_sz = d.tier_size * s,
        name_car_gap = d.name_car_gap * s,
        text_avatar_gap = d.text_avatar_gap * s,
        result_avatar_sz = d.result_avatar_size * s,
        result_name_fs = d.result_name_fs * s,
        result_score_fs = d.result_score_fs * s,
        draw_label_fs = d.draw_label_fs * s,
        draw_score_fs = d.draw_score_fs * s,
        chip_tier_sz = d.avatar_chip_tier_sz * s,
        chip_elo_fs = d.avatar_chip_elo_fs * s,
        chip_pad = d.avatar_chip_pad * s,
        chip_inner_gap = d.avatar_chip_inner_gap * s,
        chip_radius = d.avatar_chip_radius * s,
        design = d,
    }
end

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

--- Competition usa toda la ventana (sin letterbox del panel vertical).
function layout.competition_fit(win_size)
    return vec2(0, 0), win_size
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
        sep_h = math.max(1, d.sep_h * s),
        sep_margin_x = d.sep_margin_x * s,
        sep_margin_bottom = d.sep_margin_bottom * s,
    }
end

function layout.corners_all()
    return 15
end

--- Métricas Competition: 3 filas iguales, centradas, sin interacción (permite arrastrar el HUD).
function layout.competition_content(panel_size)
    local pad = layout.COMPETITION_PAD
    local rows = layout.COMPETITION_ROW_COUNT
    local list_h = math.max(1, panel_size.y)
    local row_gap = math.max(6, math.floor(panel_size.y * 0.028))
    local total_gap = row_gap * (rows - 1)
    local row_h = (list_h - total_gap) / rows
    local block_h = row_h * rows + total_gap
    local list_top = math.max(0, (panel_size.y - block_h) * 0.5)
    local content_width = panel_size.x - pad * 2

    local rh = row_h / 40
    local name_fs = math.min(12, math.max(9, math.floor(10.5 * rh)))
    local row = {
        row_height = row_h,
        rank_col_width = math.max(15, math.floor(17 * rh)),
        content_width = content_width,
        avatar_size = math.max(14, math.floor(row_h * 0.68)),
        tier_size = math.max(11, math.floor(row_h * 0.44)),
        name_fs = name_fs,
        car_fs = math.max(8, name_fs - 1),
        time_fs = math.max(8, math.floor(name_fs * 0.95)),
        text_gap = math.max(2, math.floor(2.5 * rh)),
        trailing_pad = 4,
    }

    return {
        pad = pad,
        list_top = list_top,
        block_h = block_h,
        row_h = row_h,
        side_row_h = row_h,
        center_row_h = row_h,
        row_heights = {
            [0] = row_h,
            [1] = row_h,
            [2] = row_h,
        },
        row_count = rows,
        content_width = content_width,
        row_gap = row_gap,
        row = row,
        side_row = row,
        center_row = row,
        name_fs = name_fs,
    }
end

--- Opciones de dibujo por fila (todas iguales).
function layout.competition_row_opts(content, _is_self)
    local src = content.row or content.side_row
    return {
        row_height = src.row_height,
        rank_col_width = src.rank_col_width,
        content_width = src.content_width,
        avatar_size = src.avatar_size,
        tier_size = src.tier_size,
        name_fs = src.name_fs,
        car_fs = src.car_fs,
        time_fs = src.time_fs,
        text_gap = src.text_gap,
        trailing_pad = src.trailing_pad,
        no_input = true,
    }
end

return layout
