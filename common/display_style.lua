--[[ Display style — custom fonts, colors, and text effects (web parity v1) ]]

local theme = require("common.theme")
local profile = require("common.api.profile")

local M = {}

local app_dir = ac.dirname()
local FONT_DIR = "/fonts/display"

-- v1: letterSpacing fine tracking ignored; animated effects are static approximations.
-- Font ids match web DISPLAY_NAME_FONT_OPTIONS (ProjectD).
local FONT_REGISTRY = {
    rajdhani = { family = "Rajdhani", uppercase = true },
    orbitron = { family = "Orbitron", uppercase = true },
    bebas = { family = "Bebas Neue", uppercase = true, regular_only = true },
    minecraft_ten = { family = "Minecraft Ten", uppercase = false, regular_only = true },
    medievalsharp = { family = "MedievalSharp", uppercase = false, regular_only = true },
    cinzel = { family = "Cinzel", uppercase = true },
    permanent_marker = { family = "Permanent Marker", uppercase = false, regular_only = true },
    zen_kaku = { family = "Zen Kaku Gothic New", uppercase = false },
}

local WEIGHT_TO_DWRITE = {
    regular = "Regular",
    semibold = "SemiBold",
    bold = "Bold",
    black = "Black",
}

local font_cache = {} ---@type table<string, ui.DWriteFont>

local function cache_key(fontId, weight, italic)
    return tostring(fontId) .. "|" .. tostring(weight) .. "|" .. (italic and "1" or "0")
end

local function display_font_dir_exists()
    return io.fileExists(app_dir .. FONT_DIR .. "/Rajdhani-Bold.ttf")
        or io.fileExists(app_dir .. FONT_DIR .. "/Rajdhani-Regular.ttf")
end

