--[[ ProjectD — Perfil del jugador (template, Steam ID → datos falsos) ]]

local theme = require("common.theme")
local data = require("common.data")
local draw = require("common.draw")
local images = require("common.images")
local profile_display = require("common.profile.display")
local mod = {}

local avatars_prefetched_for = ""
local DEBUG_STORAGE = ac.storage("ProjectD-HUD:battle_debug", false)

local function transport_status_line()
    if data.get_status == nil then return nil end
    local ok, st = pcall(data.get_status)
    if not ok or st == nil then return nil end
    return string.format(
        "mode=%s evt=%s wait=%s bundle=%s profile=%s",
        tostring(st.battle_sse_mode ~= "" and st.battle_sse_mode or (st.battle_sse and "?" or "off")),
        tostring(st.battle_event_name or ""),
        tostring(st.hud_waiting_reason or ""),
        st.has_bundle and "y" or "n",
        st.has_profile and "y" or "n"
    )
end

local function debug_status_line()
    if DEBUG_STORAGE:get() ~= true then return nil end
    return transport_status_line()
end

function mod.init()
    images.init()
    local p = profile_display.resolve_profile(
        function() return data.get_player_profile() end,
        data.is_account_restricted
    )
    if p ~= nil then
        avatars_prefetched_for = profile_display.avatar_prefetch_key(p)
        images.prefetch_avatar(p.name, p.avatar_url)
    end
end

function mod.on_session_start()
    avatars_prefetched_for = ""
    profile_display.reset()
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
    local win = ui.windowSize()

    draw.card_panel(vec2(0, 0), win)

    if data.is_account_restricted ~= nil and data.is_account_restricted() then
        draw.center_status_message(vec2(0, 0), win, "Account restricted")
        return
    end

    local profile = profile_display.resolve_profile(
        function() return data.get_player_profile() end,
        data.is_account_restricted
    )

    if profile ~= nil then
        profile_display.tick(dt, profile)
        local prefetch_key = profile_display.avatar_prefetch_key(profile)
        if avatars_prefetched_for ~= prefetch_key then
            avatars_prefetched_for = prefetch_key
            images.prefetch_avatar(profile.name, profile.avatar_url)
        end
        draw.profile_block(vec2(0, 0), win, profile, {
            highlights = profile_display.get_highlights(),
        })
        return
    end

    ui.pushDWriteFont(theme.fonts.reg)
    local msg = "No profile data"
    if data.get_status_message ~= nil then
        msg = data.get_status_message("profile") or msg
    elseif data.is_loading ~= nil and data.is_loading() then
        msg = "Loading profile..."
    end
    local transport_line = transport_status_line()
    if transport_line ~= nil then
        msg = msg .. "\n" .. transport_line
    end
    local debug_line = debug_status_line()
    if debug_line ~= nil and debug_line ~= transport_line then
        msg = msg .. "\n" .. debug_line
    end
    local tw = ui.measureDWriteText(msg, 13).x
    ui.dwriteDrawText(msg, 13, vec2((win.x - tw) * 0.5, math.max(8, (win.y - 13) * 0.35)), theme.colors.muted)
    ui.popDWriteFont()
end

return mod
