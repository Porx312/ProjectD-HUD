--[[ ProjectD HUD — colores y tipografía (mismas fuentes que CMRT Essential HUD) ]]

local theme = {}

theme.colors = {
    white         = rgbm(1, 1, 1, 1),
    muted         = rgbm(0.55, 0.55, 0.58, 1),
    accent        = rgbm(0.35, 0.78, 1.0, 1),
    bg            = rgbm(0, 0, 0, 0.55),
    bg_card       = rgbm(0, 0, 0, 0.65),
    panel_overlay = rgbm(1, 1, 1, 1),
    leaderboard_overlay = rgbm(1, 1, 1, 1),
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
local fonts_source = "unknown"

local app_dir = ac.dirname()
local FONT_FAMILY = "Archivo SemiExpanded"

local function system_font(name, weight)
    local font = ui.DWriteFont(name .. ":@System")
    if weight ~= nil then
        font = font:weight(weight)
    end
    return font
end

local function bundled_font(weight)
    return ui.DWriteFont(FONT_FAMILY .. ":/fonts;Weight=" .. weight)
end

local function has_bundled_fonts()
    return io.fileExists(app_dir .. "/fonts/ArchivoSemiExpanded-Regular.ttf")
        and io.fileExists(app_dir .. "/fonts/ArchivoSemiExpanded-Medium.ttf")
        and io.fileExists(app_dir .. "/fonts/ArchivoSemiExpanded-Bold.ttf")
end

--- Mismas fuentes que CMRT: Archivo SemiExpanded Medium / Bold.
function theme.ensure_fonts()
    if fonts_ready then return end
    fonts_ready = true

    if has_bundled_fonts() then
        fonts_source = "bundled"
        theme.fonts.reg    = bundled_font("Regular")
        theme.fonts.small  = bundled_font("Regular")
        theme.fonts.medium = bundled_font("Medium")
        theme.fonts.bold   = bundled_font("Bold")
        return
    end

    fonts_source = "system"
    theme.fonts.reg    = system_font("Segoe UI")
    theme.fonts.small  = system_font("Segoe UI")
    theme.fonts.medium = system_font("Segoe UI", ui.DWriteFont.Weight.Medium)
    theme.fonts.bold   = system_font("Segoe UI", ui.DWriteFont.Weight.Bold)
end

function theme.get_fonts_source()
    theme.ensure_fonts()
    return fonts_source
end

function theme.format_lap(ms)
    if ms == nil or ms <= 0 then return "--:--.---" end
    local total_sec = ms / 1000
    local min = math.floor(total_sec / 60)
    local sec = total_sec - min * 60
    if min > 0 then
        return string.format("%d:%06.3f", min, sec)
    end
    return string.format("0:%06.3f", sec)
end

--- Código corto de coche para profile/rival (#2 AE86 - 4:39.65).
function theme.format_car_short(car_name, car_id)
    if car_id ~= nil and car_id ~= "" then
        local id = string.lower(car_id)
        local by_id = {
            ae86_trueno = "AE86",
            ae86_levin = "AE86",
            ae85_levin = "AE85",
            rx7_fc = "FC",
            rx7_fd = "FD",
            s13_silvia = "S13",
            s15_silvia = "S15",
            civic_eg6 = "EG6",
            evo_iv = "EVO4",
            evo_v = "EVO5",
            gt86 = "86",
        }
        if by_id[id] ~= nil then return by_id[id] end
        local tail = id:match("([^_]+)$")
        if tail ~= nil then
            tail = tail:upper()
            if #tail <= 5 then return tail end
        end
    end

    if car_name == nil or car_name == "" then return "?" end

    local upper = string.upper(car_name)

    if upper:find("AE86", 1, true) then return "AE86" end
    if upper:find("AE85", 1, true) then return "AE85" end
    if upper:find("EG6", 1, true) then return "EG6" end
    if upper:find("S15", 1, true) then return "S15" end
    if upper:find("S13", 1, true) then return "S13" end
    if upper:find("86 GT", 1, true) or upper:find("GT86", 1, true) then return "86" end

    if upper:find("EVO", 1, true) then
        local gen = upper:match("EVO%s*([IVX%d]+)") or upper:match("(%d+)")
        if gen == "IV" or gen == "4" then return "EVO4" end
        if gen == "V" or gen == "5" then return "EVO5" end
        if gen ~= nil then return "EVO" .. gen end
        return "EVO"
    end

    if upper:find("SILEIGHTY", 1, true) or upper:find("SIL80", 1, true) then return "S13" end

    if upper:find("RX", 1, true) or upper:find("7", 1, true) then
        if upper:find("FD", 1, true) then return "FD" end
        if upper:find("FC", 1, true) then return "FC" end
    end
    if upper:find("FD", 1, true) then return "FD" end
    if upper:find("FC", 1, true) then return "FC" end

    local last = car_name:match("([%w%-]+)$")
    if last ~= nil then
        last = last:upper():gsub("-", "")
        if #last <= 6 then return last end
    end

    return car_name:sub(1, 6):upper()
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
