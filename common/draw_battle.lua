--[[ Battle HUD — bg + center PNG (matchmaking/countdown) + texto dinámico ]]

local theme = require("common.theme")
local layout = require("common.layout")
local images = require("common.images")

local draw_battle = {}

local PREP_LIVE = {
    arming = true,
    armed = true,
    launching = true,
    active = true,
}

local function measure_text(font, text, fs)
    ui.pushDWriteFont(font)
    local w = ui.measureDWriteText(text, fs).x
    ui.popDWriteFont()
    return w
end

local function profile_car_name(player)
    if player == nil then return "" end
    return theme.format_car_label(player.car_name, player.car_id)
end

local function draw_text_centered(text, fs, point, color, font)
    if text == nil or text == "" then return end
    font = font or theme.fonts.bold
    ui.pushDWriteFont(font)
    local w = measure_text(font, text, fs)
    ui.dwriteDrawText(text, fs, vec2(point.x - w * 0.5, point.y - fs * 0.52), color)
    ui.popDWriteFont()
end

local function draw_text_anchored(text, fs, point, anchor, color, font)
    if text == nil or text == "" then return end
    font = font or theme.fonts.bold
    ui.pushDWriteFont(font)
    local w = measure_text(font, text, fs)
    local x = point.x
    if anchor == "center" then
        x = point.x - w * 0.5
    elseif anchor == "right" then
        x = point.x - w
    end
    ui.dwriteDrawText(text, fs, vec2(x, point.y), color)
    ui.popDWriteFont()
end

local function battle_prep_state(battle)
    return string.lower(tostring(battle.prep_state or battle.state or "pairing"))
end

local function battle_has_battle_id(battle)
    local id = battle.battle_id
    return id ~= nil and tostring(id) ~= ""
end

local function battle_is_terminal(battle)
    local prep = battle_prep_state(battle)
    local display = string.lower(tostring(battle.state or prep))
    local status_name = string.lower(tostring(battle.status or ""))
    local is_draw = status_name == "draw"

    if display == "finished" or display == "cancelled" then
        return true, display, status_name, is_draw
    end
    if prep == "finished" or prep == "cancelled" then
        return true, prep, status_name, is_draw
    end
    if status_name == "finished" or status_name == "cancelled" or is_draw then
        if status_name == "cancelled" then
            return true, "cancelled", status_name, is_draw
        end
        return true, "finished", status_name, is_draw
    end
    return false, prep, status_name, is_draw
end

local function should_show_searching(battle)
    if battle.is_lobby == true then return true end
    if battle.looking_for_opponent ~= true then return false end
    if battle_has_battle_id(battle) then return false end
    local prep = battle_prep_state(battle)
    if PREP_LIVE[prep] == true then return false end
    return true
end

local function should_show_center_scores(battle, phase_state, is_terminal)
    if is_terminal then return false end
    if battle.show_scores == true then return true end
    if battle.show_prep_scores == true then return true end
    if phase_state == "active" then return true end
    return false
end

local function battle_placeholder()
    return {
        placeholder = true,
        name = "Looking for opponent",
        car_name = "",
        tier = 0,
    }
end

local function draw_avatar_circle(pos, url, size)
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

local function draw_tier_badge(pos, tier, tier_sz)
    images.draw_tier_badge(pos, tier, tier_sz)
end

function draw_battle.battle_panel(bar_origin, bar_size)
    local origin = bar_origin
    local ps = bar_size
    local br = origin + ps
    local d = layout.BATTLE_DESIGN

    local container = images.get_battle_container()
    local bg = images.get_battle_bg()

    if container ~= nil then
        local c_o, c_sz = layout.battle_slot(origin, ps, d.container)
        ui.drawImage(container, c_o, c_o + c_sz, rgbm(1, 1, 1, 1))
    end

    if bg ~= nil then
        local b_o, b_sz = layout.battle_slot(origin, ps, d.bg)
        ui.drawImage(bg, b_o, b_o + b_sz, rgbm(1, 1, 1, 1))
    elseif container == nil then
        ui.drawRectFilled(origin, br, theme.colors.battle_bg, 8, layout.corners_all())
        ui.drawRect(origin, br, theme.colors.battle_border, 8, layout.corners_all(), 1)
    end

    return vec2(0, 0), ps
end

