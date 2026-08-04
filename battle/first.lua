--[[ ProjectD — Battle HUD (repo SSE logic + local visuals) ]]

local layout = require("common.layout.battle")
local theme = require("common.theme")
local data = require("common.data")
local draw = require("common.draw")
local images = require("common.images")
local mod = {}

local function battle_data()
    if data.get_battle == nil then return nil end
    return data.get_battle()
end

local function prefetch_avatars(battle)
    if battle == nil then return end
    for _, player in ipairs({ battle.player_left, battle.player_right }) do
        if player ~= nil then
            images.prefetch_avatar(player.name, player.avatar_url)
        end
    end
end

local function battle_status_message()
    if data.get_status_message ~= nil then
        local custom = data.get_status_message("battle")
        if custom ~= nil then return custom end
    end
    if data.is_loading ~= nil and data.is_loading() then
        return "Connecting to ProjectD…"
    end
    return "Waiting for battle…"
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
    if data.tick ~= nil then
        data.tick("global")
    end

    local win_origin = vec2(0, 0)
    local win_size = ui.windowSize()
    if win_size.x <= 0 or win_size.y <= 0 then
        return
    end

    if data.is_account_restricted ~= nil and data.is_account_restricted() then
        local frame_o, bar_ps = layout.battle_frame_fit(win_size, false)
        if bar_ps.x > 0 and bar_ps.y > 0 then
            local bar_o = win_origin + frame_o
            draw.battle_panel(bar_o, bar_ps)
            draw.center_status_message(bar_o, bar_ps, "Account restricted")
        else
            draw.center_status_message(win_origin, win_size, "Account restricted")
        end
        return
    end

    local battle = battle_data()
    if battle == nil then
        local frame_o, bar_ps = layout.battle_frame_fit(win_size, false)
        local msg = battle_status_message()
        local opts = { color = theme.colors.muted }
        if bar_ps.x > 0 and bar_ps.y > 0 then
            local bar_o = win_origin + frame_o
            draw.battle_panel(bar_o, bar_ps)
            draw.center_status_message(bar_o, bar_ps, msg, opts)
        else
            draw.center_status_message(win_origin, win_size, msg, opts)
        end
        return
    end

    prefetch_avatars(battle)

    local frame_o, bar_ps, gap_margin, gap_h = layout.battle_frame_fit(win_size, battle.show_gap == true)
    if bar_ps.x <= 0 or bar_ps.y <= 0 then
        return
    end

    local bar_o = win_origin + frame_o
    draw.battle_panel(bar_o, bar_ps)
    draw.battle_block(bar_o, bar_ps, battle, {
        gap_margin = gap_margin,
        gap_h = gap_h,
        win_origin = win_origin,
        win_size = win_size,
    })
end

return mod
