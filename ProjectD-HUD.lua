-- keep the filename of this file the same as the folder that contains it

Dt = 0
Time = 0

local top10 = require("top10.first")
local profile = require("profile.first")
local rival = require("rival.first")
local theme = require("common.theme")

local init = false
local filter_storage = ac.storage("ProjectD-HUD:top10_filter", "")
local legacy_filter_storage = ac.storage("ProjectD-HUD:top5_filter", "global")

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

local function ensure_data_ready()
    pcall(function()
        local data = require("common.data")
        if data.init ~= nil then data.init() end
        if data.hydrate ~= nil then data.hydrate() end
    end)
end

local function session_start()
    pcall(function()
        local data = require("common.data")
        if data.on_session_start ~= nil then data.on_session_start() end
    end)
    top10.on_session_start()
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
        pcall(top10.init)
        pcall(profile.init)
        pcall(rival.init)
    end

    pcall(function()
        local data = require("common.data")
        local filt = filter_storage:get()
        if filt == nil or filt == "" then filt = legacy_filter_storage:get() or "global" end
        if data.run_tick ~= nil then data.run_tick(filt)
        elseif data.tick ~= nil then data.tick(filt) end
    end)
end

function top10Main(dt) safe_main(top10, dt, "top10") end
function top10Show() ensure_data_ready(); top10.on_open() end
function top10Hide() top10.on_close() end

function top5Main(dt) top10Main(dt) end
function top5Show() top10Show() end
function top5Hide() top10Hide() end

function profileMain(dt) safe_main(profile, dt, "profile") end
function profileShow() ensure_data_ready(); profile.on_open() end
function profileHide() profile.on_close() end

function rivalMain(dt) safe_main(rival, dt, "rival") end
function rivalShow() ensure_data_ready(); rival.on_open() end
function rivalHide() rival.on_close() end