local function draw_beside_avatar_text(avatar_o, aw, ah, side, name, car, m)
    local gap = m.text_avatar_gap
    local name_block = m.name_fs * 1.05
    local car_block = m.car_fs * 1.05
    local block_h = name_block + m.name_car_gap + car_block
    local top_y = avatar_o.y + ah * 0.5 - block_h * 0.5

    if side == "left" then
        local tx = avatar_o.x + aw + gap
        draw_text_anchored(name, m.name_fs, vec2(tx, top_y), "left", theme.colors.white, theme.fonts.bold)
        draw_text_anchored(
            car,
            m.car_fs,
            vec2(tx, top_y + name_block + m.name_car_gap),
            "left",
            theme.colors.rival_tag,
            theme.fonts.medium
        )
    else
        local tx = avatar_o.x - gap
        draw_text_anchored(name, m.name_fs, vec2(tx, top_y), "right", theme.colors.white, theme.fonts.bold)
        draw_text_anchored(
            car,
            m.car_fs,
            vec2(tx, top_y + name_block + m.name_car_gap),
            "right",
            theme.colors.rival_tag,
            theme.fonts.medium
        )
    end
end

local function format_elo_text(elo)
    local n = tonumber(elo)
    if n == nil or n <= 0 then return "—" end
    return tostring(math.floor(n + 0.5))
end

local function draw_avatar_stats_chip(circle_o, circle_sz, side, player, m)
    if circle_o == nil then return end
    theme.ensure_fonts()

    local tier = tonumber(player.tier) or 0
    local elo_text = format_elo_text(player.elo)
    local tier_sz = m.chip_tier_sz
    local elo_fs = m.chip_elo_fs
    local pad = m.chip_pad
    local gap = m.chip_inner_gap

    ui.pushDWriteFont(theme.fonts.medium)
    local elo_w = measure_text(theme.fonts.medium, elo_text, elo_fs)
    ui.popDWriteFont()

    local row_h = math.max(tier_sz, elo_fs)
    local chip_h = row_h + pad * 2
    local chip_w = pad + tier_sz + gap + elo_w + pad
    local chip_o = layout.battle_avatar_chip_origin(circle_o, circle_sz, side, chip_w, chip_h, m.scale)
    local radius = math.max(m.chip_radius, chip_h * 0.45)

    ui.drawRectFilled(
        chip_o,
        chip_o + vec2(chip_w, chip_h),
        rgbm(0, 0, 0, 0.85),
        radius,
        layout.corners_all()
    )

    local tier_y = pad + (row_h - tier_sz) * 0.5
    local elo_y = pad + (row_h - elo_fs) * 0.5

    draw_tier_badge(
        chip_o + vec2(pad, tier_y),
        tier,
        tier_sz
    )
    draw_text_anchored(
        elo_text,
        elo_fs,
        vec2(chip_o.x + pad + tier_sz + gap, chip_o.y + elo_y),
        "left",
        theme.colors.white,
        theme.fonts.medium
    )
end

local function battle_player_layer(panel_o, panel_size, player, side, m, d)
    theme.ensure_fonts()
    player = player or {}

    if player.placeholder == true then
        return
    end

    local avatar_slot = side == "left" and d.left_avatar or d.right_avatar
    layout.battle_slot(panel_o, panel_size, avatar_slot)

    local url = images.resolve_url(player.name, player.avatar_url)
    local circle_o, circle_sz = layout.battle_avatar_circle(panel_o, panel_size, side)
    draw_avatar_circle(circle_o, url, circle_sz)
    draw_avatar_stats_chip(circle_o, circle_sz, side, player, m)

    local name = theme.format_display_name(player.name)
    local car = profile_car_name(player)
    draw_beside_avatar_text(circle_o, circle_sz, circle_sz, side, name, car, m)
end

local function should_show_live_event_top(phase_state, is_terminal)
    if is_terminal then return false end
    return phase_state == "active" or phase_state == "armed" or phase_state == "launching"
end

local function util_safe_str(s)
    return tostring(s or "")
end

local function live_event_differs_from_center(event_label, center_text)
    if event_label == "" then return false end
    local upper_center = string.upper(util_safe_str(center_text))
    local upper_event = string.upper(event_label)
    if upper_event == upper_center then return false end
    if upper_center == "ACTIVE" and upper_event == "ACTIVE" then return false end
    return true
end

