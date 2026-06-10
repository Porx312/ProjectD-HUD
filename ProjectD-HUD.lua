-- keep the filename of this file the same as the folder that contains it
-- ProjectD HUD — template con datos falsos (sin API)

Dt = 0
Time = 0

local top5 = require("top5.first")
local profile = require("profile.first")
local rival = require("rival.first")

local init = false

local function session_start()
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
        top5.init()
        profile.init()
        rival.init()
    end
end

function top5Main(dt) top5.main(dt) end
function top5Show() top5.on_open() end
function top5Hide() top5.on_close() end

function profileMain(dt) profile.main(dt) end
function profileShow() profile.on_open() end
function profileHide() profile.on_close() end

function rivalMain(dt) rival.main(dt) end
function rivalShow() rival.on_open() end
function rivalHide() rival.on_close() end
