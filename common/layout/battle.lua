--[[ Layout — battle HUD ]]

local M = {}

--- battle/bg.png ΓÇö canvas nativo del bar (editar posiciones en BATTLE_DESIGN).
M.BATTLE_NATIVE = vec2(3010, 469)
M.BATTLE_ASPECT = M.BATTLE_NATIVE.x / M.BATTLE_NATIVE.y
M.BATTLE_GAP_H = 176
M.BATTLE_GAP_MARGIN = -20
M.BATTLE_GAP_MIN_PX = 40

--- Coordenadas en canvas 3010├ù469 ΓÇö solo cambiar n├║meros aqu├¡ para mover elementos.
M.BATTLE_DESIGN = {
    --- Marco exterior (container.png) ΓÇö suele cubrir todo el panel.
    container = { x = 0, y = 0, w = 3010, h = 469 },

    --- Fondo interior / watermark (bg.png) ΓÇö encima del container.
    bg = { x = 0, y = 0, w = 3010, h = 469 },

    --- Slot com├║n para center_*.png (contain; solo matchmaking usa center_matchmaking_scale)
    center = { x = 0, y = 0, w = 1050, h = 469, anchor = "center" },
    center_matchmaking_scale = 0.76,

    --- Jugador izquierdo ΓÇö slot 442├ù442; foto m├ís peque├▒a dentro (avatar_circle_size)
    left_avatar = { x = 175, y = 13, w = 442, h = 442 },

    --- Jugador derecho ΓÇö mismo margen que izquierda (anchor right)
    right_avatar = { x = 175, y = 13, w = 442, h = 442, anchor = "right" },

    --- C├¡rculo de foto de perfil / looking (px nativos; margen dentro del slot)
    avatar_circle_size = 427,
    avatar_circle_offset_y = 3.4,
    --- Overlay matchmaking ΓÇö PNG 697├ù442; ? escala con avatar_circle_size + offset
    searching_native = vec2(697, 442),

    --- Texto al lado del avatar (draw_battle)
    text_avatar_gap = 18,

    ---[[ Texto din├ímico sobre center_*.png ΓÇö solo posici├│n, no mueve los PNG.
    --- Marco: slot `center` (1050├ù469, centrado en canvas 3010├ù469).
    --- F├│rmula (M.battle_center_point):
    ---   x = centro_x + ancho_centro/2 + cx * scale
    ---   y = centro_y + alto_centro * cy + ty * scale
    ---   scale = ancho_panel / 3010
    ---
    --- cx  ΓÇö px nativos desde el centro horizontal del slot. Negativo = izq, positivo = der.
    --- cx_frac ΓÇö fracci├│n del ancho del rect PNG (center_points_score_*); alternativa a cx.
    --- cy  ΓÇö fracci├│n 0..1 del alto del slot (0 = arriba, 0.5 = mitad, 1 = abajo).
    --- ty  ΓÇö ajuste fino vertical en px nativos (negativo = subir, positivo = bajar). Opcional.
    ---
    --- Tama├▒o de fuente: score_fs, countdown_fs, role_fs, event_fs, hint_fs (m├ís abajo).
    --- Probar sin API: ac.storage("ProjectD-HUD:battle_mock_state", "active"|"countdown"|ΓÇª)
    --]]
    center_role = { cx = 0, cy = 0.11, ty = 6 },           -- LEAD / CHASE (sin PNG)
    center_event_top = { cx = 0, cy = 0.09, ty = 2 },      -- SEPARATED, IDLE, OVERTAKEΓÇª
    center_event = { cx = 0, cy = 0.85, ty = -6 },         -- toast inferior (puntos)
    center_score_left = { cx = -168, cy = 0.46, ty = -2.5 },
    center_score_right = { cx = 168, cy = 0.46, ty = -2.5 },
    center_score_vs = { cx = 0, cy = 0.46, ty = -2.5 },
    --- center_points.png ΓÇö VS en el PNG; d├¡gitos a los lados, rol arriba, evento abajo
    --- cx_frac: fracci├│n del ancho del PNG contain-fit (┬▒0.34 Γëê huecos laterales del arte)
    center_points_role = { cx = 0, cy = 0.13, ty = 2 },
    center_points_score_left = { cx_frac = -0.34, cy = 0.50, ty = -2 },
    center_points_score_right = { cx_frac = 0.34, cy = 0.50, ty = -2 },
    center_points_event = { cx = 0, cy = 0.91, ty = 0 },
    center_countdown = { cx = 0, cy = 0.40 },              -- 5ΓåÆ1 / GO!
    countdown_hint = { cx = 0, cy = 0.72 },                -- hint bajo countdown
    center_phase_label = { cx = 0, cy = 0.50, ty = 0 },    -- CANCELLED, ARMEDΓÇª (no pairing)

    --- Horizontal gap bar in bottom strip (full width)
    gap_bar_x_start = 0,
    gap_bar_x_end = 1.0,
    gap_bar_h_frac = 0.78,
    gap_label_fs = 14,

    --- Pantalla resultado ΓÇö "WIN Nombre" arriba, marcador abajo (sin solaparse)
    center_result_headline = { cx = 0, cy = 0.34, ty = 0 },
    center_result_score = { cx = 0, cy = 0.62, ty = 0 },
    --- center-result.png ΓÇö caja azul horizontal (si existe el asset)
    center_result_avatar = { cx = -200, cy = 0.60, ty = 4 },
    center_result_name = { cx = -50, cy = 0.60, ty = 4 },
    center_result_score_inline = { cx = 200, cy = 0.60, ty = 4 },

    --- Empate ΓÇö solo texto grande (sin PNG center_draw)
    center_draw_label = { cx = 0, cy = 0.36 },
    center_draw_score = { cx = 0, cy = 0.64 },

    result_avatar_size = 80,
    result_name_fs = 104,
    result_headline_fs = 88,
    result_score_fs = 128,
    draw_label_fs = 280,
    draw_score_fs = 180,

    name_fs = 105,
    car_fs = 94,
    score_fs = 190,
    score_vs_fs = 88,
    mode_fs = 72,
    cancel_label_fs = 112,
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

function M.battle_scale(panel_size)
    if panel_size == nil then return -1 end
    local pw = tonumber(panel_size.x) or tonumber(panel_size[-1]) or 0
    if pw <= 0 then return -1 end
    return pw / M.BATTLE_NATIVE.x
end

function M.battle_fit(win_size)
    local aspect = M.BATTLE_ASPECT
    
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
function M.battle_frame_fit(win_size, include_gap)
    if include_gap ~= true then
        local po, ps = M.battle_fit(win_size)
        return po, ps, 0, 0
    end

    local s = win_size.x / M.BATTLE_NATIVE.x
    local gap_margin = (M.BATTLE_GAP_MARGIN or 0) * s
    local gap_h = math.max((M.BATTLE_GAP_H or 58) * s, M.BATTLE_GAP_MIN_PX or 32)
    local bar_h = win_size.y - gap_margin - gap_h
    if bar_h < win_size.y * 0.52 then
        gap_h = math.max(gap_h, win_size.y * 0.34)
        bar_h = win_size.y - gap_margin - gap_h
    end
    local total_h = bar_h + gap_margin + gap_h
    local oy = 0
    if win_size.y > total_h then
        oy = (win_size.y - total_h) * 0.5
    end
    return vec2(0, oy), vec2(win_size.x, bar_h), gap_margin, gap_h
end

function M.battle_gap_rect(bar_origin, bar_size, gap_margin, gap_h, win_origin, win_size)
    local d = M.BATTLE_DESIGN
    local x0 = tonumber(d.gap_bar_x_start) or 0
    local x1 = tonumber(d.gap_bar_x_end) or 1.0
    if x1 < x0 then x0, x1 = x1, x0 end
    local base_o = win_origin or bar_origin
    local base_w = (win_size and win_size.x) or bar_size.x
    local gx = base_o.x + base_w * x0
    local gw = base_w * (x1 - x0)
    local gy = bar_origin.y + bar_size.y + gap_margin
    return vec2(gx, gy), vec2(gw, gap_h)
end

--- Convierte slot BATTLE_DESIGN ΓåÆ origen + tama├▒o en p├¡xeles de pantalla.
function M.battle_slot(panel_o, panel_size, slot)
    local s = M.battle_scale(panel_size)
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
function M.battle_point(panel_o, panel_size, slot)
    local s = M.battle_scale(panel_size)
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
function M.battle_center_rect(panel_o, panel_size, center_key)
    local d = M.BATTLE_DESIGN
    local o, sz = M.battle_slot(panel_o, panel_size, d.center)
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

--- C├¡rculo de foto de perfil (m├ís peque├▒o que el slot; margen superior v├¡a offset_y).
function M.battle_avatar_circle(panel_o, panel_size, side)
    local d = M.BATTLE_DESIGN
    local slot = side == "right" and d.right_avatar or d.left_avatar
    local av_o, av_sz = M.battle_slot(panel_o, panel_size, slot)
    local s = M.battle_scale(panel_size)
    local diam_native = tonumber(d.avatar_circle_size) or slot.w or slot.h or 442
    local size = math.max(4, math.floor(diam_native * s + 0.5))
    local ox = av_o.x + (av_sz.x - size) * 0.5
    local oy = av_o.y + (av_sz.y - size) * 0.5 + (tonumber(d.avatar_circle_offset_y) or 0) * s
    return vec2(ox, oy), size
end

--- Origen del chip tier+ELO dentro del c├¡rculo del avatar (esquina interior).
function M.battle_avatar_chip_origin(circle_o, circle_sz, side, chip_w, chip_h, scale)
    local d = M.BATTLE_DESIGN
    scale = scale or 1
    local h_inset = math.max((d.avatar_chip_inset or 12) * scale, circle_sz * 0.05)
    local bottom_inset = math.max((d.avatar_chip_bottom_inset or 4) * scale, circle_sz * 0.02)
    local y = circle_o.y + circle_sz - chip_h - bottom_inset
    if side == "right" then
        return vec2(circle_o.x + h_inset, y)
    end
    return vec2(circle_o.x + circle_sz - chip_w - h_inset, y)
end

--- Overlay looking: mismo tama├▒o/offset que battle_avatar_circle (perfil derecho).
function M.battle_searching_rect(panel_o, panel_size)
    local d = M.BATTLE_DESIGN
    local circle_o, circle_sz = M.battle_avatar_circle(panel_o, panel_size, "right")
    local native = d.searching_native or vec2(697, 442)
    local circle_w = math.max(1, d.searching_circle_w or 442)
    local scale = circle_sz / circle_w
    local nw = math.max(4, math.floor(native.x * scale + 0.5))
    local nh = math.max(4, math.floor(native.y * scale + 0.5))
    local ox = circle_o.x + circle_sz - nw
    local oy = circle_o.y + (circle_sz - nh) * 0.5
    return vec2(ox, oy), vec2(nw, nh)
end

--- Punto ancla para texto din├ímico del centro (ver comentario cx/cy/ty en BATTLE_DESIGN).
--- cx, ty: p├¡xeles nativos (3010) escalados; cy: fracci├│n 0..1 del alto del rect.
--- cx_frac: fracci├│n del ancho del rect (p. ej. center_points_score_* sobre PNG contain-fit).
--- content_o/content_sz opcionales: rect contain-fit del PNG (p. ej. center_points.png).
function M.battle_center_point(panel_o, panel_size, pt, content_o, content_sz)
    local d = M.BATTLE_DESIGN
    local c_o, c_sz
    if content_o ~= nil and content_sz ~= nil then
        c_o, c_sz = content_o, content_sz
    else
        c_o, c_sz = M.battle_slot(panel_o, panel_size, d.center)
    end
    local s = M.battle_scale(panel_size)
    local cx_off
    if pt.cx_frac ~= nil then
        cx_off = c_sz.x * pt.cx_frac
    else
        cx_off = (pt.cx or 0) * s
    end
    local cy_frac = pt.cy or 0.5
    local ty_off = (pt.ty or 0) * s
    return vec2(c_o.x + c_sz.x * 0.5 + cx_off, c_o.y + c_sz.y * cy_frac + ty_off)
end

function M.battle_metrics(panel_size)
    local s = M.battle_scale(panel_size)
    local d = M.BATTLE_DESIGN
    return {
        scale = s,
        name_fs = d.name_fs * s,
        car_fs = d.car_fs * s,
        score_fs = d.score_fs * s,
        score_vs_fs = d.score_vs_fs * s,
        mode_fs = d.mode_fs * s,
        cancel_label_fs = d.cancel_label_fs * s,
        countdown_fs = d.countdown_fs * s,
        role_fs = d.role_fs * s,
        hint_fs = d.hint_fs * s,
        distance_fs = d.distance_fs * s,
        gap_label_fs = d.gap_label_fs * s,
        event_fs = d.event_fs * s,
        tier_sz = d.tier_size * s,
        name_car_gap = d.name_car_gap * s,
        text_avatar_gap = d.text_avatar_gap * s,
        result_avatar_sz = d.result_avatar_size * s,
        result_name_fs = d.result_name_fs * s,
        result_headline_fs = d.result_headline_fs * s,
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

return M
