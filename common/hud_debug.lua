--[[ On-screen diagnostics for ProjectD HUD API loading issues. ]]

local theme = require("common.theme")

local hud_debug = {}

function hud_debug.should_show(data)
    if data == nil then return true end
    if data.should_show_diag ~= nil and data.should_show_diag() then return true end
    if data.is_debug ~= nil and data.is_debug() then return true end
    if data.is_loading ~= nil and data.is_loading() then return true end
    if data.get_status ~= nil then
        local st = data.get_status()
        if st ~= nil then
            if st.loading or st.profile_loading then return true end
            if not st.has_bundle then return true end
            if st.error ~= nil and st.error ~= "" then return true end
        end
    end
    return false
end

function hud_debug.draw(data, win, opts)
    if data == nil or data.get_diag_lines == nil then return end
    if not hud_debug.should_show(data) then return end

    opts = opts or {}
    local lines = data.get_diag_lines()
    if lines == nil or #lines == 0 then return end

    theme.ensure_fonts()
    local font = theme.fonts.reg
    local fs = opts.font_size or 9
    local pad = opts.pad or 3
    local max_lines = opts.max_lines or 14
    local line_h = fs + 2

    local count = math.min(#lines, max_lines)
    local box_h = count * line_h + pad * 2
    local box_w = win.x
    local y0 = win.y - box_h
    if y0 < 0 then y0 = 0 end

    ui.drawRectFilled(vec2(0, y0), vec2(box_w, win.y), rgbm(0, 0, 0, 0.82))

    if font ~= nil then ui.pushDWriteFont(font) end
    local y = y0 + pad
    for i = 1, count do
        local color = theme.colors.muted
        local line = lines[i]
        if line ~= nil and string.sub(line, 1, 4) == "err=" and not line:match("err=$") and not line:match("err=nil") then
            color = rgbm(1, 0.55, 0.55, 1)
        end
        ui.dwriteDrawText(line, fs, vec2(pad, y), color)
        y = y + line_h
    end
    if font ~= nil then ui.popDWriteFont() end
end

return hud_debug
