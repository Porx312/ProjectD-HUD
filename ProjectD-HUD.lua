-- keep the filename of this file the same as the folder that contains it

Dt = 0
Time = 0

local top5 = require("top5.first")
local profile = require("profile.first")
local rival = require("rival.first")
local theme = require("common.theme")

local init = false

local function safe_main(mod, dt, label)
    local ok, err = pcall(mod.main, dt)
    if not ok then
        local msg = tostring(err)
        ac.debug("ProjectD-HUD " .. label .. " error", msg)
        theme.ensure_fonts()
        local win = ui.windowSize()
        ui.drawRectFilled(vec2(0, 0), win, rgbm(0, 0, 0, 0.85))
        local font = theme.fonts.reg
        if font ~= nil then ui.pushDWriteFont(font) end
        ui.dwriteDrawText(label .. " error:", 11, vec2(6, 6), rgbm(1, 0.5, 0.5, 1))
        ui.dwriteDrawText(msg, 10, vec2(6, 22), rgbm(1, 0.85, 0.85, 1))
        if font ~= nil then ui.popDWriteFont() end
    end
end

local function session_start()
    pcall(function()
        local data = require("common.data")
        if data.on_session_start ~= nil then data.on_session_start() end
    end)
    top5.on_session_start()
    profile.on_session_start()
    rival.on_session_start()
end

function script.update(dt)
    Dt = dt
    Time = Time + Dt

    if init == false then
        init = true
        ac.onSessionStart(session_start)
        pcall(function()
            local data = require("common.data")
            if data.init ~= nil then data.init() end
        end)
        pcall(top5.init)
        pcall(profile.init)
        pcall(rival.init)
    end
end

function top5Main(dt) safe_main(top5, dt, "top5") end
function top5Show() top5.on_open() end
function top5Hide() top5.on_close() end

function profileMain(dt) safe_main(profile, dt, "profile") end
function profileShow() profile.on_open() end
function profileHide() profile.on_close() end

function rivalMain(dt) safe_main(rival, dt, "rival") end
function rivalShow() rival.on_open() end
function rivalHide() rival.on_close() end
