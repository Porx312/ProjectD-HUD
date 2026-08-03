--[[ Battle HUD — center PNG, countdown, scores, terminal screens. ]]

local theme = require("common.theme")
local layout = require("common.layout")
local images = require("common.images")
local draw_text = require("common.draw_text")

local draw_battle_center = {}

local function clamp_result_fs(base_fs, panel_h, min_frac, max_frac)
    local min_fs = math.max(11, panel_h * min_frac)
    local max_fs = math.max(min_fs + 1, panel_h * max_frac)
    return math.min(math.max(base_fs, min_fs), max_fs)
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

local function draw_phase_label_box(panel_o, panel_size, text, fs, pt, m)
    if text == nil or text == "" then return end
    theme.ensure_fonts()
    ui.pushDWriteFont(theme.fonts.bold)
    local tw = draw_text.measure(theme.fonts.bold, text, fs)
    ui.popDWriteFont()

    local pad_x = math.max(6, 8 * m.scale)
    local pad_y = math.max(2, 3 * m.scale)
    local box_w = tw + pad_x * 2
    local box_h = fs + pad_y * 2
    local box_o = vec2(pt.x - box_w * 0.5, pt.y - box_h * 0.5)

    ui.drawRectFilled(box_o, box_o + vec2(box_w, box_h), theme.colors.battle_mode_bg, 4, layout.corners_all())
    draw_text.centered(text, fs, pt, theme.colors.white, theme.fonts.bold)
end

local function draw_top_event_banner(panel_o, panel_size, event_label, center_text, m, d)
    if not draw_text.live_event_differs_from_center(event_label, center_text) then return end
    local top_pt = layout.battle_center_point(panel_o, panel_size, d.center_event_top)
    local top_fs = math.max(m.hint_fs * 1.2, m.event_fs * 0.85, panel_size.y * 0.11)
    draw_phase_label_box(panel_o, panel_size, event_label, top_fs, top_pt, m)
end

local function draw_center_points_event(panel_o, panel_size, event_label, center_text, m, d, content_o, content_sz)
    if event_label == "" then return end
    if not draw_text.live_event_differs_from_center(event_label, center_text) then return end
    local pt = layout.battle_center_point(panel_o, panel_size, d.center_points_event, content_o, content_sz)
    local fs = math.max(m.event_fs, panel_size.y * 0.10)
    draw_text.centered(event_label, fs, pt, theme.colors.white, theme.fonts.bold)
end

function draw_battle_center.draw_center_image(panel_o, panel_size, center_key)
    if center_key == nil or center_key == "" then return false, nil, nil end
    local tex = images.get_battle_center(center_key)
    if tex == nil then return false, nil, nil end
    local slot_o, slot_sz = layout.battle_center_rect(panel_o, panel_size, center_key)
    local draw_o, draw_sz = images.contain_rect(slot_o, slot_sz, tex)
    ui.drawImage(tex, draw_o, draw_o + draw_sz, rgbm(1, 1, 1, 1))
    return true, draw_o, draw_sz
end

local function draw_finished_result_center(panel_o, panel_size, battle, display, m, d, content_o, content_sz)
    local winner = display.winner_display_name
    if winner == "" then winner = "WINNER" end
    winner = theme.format_display_name(winner)

    local score_text = tostring(
        battle.final_score_text
            or string.format("%d-%d", tonumber(battle.score_left) or 0, tonumber(battle.score_right) or 0)
    )

    local headline_pt = layout.battle_center_point(panel_o, panel_size, d.center_result_headline, content_o, content_sz)
    local score_pt = layout.battle_center_point(panel_o, panel_size, d.center_result_score, content_o, content_sz)

    local headline_fs = clamp_result_fs(m.result_headline_fs, panel_size.y, 0.16, 0.24)
    local score_fs = clamp_result_fs(m.result_score_fs, panel_size.y, 0.14, 0.22)

    draw_text.centered("WIN " .. winner, headline_fs, headline_pt, theme.colors.battle_vs, theme.fonts.bold)
    draw_text.centered(score_text, score_fs, score_pt, theme.colors.white, theme.fonts.bold)
end

