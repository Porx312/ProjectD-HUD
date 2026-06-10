--[[ ProjectD — Perfil del jugador (template, Steam ID → datos falsos) ]]

local theme = require("common.theme")
local mock = require("common.mock_data")
local draw = require("common.draw")
local images = require("common.images")

local mod = {}

function mod.init()
    images.init()
    local p = mock.get_player_profile()
    if p ~= nil then
        images.request_avatar(images.resolve_url(p.name, p.avatar_url))
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

    draw.card_panel(vec2(0, 0), win)

    local profile = mock.get_player_profile()
    if profile == nil then
        ui.pushDWriteFont(theme.fonts.reg)
        local msg = "No profile (mock)"
        local tw = ui.measureDWriteText(msg, 13).x
        ui.dwriteDrawText(msg, 13, vec2((win.x - tw) * 0.5, (win.y - 13) * 0.5), theme.colors.muted)
        ui.popDWriteFont()
        return
    end

    draw.profile_block(vec2(0, 0), win, profile)
end

return mod
