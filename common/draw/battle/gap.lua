--[[ Battle HUD — horizontal gap bar with lateral opponent dot. ]]

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

local function compute_bar_layout(strip_o, strip_sz, m, d)
    local pad_x = math.max(4, 6 * m.scale)
    local label_fs = math.max(
        tonumber(d.gap_label_fs) or 14,
        11 * m.scale,
        strip_sz.y * 0.16
    )
    local you_fs = math.max(8, label_fs * 0.72)
    local meters_h = label_fs + math.max(3, 4 * m.scale)
    local you_h = you_fs + math.max(2, 3 * m.scale)
    local h_frac = tonumber(d.gap_bar_h_frac) or 0.68
    local bar_h = math.max(12, (strip_sz.y - meters_h - you_h) * h_frac)
    local bar_y = strip_o.y + you_h + math.max(0, (strip_sz.y - you_h - meters_h - bar_h) * 0.3)
    local bar_o = vec2(strip_o.x + pad_x, bar_y)
    local bar_sz = vec2(math.max(40, strip_sz.x - pad_x * 2), bar_h)
    return {
        bar_o = bar_o,
        bar_sz = bar_sz,
        label_fs = label_fs,
        you_fs = you_fs,
        meters_y = strip_o.y + strip_sz.y - meters_h * 0.35,
        you_y = strip_o.y + you_fs * 0.55,
    }
end

local function draw_horizontal_track(bar_o, bar_sz)
    local green = theme.colors.battle_gap_green
    local red = theme.colors.battle_gap_red
    local track = theme.colors.battle_gap_track
    local mid_x = bar_o.x + bar_sz.x * 0.5
    local red_mix = 0.75

    ui.drawRectFilled(
        bar_o - vec2(3, 3),
        bar_o + bar_sz + vec2(3, 3),
        rgbm(1, 1, 1, 0.05),
        CORNER + 2,
        layout.corners_all()
    )

    ui.drawRectFilled(bar_o, bar_o + bar_sz, track, CORNER, layout.corners_all())

    ui.drawRectFilled(
        bar_o,
        vec2(mid_x, bar_o.y + bar_sz.y),
        lerp_color(track, red, red_mix),
        CORNER,
        layout.corners_all()
    )
    ui.drawRectFilled(
        vec2(mid_x, bar_o.y),
        bar_o + bar_sz,
        lerp_color(track, red, red_mix),
        CORNER,
        layout.corners_all()
    )

    local cap_w = math.max(3, bar_sz.x * 0.015)
    ui.drawRectFilled(
        bar_o,
        vec2(bar_o.x + cap_w, bar_o.y + bar_sz.y),
        lerp_color(track, red, 0.92),
        CORNER,
        layout.corners_all()
    )
    ui.drawRectFilled(
        vec2(bar_o.x + bar_sz.x - cap_w, bar_o.y),
        bar_o + bar_sz,
        lerp_color(track, red, 0.92),
        CORNER,
        layout.corners_all()
    )

    local glow_w = math.max(8, bar_sz.x * 0.07)
    ui.drawRectFilled(
        vec2(mid_x - glow_w * 0.5, bar_o.y),
        vec2(mid_x + glow_w * 0.5, bar_o.y + bar_sz.y),
        lerp_color(track, green, 0.72),
        3,
        layout.corners_all()
    )
end

local function draw_you_marker(bar_o, bar_sz, you_y, you_fs)
    local cx = bar_o.x + bar_sz.x * 0.5
    local tick_h = bar_sz.y + math.max(5, 7)
    local tick_w = math.max(2.5, 3)
    ui.drawRectFilled(
        vec2(cx - tick_w * 0.5, bar_o.y + (bar_sz.y - tick_h) * 0.5),
        vec2(cx + tick_w * 0.5, bar_o.y + (bar_sz.y + tick_h) * 0.5),
        theme.colors.battle_gap_center
    )
    theme.ensure_fonts()
    draw_text.centered("YOU", you_fs, vec2(cx, you_y), theme.colors.muted, theme.fonts.bold)
end

local function opponent_dot_color(anim_state)
    if anim_state.closing then
        return theme.colors.battle_gap_closing
    end
    if math.abs(anim_state.velocity or 0) > 0.08 and not anim_state.closing then
        return theme.colors.battle_gap_opening
    end
    return theme.colors.battle_gap_opponent
end

local function draw_opponent_dot(bar_o, bar_sz, anim_state, m)
    local cx = bar_o.x + bar_sz.x * 0.5
    local cy = bar_o.y + bar_sz.y * 0.5
    local pad = math.max(5, 6 * m.scale)
    local travel = (bar_sz.x * 0.5 - pad) * 0.9
    local signed = anim_state.display_signed or 0
    local dot_x = cx + signed * travel

    local pulse = anim_state.pulse or 0
    local pill_h = bar_sz.y * (0.70 + pulse * 0.10)
    local pill_w = math.max(pill_h * 1.4, pill_h + 5 * m.scale)
    local color = opponent_dot_color(anim_state)

    ui.drawRectFilled(
        vec2(dot_x - pill_w * 0.5, cy - pill_h * 0.5),
        vec2(dot_x + pill_w * 0.5, cy + pill_h * 0.5),
        rgbm(color.r, color.g, color.b, math.min(1, color.mult * 0.4)),
        pill_h * 0.5,
        layout.corners_all()
    )
    ui.drawRectFilled(
        vec2(dot_x - pill_w * 0.5, cy - pill_h * 0.5),
        vec2(dot_x + pill_w * 0.5, cy + pill_h * 0.5),
        color,
        pill_h * 0.5,
        layout.corners_all()
    )
end

local function draw_meters_label(bar_o, bar_sz, gap_m, label_fs, meters_y)
    local cx = bar_o.x + bar_sz.x * 0.5
    local label = string.format("%dm", math.floor(gap_m + 0.5))
    theme.ensure_fonts()
    draw_text.centered(label, label_fs, vec2(cx, meters_y), theme.colors.white, theme.fonts.bold)
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

    local anim_state = gap_anim.tick(dt, signed, gap_max, opponent_ahead, battle.battle_id, gap_current)

    local strip_o, strip_sz = layout.battle_gap_rect(
        bar_origin, bar_size, gap_margin, gap_h, win_origin, win_size
    )
    local d = m.design or layout.BATTLE_DESIGN
    local L = compute_bar_layout(strip_o, strip_sz, m, d)

    draw_horizontal_track(L.bar_o, L.bar_sz)
    draw_you_marker(L.bar_o, L.bar_sz, L.you_y, L.you_fs)
    draw_opponent_dot(L.bar_o, L.bar_sz, anim_state, m)
    draw_meters_label(L.bar_o, L.bar_sz, anim_state.display_meters or gap_current, L.label_fs, L.meters_y)
end

return draw_battle_gap
