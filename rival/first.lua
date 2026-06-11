--[[ ProjectD — Rival (jugador #rank-1, template) ]]

local theme = require("common.theme")
local data = require("common.data")
local draw = require("common.draw")
local images = require("common.images")
local hud_debug = require("common.hud_debug")

local mod = {}

function mod.init()
    images.init()
    local r = data.get_rival()
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
    if data.run_tick ~= nil then pcall(data.run_tick)
    elseif data.tick ~= nil then pcall(data.tick) end
    theme.ensure_fonts()
    local win = ui.windowSize()

    draw.card_panel(vec2(0, 0), win)

    local rival = data.get_rival()
    local profile = data.get_player_profile()
    if rival ~= nil then
        images.request_avatar(images.resolve_url(rival.name, rival.avatar_url))
    end

    if rival == nil then
        local msg = "No rival"
        if data.get_status_message ~= nil then
            msg = data.get_status_message("rival")
        elseif profile == nil then
            msg = "No rival data"
        elseif (profile.rank or 0) == 1 then
            msg = "You're #1 — no rival"
        end
        ui.pushDWriteFont(theme.fonts.reg)
        local tw = ui.measureDWriteText(msg, 13).x
        ui.dwriteDrawText(msg, 13, vec2((win.x - tw) * 0.5, math.max(8, (win.y - 13) * 0.35)), theme.colors.muted)
        ui.popDWriteFont()
    else
        draw.rival_block(vec2(0, 0), win, rival)
    end

    hud_debug.draw(data, win, { max_lines = 10, font_size = 8 })
end

return mod
