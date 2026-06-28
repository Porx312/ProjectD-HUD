--[[ ProjectD — Battle HUD (repo SSE logic + local visuals) ]]

local layout = require("common.layout")
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
            images.prefetch_avatar(player.name, player.avatar_url)
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

    local win_origin = vec2(0, 0)
    local win_size = ui.windowSize()
    if win_size.x <= 0 or win_size.y <= 0 then
        return
    end

    local frame_o, bar_ps, gap_margin, gap_h = layout.battle_frame_fit(win_size, battle.show_gap == true)
    if bar_ps.x <= 0 or bar_ps.y <= 0 then
        return
    end

    local bar_o = win_origin + frame_o
    draw.battle_panel(bar_o, bar_ps)
    draw.battle_block(bar_o, bar_ps, battle, {
        gap_margin = gap_margin,
        gap_h = gap_h,
    })
end

return mod
