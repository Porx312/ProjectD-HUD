--[[ ProjectD — Battle HUD (live ac-data SSE /hud/battle/stream) ]]

local theme = require("common.theme")
local data = require("common.data")
local draw = require("common.draw")
local images = require("common.images")
local mod = {}

local use_api = ac.storage("ProjectD-HUD:use_api", true):get()

local function battle_data()
    if data.get_battle ~= nil then
        return data.get_battle()
    end
    if not use_api then
        return require("common.mock_data").get_battle()
    end
    return nil
end

local function prefetch_avatars(battle)
    if battle == nil then return end
    for _, player in ipairs({ battle.player_left, battle.player_right }) do
        if player ~= nil then
            images.request_avatar(images.resolve_url(player.name, player.avatar_url))
        end
    end
end

function mod.init()
    images.init()
    prefetch_avatars(battle_data())
end

function mod.on_session_start()
    mod.init()
end

function mod.on_open() end
function mod.on_close() end
function mod.update() end

function mod.main(dt)
    theme.ensure_fonts()
    local battle = battle_data()

    if battle == nil then
        return
    end

    prefetch_avatars(battle)
    draw.battle_block(vec2(0, 0), ui.windowSize(), battle)
end

return mod