local function draw_phase_label_box(panel_o, panel_size, text, fs, pt, m)
    if text == nil or text == "" then return end
    theme.ensure_fonts()
    ui.pushDWriteFont(theme.fonts.bold)
    local tw = measure_text(theme.fonts.bold, text, fs)
    ui.popDWriteFont()

    local pad_x = math.max(6, 8 * m.scale)
    local pad_y = math.max(2, 3 * m.scale)
    local box_w = tw + pad_x * 2
    local box_h = fs + pad_y * 2
    local box_o = vec2(pt.x - box_w * 0.5, pt.y - box_h * 0.5)

    ui.drawRectFilled(box_o, box_o + vec2(box_w, box_h), theme.colors.battle_mode_bg, 4, layout.corners_all())
    draw_text_centered(text, fs, pt, theme.colors.white, theme.fonts.bold)
end

local function draw_top_event_banner(panel_o, panel_size, event_label, center_text, m, d, phase_state, is_terminal)
    if not should_show_live_event_top(phase_state, is_terminal) then return end
    if not live_event_differs_from_center(event_label, center_text) then return end

    local top_pt = layout.battle_center_point(panel_o, panel_size, d.center_event_top)
    local top_fs = math.max(m.hint_fs * 1.2, m.event_fs * 0.85, panel_size.y * 0.11)
    draw_phase_label_box(panel_o, panel_size, event_label, top_fs, top_pt, m)
end

local function phase_label_fs(phase_state, is_terminal, center_text, m, panel_size)
    if phase_state == "arming" then
        return math.max(m.countdown_fs, panel_size.y * 0.48)
    end
    if phase_state == "launching" then
        return math.max(m.countdown_fs * 0.85, panel_size.y * 0.4)
    end
    if is_terminal then
        local fs = math.min(m.mode_fs, math.max(m.event_fs, panel_size.y * 0.14))
        local len = #(center_text or "")
        if len > 22 then return fs * 0.85 end
        if len > 14 then return fs * 0.92 end
        return fs
    end
    return m.mode_fs
end

local function battle_center_image_key(battle, phase_state, is_terminal)
    if is_terminal then return nil end
    if battle.is_lobby == true or battle.looking_for_opponent == true then
        return "matchmaking"
    end
    if phase_state == "arming" or phase_state == "launching" then
        return "countdown"
    end
    local cd = tonumber(battle.arming_countdown)
    if phase_state == "pairing" and cd ~= nil and cd > 0 then
        return "countdown"
    end
    return nil
end

local function battle_center_image_layer(panel_o, panel_size, center_key)
    if center_key == nil or center_key == "" then return false end
    local tex = images.get_battle_center(center_key)
    if tex == nil then return false end
    local o, sz = layout.battle_center_rect(panel_o, panel_size, center_key)
    ui.drawImage(tex, o, o + sz, rgbm(1, 1, 1, 1))
    return true
end

local function countdown_overlay_label(battle, phase_state)
    local cd = tonumber(battle.arming_countdown)
    if cd ~= nil and cd >= 0 then
        if cd > 0 then return tostring(math.floor(cd + 0.5)) end
        if phase_state == "launching" then return "GO!" end
    end
    local center_text = tostring(battle.center_text or battle.mode or "")
    if center_text ~= "" and tonumber(center_text) ~= nil then
        return center_text
    end
    if center_text == "GO!" then return center_text end
    return ""
end

