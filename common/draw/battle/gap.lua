--[[ Battle HUD — vertical distance indicator in the bottom gap strip. ]]

local theme = require("common.theme")
local layout = require("common.layout")
local draw_text = require("common.draw_text")
local gap_anim = require("common.battle.gap_anim")

local draw_battle_gap = {}

local CORNER = 6

local function lerp_color(a, b, t)
    t = math.max(0, math.min(1, t))
    return rgbm(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        a.mult + (b.mult - a.mult) * t
    )
end

local function draw_vertical_gradient_track(origin, size)
    local green = theme.colors.battle_gap_green
    local red = theme.colors.battle_gap_red
    local track = theme.colors.battle_gap_track
    local half_h = size.y * 0.5
    local center_y = origin.y + half_h

    ui.drawRectFilled(
        origin - vec2(2, 2),
        origin + size + vec2(2, 2),
        rgbm(1, 1, 1, 0.04),
        CORNER + 2,
        layout.corners_all()
    )

    ui.drawRectFilled(origin, origin + size, track, CORNER, layout.corners_all())

    local top_o = origin
    local top_sz = vec2(size.x, half_h)
    local bot_o = vec2(origin.x, center_y)
    local bot_sz = vec2(size.x, half_h)

    ui.drawRectFilled(top_o, top_o + top_sz, lerp_color(track, red, 0.55), CORNER, layout.corners_all())
    ui.drawRectFilled(bot_o, bot_o + bot_sz, lerp_color(track, green, 0.55), CORNER, layout.corners_all())
end

local function draw_center_marker(origin, size, fs, m)
    local cx = origin.x + size.x * 0.5
    local cy = origin.y + size.y * 0.5
    local tick_w = math.max(10, size.x * 0.85)
    local tick_h = math.max(1.5, 2 * m.scale)
    ui.drawRectFilled(
        vec2(cx - tick_w * 0.5, cy - tick_h * 0.5),
        vec2(cx + tick_w * 0.5, cy + tick_h * 0.5),
        theme.colors.battle_gap_center
    )
    theme.ensure_fonts()
    local label_fs = math.max(8, fs * 0.72)
    draw_text.centered("YOU", label_fs, vec2(cx, cy + label_fs * 0.85), theme.colors.muted, theme.fonts.bold)
end

local function opponent_arrow_color(anim_state)
    if anim_state.closing then
        return theme.colors.battle_gap_closing
    end
    if math.abs(anim_state.velocity or 0) > 0.08 and not anim_state.closing then
        return theme.colors.battle_gap_opening
    end
    return theme.colors.battle_gap_opponent
end

local function draw_opponent_arrow(origin, size, anim_state, arrow_fs, m)
    local cx = origin.x + size.x * 0.5
    local cy = origin.y + size.y * 0.5
    local travel = size.y * 0.45
    local signed = anim_state.display_signed or 0
    local arrow_y = cy - signed * travel

    local pulse = anim_state.pulse or 0
    local scale = 1 + pulse * 0.12
    local fs = arrow_fs * scale
    local color = opponent_arrow_color(anim_state)
    local glyph = "▲"
    if signed < -0.001 then
        glyph = "▼"
    end

    theme.ensure_fonts()
    draw_text.centered(glyph, fs, vec2(cx, arrow_y), color, theme.fonts.bold)
end

local function draw_meters_label(origin, size, gap_m, fs, m)
    local cx = origin.x + size.x * 0.5
    local label_y = origin.y + size.y + math.max(4, 5 * m.scale)
    local label = string.format("%dm", math.floor(gap_m + 0.5))
    theme.ensure_fonts()
    draw_text.centered(label, fs, vec2(cx, label_y), theme.colors.white, theme.fonts.bold)
end

function draw_battle_gap.draw_layer(bar_origin, bar_size, gap_margin, gap_h, battle, m, win_origin, win_size, dt)
    if battle.show_gap ~= true or gap_h <= 0 then
        gap_anim.reset()
        return
    end

    dt = tonumber(dt) or 0

    local gap = battle.gap or {}
    local gap_current = math.max(0, tonumber(gap.current or battle.gap3d_m) or 0)
    local gap_max = math.max(1, tonumber(gap.max or battle.disappear_gap_m) or 250)
    local signed = tonumber(gap.signed)
    if signed == nil then signed = 0 end
    local opponent_ahead = gap.opponent_ahead

    local anim_state = gap_anim.tick(dt, signed, gap_max, opponent_ahead, battle.battle_id)

    local origin, size = layout.battle_gap_indicator_rect(
        bar_origin, bar_size, gap_margin, gap_h, win_origin, win_size, m.scale
    )
    local d = m.design or layout.BATTLE_DESIGN
    local label_fs = math.max(
        tonumber(d.gap_label_fs) or 14,
        11 * m.scale,
        size.y * 0.14
    )
    local arrow_fs = math.max(label_fs * 1.35, size.x * 0.95, 14)

    draw_vertical_gradient_track(origin, size)
    draw_center_marker(origin, size, label_fs, m)
    draw_opponent_arrow(origin, size, anim_state, arrow_fs, m)
    draw_meters_label(origin, size, gap_current, label_fs, m)
end

return draw_battle_gap
