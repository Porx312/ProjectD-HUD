--[[ Draw — shared UI primitives ]]

local theme = require("common.theme")
local images = require("common.images")
local layout = require("common.layout")
local draw_text = require("common.draw_text")

local M = {}

function M.measure_text(font, text, size)
    return draw_text.measure(font, text, size)
end

function M.measure_dwrite(font, text, size)
    return draw_text.measure_size(font, text, size)
end

function M.flat_panel(origin, size)
    ui.drawRectFilled(origin, origin + size, theme.colors.bg, 6, layout.corners_all())
end

function M.car_filter_combo(origin, width, filters, selected_id)
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

function M.card_panel(win_origin, win_size)
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

function M.center_status_message(origin, size, text, opts)
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

-- Frame overlay alignment (web FrameAvatar.tsx parity).
local FRAME_DRAW_SIZE_RATIO = 1.794   -- 138% * scale 1.3
local FRAME_CENTER_X_RATIO = 0.5
local FRAME_CENTER_Y_RATIO = 0.3885   -- ~11% above avatar vertical center

local function draw_frame_overlay(pos, size, frame_url)
    if frame_url == nil or frame_url == "" then return end
    local tex = images.get_frame(frame_url)
    if tex == nil then return end

    local draw_size = size * FRAME_DRAW_SIZE_RATIO
    local center = vec2(
        pos.x + size * FRAME_CENTER_X_RATIO,
        pos.y + size * FRAME_CENTER_Y_RATIO
    )
    local slot_o = center - vec2(draw_size * 0.5, draw_size * 0.5)
    local slot_sz = vec2(draw_size, draw_size)
    local draw_o, draw_wh = images.contain_rect(slot_o, slot_sz, tex)
    ui.drawImage(tex, draw_o, draw_o + draw_wh, theme.colors.white)
end

function M.avatar_circle(pos, url, size, ring_color)
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
        local tw = M.measure_text(theme.fonts.bold, initial, fs)
        ui.dwriteDrawText(initial, fs, center - vec2(tw * 0.5, fs * 0.52), theme.colors.muted)
        ui.popDWriteFont()
    end

    local ring = ring_color or theme.colors.avatar_ring
    ui.drawCircle(center, radius, ring, segs, math.max(1.5, size * 0.028))
end

function M.avatar_with_frame(pos, avatar_url, frame_url, size, ring_color)
    M.avatar_circle(pos, avatar_url, size, ring_color)
    draw_frame_overlay(pos, size, frame_url)
end

function M.avatar_with_tier(pos, url, size, tier, ring_color, tier_sz, frame_url)
    if pos == nil then return end
    size = math.max(4, math.floor(tonumber(size) or 32) + 0.5)
    tier_sz = math.max(8, math.floor(tonumber(tier_sz) or size * 0.44))
    M.avatar_with_frame(pos, url, frame_url, size, ring_color)
    local tier_x = pos.x + (size - tier_sz) * 0.5
    local tier_y = pos.y + size - tier_sz * 0.72
    M.tier_badge(vec2(tier_x, tier_y), tier, tier_sz)
end

function M.tier_badge(pos, tier, tier_sz)
    images.draw_tier_badge(pos, tier, tier_sz)
end

function M.truncate_text(text, font, fs, max_w)
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

return M
