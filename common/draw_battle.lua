--[[ Battle HUD — panel background and block orchestrator. ]]

local theme = require("common.theme")
local layout = require("common.layout")
local images = require("common.images")
local battle_parse = require("common.api.battle_parse")
local draw_battle_players = require("common.draw_battle_players")
local draw_battle_center = require("common.draw_battle_center")
local draw_battle_gap = require("common.draw_battle_gap")

local draw_battle = {}

local function battle_placeholder()
    return {
        placeholder = true,
        name = "Looking for opponent",
        car_name = "",
        tier = 0,
    }
end

local function resolve_display(battle)
    if battle.display ~= nil then return battle.display end
    return battle_parse.build_display(battle)
end

function draw_battle.battle_panel(bar_origin, bar_size)
    local origin = bar_origin
    local ps = bar_size
    local br = origin + ps
    local d = layout.BATTLE_DESIGN

    local container = images.get_battle_container()
    local bg = images.get_battle_bg()

    if container ~= nil then
        local c_o, c_sz = layout.battle_slot(origin, ps, d.container)
        ui.drawImage(container, c_o, c_o + c_sz, rgbm(1, 1, 1, 1))
    end

    if bg ~= nil then
        local b_o, b_sz = layout.battle_slot(origin, ps, d.bg)
        ui.drawImage(bg, b_o, b_o + b_sz, rgbm(1, 1, 1, 1))
    elseif container == nil then
        ui.drawRectFilled(origin, br, theme.colors.battle_bg, 8, layout.corners_all())
        ui.drawRect(origin, br, theme.colors.battle_border, 8, layout.corners_all(), 1)
    end

    return vec2(0, 0), ps
end

function draw_battle.battle_block(panel_o, panel_size, battle, opts)
    theme.ensure_fonts()
    battle = battle or {}
    opts = opts or {}
    local m = layout.battle_metrics(panel_size)
    local d = layout.BATTLE_DESIGN
    local display = resolve_display(battle)

    local left = battle.player_left or {}
    local right = battle.player_right or battle_placeholder()
    local right_placeholder = right.placeholder == true

    local center_key = display.center_key
    local center_image_drawn, center_content_o, center_content_sz =
        draw_battle_center.draw_center_image(panel_o, panel_size, center_key)

    draw_battle_players.draw_player(panel_o, panel_size, left, "left", m, d)
    if not right_placeholder then
        draw_battle_players.draw_player(panel_o, panel_size, right, "right", m, d)
    end

    draw_battle_center.draw_block(
        panel_o,
        panel_size,
        battle,
        display,
        m,
        d,
        center_key,
        center_image_drawn,
        center_content_o,
        center_content_sz
    )
    draw_battle_players.draw_searching_overlay(panel_o, panel_size, display.show_searching)
    draw_battle_gap.draw_layer(
        panel_o,
        panel_size,
        tonumber(opts.gap_margin) or 0,
        tonumber(opts.gap_h) or 0,
        battle,
        m,
        opts.win_origin,
        opts.win_size
    )
end

return draw_battle
