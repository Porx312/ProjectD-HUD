--[[ ProjectD — Rival (jugador #rank-1, template) ]]

local theme = require("common.theme")
local mock = require("common.mock_data")
local draw = require("common.draw")
local images = require("common.images")

local mod = {}

function mod.init()
    images.init()
    local r = mock.get_rival()
    if r ~= nil then
        images.request_avatar(images.resolve_url(r.name, r.avatar_url))
    end
end

function mod.on_session_start()
    mod.init()
end

function mod.on_open() end
function mod.on_close() end
function mod.update() end

function mod.main(dt)
    theme.ensure_fonts()
    local win = ui.windowSize()

    draw.cmrt_panel(vec2(0, 0), win)

    local rival = mock.get_rival()
    local profile = mock.get_player_profile()

    if rival == nil then
        local msg = "You're #1 — no rival"
        if profile == nil then msg = "No rival data" end
        ui.pushDWriteFont(theme.fonts.reg)
        local tw = ui.measureDWriteText(msg, 13).x
        ui.dwriteDrawText(msg, 13, vec2((win.x - tw) * 0.5, (win.y - 13) * 0.5), theme.colors.muted)
        ui.popDWriteFont()
        return
    end

    draw.rival_block(vec2(0, 0), win, rival)
end

return mod
