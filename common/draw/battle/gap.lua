--[[ Battle HUD — 3D gap bar below the main battle panel. ]]

local theme = require("common.theme")
local layout = require("common.layout")
local images = require("common.images")
local draw_text = require("common.draw_text")

local draw_battle_gap = {}

local function draw_rect_bar(tl, size, color)
    if size.x <= 0 or size.y <= 0 then return end
    ui.drawRectFilled(tl, tl + size, color)
end

local function gap_fill_color(ratio)
    ratio = math.max(0, math.min(1, ratio))
    local safe = theme.colors.battle_gap_safe or rgbm(0.18, 0.72, 0.38, 0.95)
    local danger = theme.colors.battle_gap_fill
    local t = ratio * ratio
    return rgbm(
        safe.r + (danger.r - safe.r) * t,
        safe.g + (danger.g - safe.g) * t,
        safe.b + (danger.b - safe.b) * t,
        safe.mult + (danger.mult - safe.mult) * t
    )
end

local function draw_gap_label(text, fs, point)
    theme.ensure_fonts()
    local font = theme.fonts.bold
    local shadow = rgbm(0, 0, 0, 0.88)
    local offset = math.max(1, fs * 0.07)
    draw_text.centered(text, fs, point + vec2(offset, offset), shadow, font)
    draw_text.centered(text, fs, point + vec2(-offset * 0.6, offset * 0.6), shadow, font)
    draw_text.centered(text, fs, point, rgbm(1, 1, 1, 1), font)
end

function draw_battle_gap.draw_layer(bar_origin, bar_size, gap_margin, gap_h, battle, m, win_origin, win_size)
    if battle.show_gap ~= true or gap_h <= 0 then return end

    local gap = battle.gap or {}
    local gap_current = math.max(0, tonumber(gap.current or battle.gap3d_m) or 0)
    local gap_max = math.max(1, tonumber(gap.max or battle.disappear_gap_m) or 250)
    local gap_ratio = math.min(1, gap_current / gap_max)

    local origin, size = layout.battle_gap_rect(bar_origin, bar_size, gap_margin, gap_h, win_origin, win_size)
    local d = m.design or layout.BATTLE_DESIGN
    local pad = math.max(0, (tonumber(d.gap_bar_pad) or 0) * m.scale)

    local bar_asset = images.get_battle_gap_bar()
    local track = images.get_battle_gap_track()
    local fill_tex = images.get_battle_gap_fill()

    if bar_asset ~= nil then
        ui.drawImage(bar_asset, origin, origin + size, rgbm(1, 1, 1, 1))
        if gap_ratio > 0 then
            local fill_w = math.max(4, size.x * gap_ratio)
            ui.pushClipRect(origin, origin + vec2(fill_w, size.y))
            if fill_tex ~= nil then
                ui.drawImage(fill_tex, origin, origin + size, rgbm(1, 1, 1, 1))
            else
                draw_rect_bar(
                    origin + vec2(pad, pad),
                    vec2(size.x - pad * 2, size.y - pad * 2),
                    gap_fill_color(gap_ratio)
                )
            end
            ui.popClipRect()
        end
    elseif track ~= nil then
        ui.drawImage(track, origin, origin + size, rgbm(1, 1, 1, 1))
        if fill_tex ~= nil and gap_ratio > 0 then
            local fill_w = math.max(4, size.x * gap_ratio)
            ui.drawImage(fill_tex, origin, vec2(origin.x + fill_w, origin.y + size.y), rgbm(1, 1, 1, 1))
        elseif gap_ratio > 0 then
            local fill_w = math.max(4, size.x * gap_ratio)
            ui.pushClipRect(origin, origin + vec2(fill_w, size.y))
            draw_rect_bar(
                origin + vec2(pad, pad),
                vec2(size.x - pad * 2, size.y - pad * 2),
                gap_fill_color(gap_ratio)
            )
            ui.popClipRect()
        end
    else
        draw_rect_bar(origin, size, theme.colors.battle_gap_track)
        if gap_ratio > 0 then
            local inner = vec2(size.x - pad * 2, size.y - pad * 2)
            local fill_w = math.max(2, inner.x * gap_ratio)
            ui.pushClipRect(origin, origin + vec2(pad + fill_w + pad, size.y))
            draw_rect_bar(origin + vec2(pad, pad), vec2(fill_w, inner.y), gap_fill_color(gap_ratio))
            ui.popClipRect()
        end
    end

    local label = string.format("%dm / %dm", math.floor(gap_current + 0.5), math.floor(gap_max + 0.5))
    local label_fs = math.max(m.gap_label_fs or 0, m.distance_fs * 1.4, size.y * 0.62, 13)
    draw_gap_label(label, label_fs, vec2(origin.x + size.x * 0.5, origin.y + size.y * 0.5))
end

return draw_battle_gap
