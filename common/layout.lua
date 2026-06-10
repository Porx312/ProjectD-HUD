--[[ Tamaños fijos — sin auto-scale (FIXED_SIZE en manifest) ]]

local layout = {}

layout.PAD_TOP5 = 10
layout.ROW_H = 40
layout.CARD_EDGE_PAD = 4
layout.AVATAR_Y_EXTRA = 2

--- panel_card.png — proporción real del asset (sin estirar).
layout.PANEL_NATIVE = vec2(1795, 533.17)
layout.PANEL_ASPECT = layout.PANEL_NATIVE.x / layout.PANEL_NATIVE.y

--- Medidas del mock (canvas 1795×533); se escalan con el panel en pista.
layout.PROFILE_DESIGN = {
    avatar = 465.7,
    name_fs = 152,
    sub_fs = 124,
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
    top5    = vec2(300, 256),
    profile = vec2(280, 84),
    rival   = vec2(280, 84),
}

--- Rect del panel dentro de la ventana: misma proporción que el PNG, centrado.
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

function layout.corners_all()
    return 15
end

return layout