local function battle_center_text_block(panel_o, panel_size, battle, m, d, phase_state, is_terminal, is_draw, center_key, center_image_drawn)
    local center_text = tostring(battle.center_text or battle.mode or "")
    if center_text == "" and not is_terminal then
        center_text = string.upper(phase_state)
    end

    if not is_terminal and phase_state ~= "active" then
        if center_key == "countdown" then
            local label = countdown_overlay_label(battle, phase_state)
            if label ~= "" then
                local pt = layout.battle_center_point(panel_o, panel_size, d.center_countdown)
                local fs = phase_label_fs(phase_state, false, label, m, panel_size)
                if center_image_drawn == true then
                    draw_text_centered(label, fs, pt, theme.colors.white, theme.fonts.bold)
                else
                    draw_phase_label_box(panel_o, panel_size, label, fs, pt, m)
                end
            end
            local hint = tostring(battle.countdown_hint or "")
            if hint ~= "" and (phase_state == "arming" or phase_state == "armed") then
                local hpt = layout.battle_center_point(panel_o, panel_size, d.countdown_hint)
                draw_text_centered(hint, m.hint_fs, hpt, theme.colors.muted, theme.fonts.medium)
            end
        elseif center_key == "matchmaking" then
            if center_image_drawn ~= true then
                local pt = layout.battle_center_point(panel_o, panel_size, d.center_countdown)
                local label = center_text ~= "" and center_text or "LOOKING"
                draw_phase_label_box(panel_o, panel_size, label, m.mode_fs, pt, m)
            end
        else
            local pt = layout.battle_center_point(panel_o, panel_size, d.center_countdown)
            local fs = phase_label_fs(phase_state, false, center_text, m, panel_size)
            draw_phase_label_box(panel_o, panel_size, center_text, fs, pt, m)

            local hint = tostring(battle.countdown_hint or "")
            if hint ~= "" and (phase_state == "arming" or phase_state == "armed") then
                local hpt = layout.battle_center_point(panel_o, panel_size, d.countdown_hint)
                draw_text_centered(hint, m.hint_fs, hpt, theme.colors.muted, theme.fonts.medium)
            end
        end
    end

    if should_show_center_scores(battle, phase_state, is_terminal) then
        local sl = layout.battle_center_point(panel_o, panel_size, d.center_score_left)
        local sr = layout.battle_center_point(panel_o, panel_size, d.center_score_right)
        local vs_pt = layout.battle_center_point(panel_o, panel_size, d.center_score_vs)
        draw_text_centered(tostring(battle.score_left or 0), m.score_fs, sl, theme.colors.white, theme.fonts.bold)
        draw_text_centered("VS", m.score_vs_fs, vs_pt, theme.colors.battle_vs, theme.fonts.bold)
        draw_text_centered(tostring(battle.score_right or 0), m.score_fs, sr, theme.colors.white, theme.fonts.bold)
    end

    if phase_state == "active" and not is_terminal then
        local role = string.upper(tostring(battle.center_text or battle.mode or ""))
        if role ~= "" and role ~= "ACTIVE" then
            local rpt = layout.battle_center_point(panel_o, panel_size, d.center_role)
            draw_text_centered(role, m.role_fs, rpt, theme.colors.white, theme.fonts.bold)
        end
    end

    local event_label = tostring(battle.event_label or "")
    if event_label == "" and battle.end_label ~= nil then
        event_label = tostring(battle.end_label)
    end

    draw_top_event_banner(panel_o, panel_size, event_label, center_text, m, d, phase_state, is_terminal)

    if is_terminal and is_draw then
        local label_pt = layout.battle_center_point(panel_o, panel_size, d.center_draw_label)
        local score_pt = layout.battle_center_point(panel_o, panel_size, d.center_draw_score)
        draw_text_centered("DRAW", math.max(m.draw_label_fs, panel_size.y * 0.6), label_pt, theme.colors.white, theme.fonts.bold)
        draw_text_centered(
            string.format("%d-%d", tonumber(battle.score_left) or 0, tonumber(battle.score_right) or 0),
            math.max(m.draw_score_fs, panel_size.y * 0.36),
            score_pt,
            theme.colors.white,
            theme.fonts.bold
        )
        return
    end

    if is_terminal and phase_state == "finished" then
        local winner = tostring(battle.winner_name or "")
        if winner == "" and battle.winner_player ~= nil then
            winner = tostring(battle.winner_player.name or "")
        end
        if winner == "" then
            winner = center_text ~= "" and center_text or "WINNER"
        end
        local label_pt = layout.battle_center_point(panel_o, panel_size, d.center_draw_label)
        local score_pt = layout.battle_center_point(panel_o, panel_size, d.center_draw_score)
        draw_text_centered(winner, math.max(m.result_name_fs, panel_size.y * 0.36), label_pt, theme.colors.white, theme.fonts.bold)
        draw_text_centered(
            tostring(battle.final_score_text or string.format("%d-%d", tonumber(battle.score_left) or 0, tonumber(battle.score_right) or 0)),
            math.max(m.result_score_fs, panel_size.y * 0.30),
            score_pt,
            theme.colors.white,
            theme.fonts.bold
        )
        return
    elseif is_terminal and phase_state == "cancelled" then
        local msg = event_label ~= "" and event_label or center_text
        if msg == "" then msg = "CANCELLED" end
        local pt = layout.battle_center_point(panel_o, panel_size, d.center_draw_label)
        draw_text_centered(msg, math.max(m.event_fs * 2, panel_size.y * 0.32), pt, theme.colors.accent, theme.fonts.bold)
    end
