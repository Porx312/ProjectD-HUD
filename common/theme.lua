--[[ ProjectD HUD — colores y tipografía ]]

local theme = {}

theme.colors = {
    white         = rgbm(1, 1, 1, 1),
    muted         = rgbm(0.55, 0.55, 0.58, 1),
    accent        = rgbm(0.35, 0.78, 1.0, 1),
    bg            = rgbm(0, 0, 0, 0.55),          -- top5 (panel plano)
    bg_card       = rgbm(0, 0, 0, 0.65),          -- profile/rival (CMRT gearbox)
    panel_overlay = rgbm(1, 1, 1, 1),             -- capa encima de panel_card
    leaderboard_overlay = rgbm(1, 1, 1, 1),       -- capa encima de leaderboard_panel
    panel_border  = rgbm(1, 1, 1, 0.06),
    leaderboard_sep = rgbm(1, 1, 1, 0.22),
    avatar_ring   = rgbm(1, 1, 1, 0.35),
    avatar_fill   = rgbm(0.12, 0.12, 0.15, 1),
    tier_fallback = rgbm(0.85, 0.15, 0.12, 1),
    rival_tag     = rgbm(0.82, 0.12, 0.10, 1),
    tab_active    = rgbm(0.35, 0.78, 1.0, 0.38),
    tab_idle      = rgbm(1, 1, 1, 0.08),
}

theme.fonts = {}
local fonts_ready = false

local function system_font(name)
    return ui.DWriteFont(name .. ":@System")
end

--- Bahnschrift en Windows; si no está, CSP hace fallback al sistema.
function theme.ensure_fonts()
    if fonts_ready then return end
    fonts_ready = true

    local family = "Bahnschrift"
    theme.fonts.bold   = system_font(family):weight(ui.DWriteFont.Weight.SemiBold)
    theme.fonts.medium = system_font(family):weight(ui.DWriteFont.Weight.SemiBold)
    theme.fonts.reg    = system_font(family)
    theme.fonts.small  = system_font(family)
end

function theme.format_lap(ms)
    if ms == nil or ms <= 0 then return "--:--.--" end
    local total_sec = ms / 1000
    local min = math.floor(total_sec / 60)
    local sec = total_sec - min * 60
    if min > 0 then
        return string.format("%d:%05.2f", min, sec)
    end
    return string.format("%.2f", sec)
end

--- Nombre corto para HUD (la API puede enviarlo ya recortado).
function theme.format_display_name(name, max_len)
    max_len = max_len or 10
    if name == nil or name == "" then return "?" end
    local first = name:match("^(%S+)") or name
    if #first > max_len then
        return first:sub(1, max_len)
    end
    return first
end

return theme
