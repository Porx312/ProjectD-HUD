--[[ ProjectD — Perfil del jugador (template, Steam ID → datos falsos) ]]

local theme = require("common.theme")
local data = require("common.data")
local draw = require("common.draw")
local images = require("common.images")
local mod = {}

function mod.init()
    images.init()
    local p = data.get_player_profile()
    if p ~= nil then
        images.prefetch_avatar(p.name, p.avatar_url)
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

    local profile = data.get_player_profile()
    if profile ~= nil then
        images.prefetch_avatar(profile.name, profile.avatar_url)
    end

    if profile == nil then
        ui.pushDWriteFont(theme.fonts.reg)
        local msg = "Loading profile..."
        if data.is_loading ~= nil and not data.is_loading() then
            msg = "No profile data"
            if data.get_status_message ~= nil then
                msg = data.get_status_message("profile") or msg
            end
        end
        local tw = ui.measureDWriteText(msg, 13).x
        ui.dwriteDrawText(msg, 13, vec2((win.x - tw) * 0.5, math.max(8, (win.y - 13) * 0.35)), theme.colors.muted)
        ui.popDWriteFont()
    else
        draw.profile_block(vec2(0, 0), win, profile)
    end
end

return mod