function draw_battle_center.draw_block(
    panel_o,
    panel_size,
    battle,
    display,
    m,
    d,
    center_key,
    center_image_drawn,
    center_content_o,
    center_content_sz
)
    local phase_state = display.phase_state
    local is_terminal = display.is_terminal
    local is_draw = display.is_draw
    local center_text = display.center_text

    if is_terminal and phase_state == "finished" then
        draw_finished_result_center(panel_o, panel_size, battle, display, m, d, center_content_o, center_content_sz)
        return
    end

    if is_terminal and is_draw then
        local label_pt = layout.battle_center_point(panel_o, panel_size, d.center_draw_label, center_content_o, center_content_sz)
        local score_pt = layout.battle_center_point(panel_o, panel_size, d.center_draw_score, center_content_o, center_content_sz)
        local label_fs = clamp_result_fs(m.draw_label_fs, panel_size.y, 0.22, 0.32)
        local score_fs = clamp_result_fs(m.draw_score_fs, panel_size.y, 0.14, 0.22)
        draw_text.centered("DRAW", label_fs, label_pt, theme.colors.white, theme.fonts.bold)
        draw_text.centered(
            string.format("%d-%d", tonumber(battle.score_left) or 0, tonumber(battle.score_right) or 0),
            score_fs,
            score_pt,
            theme.colors.white,
            theme.fonts.bold
        )
        return
    end

    if is_terminal and phase_state == "cancelled" then
        local event_label = tostring(battle.event_label or "")
        if event_label == "" and battle.end_label ~= nil then
            event_label = tostring(battle.end_label)
        end
        local msg = event_label ~= "" and event_label or center_text
        if msg == "" then msg = "CANCELLED" end
        local pt = layout.battle_center_point(panel_o, panel_size, d.center_phase_label)
        local fs = clamp_result_fs(m.cancel_label_fs, panel_size.y, 0.22, 0.36)
        draw_text.centered(msg, fs, pt, theme.colors.accent, theme.fonts.bold)
        return
    end

    if not is_terminal and phase_state ~= "active" then
        if center_key == "countdown" then
            local label = display.center_label
            if label ~= "" then
                local pt = layout.battle_center_point(panel_o, panel_size, d.center_countdown)
                local fs = phase_label_fs(phase_state, false, label, m, panel_size)
                if center_image_drawn == true then
                    draw_text.centered(label, fs, pt, theme.colors.white, theme.fonts.bold)
                else
                    draw_phase_label_box(panel_o, panel_size, label, fs, pt, m)
                end
            end
            if display.show_countdown_hint then
                local hpt = layout.battle_center_point(panel_o, panel_size, d.countdown_hint)
                draw_text.centered(battle.countdown_hint, m.hint_fs, hpt, theme.colors.muted, theme.fonts.medium)
            end
        elseif center_key == "matchmaking" then
            if center_image_drawn ~= true then
                local pt = layout.battle_center_point(panel_o, panel_size, d.center_phase_label)
                local label = center_text ~= "" and center_text or "LOOKING"
                draw_phase_label_box(panel_o, panel_size, label, m.mode_fs, pt, m)
            end
        else
            if display.show_phase_label then
                local label = center_text ~= "" and center_text or string.upper(phase_state)
                local pt = layout.battle_center_point(panel_o, panel_size, d.center_phase_label)
                local fs = phase_label_fs(phase_state, false, label, m, panel_size)
                draw_phase_label_box(panel_o, panel_size, label, fs, pt, m)
            end

            if display.show_countdown_hint then
                local hpt = layout.battle_center_point(panel_o, panel_size, d.countdown_hint)
                draw_text.centered(battle.countdown_hint, m.hint_fs, hpt, theme.colors.muted, theme.fonts.medium)
            end
        end
    end

    local points_layout = center_key == "points" and center_image_drawn == true
    local points_content_o = points_layout and center_content_o or nil
    local points_content_sz = points_layout and center_content_sz or nil

    if display.show_center_scores then
        if points_layout then
            local sl = layout.battle_center_point(panel_o, panel_size, d.center_points_score_left, points_content_o, points_content_sz)
            local sr = layout.battle_center_point(panel_o, panel_size, d.center_points_score_right, points_content_o, points_content_sz)
            draw_text.centered(tostring(battle.score_left or 0), m.score_fs, sl, theme.colors.white, theme.fonts.bold)
            draw_text.centered(tostring(battle.score_right or 0), m.score_fs, sr, theme.colors.white, theme.fonts.bold)
        else
            local sl = layout.battle_center_point(panel_o, panel_size, d.center_score_left)
            local sr = layout.battle_center_point(panel_o, panel_size, d.center_score_right)
            local vs_pt = layout.battle_center_point(panel_o, panel_size, d.center_score_vs)
            draw_text.centered(tostring(battle.score_left or 0), m.score_fs, sl, theme.colors.white, theme.fonts.bold)
            draw_text.centered("VS", m.score_vs_fs, vs_pt, theme.colors.battle_vs, theme.fonts.bold)
            draw_text.centered(tostring(battle.score_right or 0), m.score_fs, sr, theme.colors.white, theme.fonts.bold)
        end
    end

    if phase_state == "active" and not is_terminal then
        local role = string.upper(tostring(battle.center_text or battle.mode or ""))
        if role ~= "" and role ~= "ACTIVE" then
            local role_pt = points_layout and d.center_points_role or d.center_role
            local rpt = layout.battle_center_point(panel_o, panel_size, role_pt, points_content_o, points_content_sz)
            draw_text.centered(role, m.role_fs, rpt, theme.colors.white, theme.fonts.bold)
        end
    end

    local event_label = tostring(battle.event_label or "")
    if event_label == "" and battle.end_label ~= nil then
        event_label = tostring(battle.end_label)
    end

    if points_layout then
        draw_center_points_event(panel_o, panel_size, event_label, center_text, m, d, points_content_o, points_content_sz)
    elseif display.show_live_event_top then
        draw_top_event_banner(panel_o, panel_size, event_label, center_text, m, d)
    end
end

return draw_battle_center