end

local function battle_searching_layer(panel_o, panel_size, show)
    if not show then return end
    local tex = images.get_battle_searching_overlay()
    if tex == nil then return end
    local origin, size = layout.battle_searching_rect(panel_o, panel_size)
    ui.drawImage(tex, origin, origin + size, rgbm(1, 1, 1, 1))
end

local function draw_pill_bar(tl, size, color)
    if size.x <= 2 or size.y <= 2 then return end
    local radius = math.min(size.y * 0.5, size.x * 0.5)
    local left_center = tl + vec2(radius, radius)
    local right_center = tl + vec2(size.x - radius, radius)
    ui.pathClear()
    ui.pathArcTo(left_center, radius, math.pi / 2, math.pi * 3 / 2, 16)
    ui.pathArcTo(right_center, radius, -math.pi / 2, math.pi / 2, 16)
    ui.pathFillConvex(color)
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
    local shadow = rgbm(0, 0, 0, 0.72)
    local offset = math.max(1, fs * 0.04)
    draw_text_centered(text, fs, point + vec2(offset, offset), shadow, font)
    draw_text_centered(text, fs, point, theme.colors.white, font)
end

local function battle_gap_layer(bar_origin, bar_size, gap_margin, gap_h, battle, m)
    if battle.show_gap ~= true or gap_h <= 0 then return end

    local gap = battle.gap or {}
    local gap_current = math.max(0, tonumber(gap.current or battle.gap3d_m) or 0)
    local gap_max = math.max(1, tonumber(gap.max or battle.disappear_gap_m) or 250)
    local gap_ratio = math.min(1, gap_current / gap_max)

    local origin, size = layout.battle_gap_rect(bar_origin, bar_size, gap_margin, gap_h)
    local d = m.design or layout.BATTLE_DESIGN
    local pad = math.max(1, (tonumber(d.gap_bar_pad) or 2) * m.scale)

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
                draw_pill_bar(
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
            draw_pill_bar(
                origin + vec2(pad, pad),
                vec2(size.x - pad * 2, size.y - pad * 2),
                gap_fill_color(gap_ratio)
            )
            ui.popClipRect()
        end
    else
        draw_pill_bar(origin, size, theme.colors.battle_gap_track)
        if gap_ratio > 0 then
            local inner = vec2(size.x - pad * 2, size.y - pad * 2)
            local fill_w = math.max(2, inner.x * gap_ratio)
            ui.pushClipRect(origin, origin + vec2(pad + fill_w + pad, size.y))
            draw_pill_bar(origin + vec2(pad, pad), inner, gap_fill_color(gap_ratio))
            ui.popClipRect()
        end
    end

    local label = string.format("%dm / %dm", math.floor(gap_current + 0.5), math.floor(gap_max + 0.5))
    local label_fs = math.max(m.distance_fs, size.y * 0.42)
    draw_gap_label(label, label_fs, vec2(origin.x + size.x * 0.5, origin.y + size.y * 0.5))
end

function draw_battle.battle_block(panel_o, panel_size, battle, opts)
    theme.ensure_fonts()
    battle = battle or {}
    opts = opts or {}
    local m = layout.battle_metrics(panel_size)
    local d = layout.BATTLE_DESIGN

    local is_terminal, terminal_state, status_name, is_draw = battle_is_terminal(battle)
    local phase_state = battle_prep_state(battle)
    if is_terminal then
        phase_state = terminal_state
    end

    local left = battle.player_left or {}
    local right = battle.player_right or battle_placeholder()
    local right_placeholder = right.placeholder == true

    local center_key = battle_center_image_key(battle, phase_state, is_terminal)
    local center_image_drawn = battle_center_image_layer(panel_o, panel_size, center_key)

    battle_player_layer(panel_o, panel_size, left, "left", m, d)
    if not right_placeholder then
        battle_player_layer(panel_o, panel_size, right, "right", m, d)
    end

    battle_center_text_block(panel_o, panel_size, battle, m, d, phase_state, is_terminal, is_draw, center_key, center_image_drawn)
    battle_searching_layer(panel_o, panel_size, should_show_searching(battle))
    battle_gap_layer(
        panel_o,
        panel_size,
        tonumber(opts.gap_margin) or 0,
        tonumber(opts.gap_h) or 0,
        battle,
        m
    )
end

return draw_battle