function M.parse_hex_color(hex, fallback)
    fallback = fallback or rgbm(1, 1, 1, 1)
    if hex == nil or hex == "" then return fallback end
    hex = tostring(hex):gsub("^#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 then return fallback end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if r == nil or g == nil or b == nil then return fallback end
    return rgbm(r / 255, g / 255, b / 255, 1)
end

function M.resolve_font(fontId, weight, italic)
    theme.ensure_fonts()
    fontId = profile.normalize_display_style({ fontId = fontId }).fontId
    weight = weight or "bold"
    if type(weight) == "string" then
        weight = weight:lower()
    end
    italic = italic == true

    local key = cache_key(fontId, weight, italic)
    if font_cache[key] ~= nil then
        return font_cache[key]
    end

    local reg = FONT_REGISTRY[fontId] or FONT_REGISTRY.rajdhani
    if not display_font_dir_exists() then
        font_cache[key] = theme.fonts.bold
        return font_cache[key]
    end

    local dwrite_weight = WEIGHT_TO_DWRITE[weight] or "Bold"
    if reg.regular_only then
        dwrite_weight = "Regular"
    end

    local spec = reg.family .. ":" .. FONT_DIR .. ";Weight=" .. dwrite_weight
    if italic then
        spec = spec .. ";Italic"
    end

    local ok, font = pcall(ui.DWriteFont, spec)
    if not ok or font == nil then
        font_cache[key] = theme.fonts.bold
        return font_cache[key]
    end

    font_cache[key] = font
    return font
end

function M.resolve_style(display_style)
    local style = profile.normalize_display_style(display_style)
    local reg = FONT_REGISTRY[style.fontId] or FONT_REGISTRY.rajdhani
    local primary = M.parse_hex_color(style.color, rgbm(1, 1, 1, 1))
    local secondary = style.gradientColor ~= nil
        and M.parse_hex_color(style.gradientColor, primary)
        or primary

    return {
        fontId = style.fontId,
        effectId = style.effectId,
        weight = style.weight,
        italic = style.italic,
        letterSpacing = style.letterSpacing,
        uppercase = reg.uppercase == true,
        primary = primary,
        secondary = secondary,
        font = M.resolve_font(style.fontId, style.weight, style.italic),
    }
end

function M.format_name_for_style(text, style_or_resolved)
    text = tostring(text or "")
    local uppercase
    if style_or_resolved ~= nil and style_or_resolved.uppercase ~= nil then
        uppercase = style_or_resolved.uppercase
    else
        local resolved = M.resolve_style(style_or_resolved)
        uppercase = resolved.uppercase
    end
    if uppercase then
        return string.upper(text)
    end
    return text
end

function M.measure_styled_name(display_style, text, fs)
    local resolved = M.resolve_style(display_style)
    local formatted = M.format_name_for_style(text, resolved)
    fs = tonumber(fs) or 13

    ui.pushDWriteFont(resolved.font)
    local sz = ui.measureDWriteText(formatted, fs)
    ui.popDWriteFont()

    return sz, formatted, resolved
end

local function draw_text_pass(text, fs, pos, color, font)
    ui.pushDWriteFont(font)
    ui.dwriteDrawText(text, fs, pos, color)
    ui.popDWriteFont()
end

local function draw_with_clip(left, top, right, bottom, fn)
    if ui.pushClipRect ~= nil then
        ui.pushClipRect(vec2(left, top), vec2(right, bottom))
        fn()
        ui.popClipRect()
        return
    end
    fn()
end

local function draw_solid(text, fs, pos, color, font)
    draw_text_pass(text, fs, pos, color, font)
end

local function draw_gradient(text, fs, pos, left_color, right_color, font)
    ui.pushDWriteFont(font)
    local tw = ui.measureDWriteText(text, fs).x
    ui.popDWriteFont()

    local mid = pos.x + tw * 0.5
    draw_with_clip(pos.x, pos.y - fs, mid, pos.y + fs * 1.2, function()
        draw_text_pass(text, fs, pos, left_color, font)
    end)
    draw_with_clip(mid, pos.y - fs, pos.x + tw + 2, pos.y + fs * 1.2, function()
        draw_text_pass(text, fs, pos, right_color, font)
    end)
end

local function draw_taillight(text, fs, pos, fill_color, font)
    local glow = M.parse_hex_color("#FF4530", rgbm(1, 0.27, 0.19, 1))
    local offsets = {
        vec2(-1.5, 0), vec2(1.5, 0), vec2(0, -1), vec2(0, 1),
        vec2(-1, -1), vec2(1, 1),
    }
    for _, off in ipairs(offsets) do
        draw_text_pass(text, fs, pos + off, rgbm(glow.r, glow.g, glow.b, 0.55), font)
    end
    draw_text_pass(text, fs, pos, fill_color, font)
end

local function draw_chrome(text, fs, pos, font)
    draw_text_pass(text, fs, pos + vec2(0, 1.5), rgbm(0.12, 0.12, 0.14, 0.85), font)
    draw_text_pass(text, fs, pos, rgbm(0.88, 0.90, 0.94, 1), font)
end

local function draw_outline_fill(text, fs, pos, fill_color, font)
    local outline = rgbm(0, 0, 0, 0.92)
    local dirs = {
        vec2(-1, 0), vec2(1, 0), vec2(0, -1), vec2(0, 1),
        vec2(-1, -1), vec2(1, -1), vec2(-1, 1), vec2(1, 1),
    }
    for _, d in ipairs(dirs) do
        draw_text_pass(text, fs, pos + d, outline, font)
    end
    draw_text_pass(text, fs, pos, fill_color, font)
end

function M.draw_styled_name(display_style, text, pos, fs, color_override)
    if pos == nil then return end
    local normalized = profile.normalize_display_style(display_style)
    local resolved = M.resolve_style(normalized)
    local formatted = M.format_name_for_style(text, resolved)
    fs = tonumber(fs) or 13

    local primary = color_override or resolved.primary
    local effect = resolved.effectId or "solid"
    local font = resolved.font

    if effect == "gradient" and normalized.gradientColor ~= nil then
        draw_gradient(formatted, fs, pos, primary, resolved.secondary, font)
    elseif effect == "taillight" then
        draw_taillight(formatted, fs, pos, rgbm(1, 1, 1, 1), font)
    elseif effect == "chrome" then
        draw_chrome(formatted, fs, pos, font)
    elseif effect == "decal" or effect == "speed" then
        draw_outline_fill(formatted, fs, pos, primary, font)
    else
        draw_solid(formatted, fs, pos, primary, font)
    end
end

function M.truncate_name(display_style, text, fs, max_w)
    local _, formatted, resolved = M.measure_styled_name(display_style, text, fs)
    if max_w <= 0 then return "", fs, resolved.font end

    ui.pushDWriteFont(resolved.font)
    if ui.measureDWriteText(formatted, fs).x <= max_w then
        ui.popDWriteFont()
        return formatted, fs, resolved.font
    end
    local suffix = "…"
    local trimmed = formatted
    while #trimmed > 0 do
        trimmed = trimmed:sub(1, -2)
        if trimmed == "" then break end
        if ui.measureDWriteText(trimmed .. suffix, fs).x <= max_w then
            ui.popDWriteFont()
            return trimmed .. suffix, fs, resolved.font
        end
    end
    ui.popDWriteFont()
    return suffix, fs, resolved.font
end

return M
