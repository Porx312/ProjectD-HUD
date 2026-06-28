--[[
    Avatares por URL e iconos de tier locales.
    Tier icons: assets/tiers/tier0.png … tier10.png
]]

local images = {}

local avatar_textures = {}   ---@type table<string, ui.ImageSource|string|false|nil>
local avatar_loading = {}    ---@type table<string, boolean>
local avatar_pending = {}    ---@type table<string, boolean>
local avatar_failed_at = {}  ---@type table<string, number>
local AVATAR_RETRY_SEC = 12

local function web_slots_full()
    local ok_wq, web_queue = pcall(require, "common.api.web_queue")
    if ok_wq and web_queue ~= nil and web_queue.inflight_count ~= nil then
        return web_queue.inflight_count() >= 2
    end
    local ok, st = pcall(require, "common.api.state")
    if not ok or st == nil then return false end
    if st.web_stream ~= nil and st.web_inflight ~= nil then return true end
    return st.web_inflight ~= nil and st.web_stream ~= nil
end
local tier_textures = {}     ---@type table<number, string?>

local app_dir = ac.dirname()
local CORNERS_ALL = nil

local function corners_all()
    if CORNERS_ALL ~= nil then return CORNERS_ALL end
    if ui.CornerFlags == nil then
        CORNERS_ALL = 15
        return CORNERS_ALL
    end
    if ui.CornerFlags.All ~= nil then
        CORNERS_ALL = ui.CornerFlags.All
        return CORNERS_ALL
    end
    CORNERS_ALL = ui.CornerFlags.TopLeft + ui.CornerFlags.TopRight
        + ui.CornerFlags.BottomLeft + ui.CornerFlags.BottomRight
    return CORNERS_ALL
end

local function tier_asset_path(tier)
    local n = math.max(0, math.min(10, math.floor(tier)))
    return app_dir .. "/assets/tiers/tier" .. tostring(n) .. ".png"
end

--- URL estable para mocks (las IDs de imgur del template suelen estar rotas).
function images.placeholder_url(name)
    local seed = string.gsub(name or "driver", "%s+", "")
    return "https://api.dicebear.com/7.x/notionists/png?seed=" .. seed .. "&size=128"
end

--- URL to display/fetch: real avatar when API provides one; dicebear only if missing.
function images.resolve_url(name, url)
    if url ~= nil and url ~= "" then
        return url
    end
    return images.placeholder_url(name)
end

--- Queue download for the real avatar (or placeholder when URL absent).
function images.prefetch_avatar(name, url)
    local target = images.resolve_url(name, url)
    if target ~= nil and target ~= "" then
        images.request_avatar(target)
    end
end

function images.get_tier_path(tier)
    local n = math.max(0, math.min(10, math.floor(tonumber(tier) or 0)))
    if tier_textures[n] == nil then
        local path = tier_asset_path(n)
        if io.fileExists(path) then
            tier_textures[n] = path
        else
            tier_textures[n] = false
        end
    end
    if tier_textures[n] == false then return nil end
    return tier_textures[n]
end

--- Dibuja icono de tier (tier0.png … tier10.png). Solo PNG local, sin fallback.
function images.draw_tier_badge(pos, tier, tier_sz)
    if pos == nil then return end

    local ok_prof, profile_mod = pcall(require, "common.api.profile")
    local parsed = 0
    if ok_prof and profile_mod.tier_for_display ~= nil then
        if type(tier) == "table" then
            parsed = profile_mod.tier_for_display(tier)
        else
            parsed = profile_mod.tier_for_display({ tier = tier })
        end
    else
        parsed = math.floor(tonumber(tier) or 0)
    end
    if parsed < 0 or parsed > 10 then return end

    tier_sz = math.max(8, tonumber(tier_sz) or 24)
    local path = images.get_tier_path(parsed)
    if path == nil then return end

    ui.drawImage(path, pos, pos + vec2(tier_sz, tier_sz))
end

function images.request_avatar(url)
    if url == nil or url == "" then return end
    local cached = avatar_textures[url]
    if cached ~= nil and cached ~= false then return end
    if avatar_loading[url] then return end
    if cached == false then
        local failed_at = avatar_failed_at[url] or 0
        if (os.clock() - failed_at) < AVATAR_RETRY_SEC then return end
        avatar_textures[url] = nil
    end
    if web_slots_full() then
        avatar_pending[url] = true
        return
    end
    avatar_loading[url] = true

    local ok_util, util = pcall(require, "common.api.util")
    local ok_wq, web_queue = pcall(require, "common.api.web_queue")
    local function on_avatar(err, response)
        avatar_loading[url] = false
        local ok_http = ok_util and util.http_response_ok(response)
            or (response ~= nil and (response.status == nil or response.status == 200))
        if ok_util and util.is_web_error(err) then ok_http = false end
        if err ~= nil and ok_util and not util.is_web_error(err) and response == nil then
            ok_http = true
            response = { status = 200, body = err }
        end
        if not ok_http then
            avatar_textures[url] = false
            avatar_failed_at[url] = os.clock()
            return
        end
        local body = ok_util and util.response_body(response) or (response and response.body)
        if body == nil or body == "" then
            avatar_textures[url] = false
            avatar_failed_at[url] = os.clock()
            return
        end
        local ok, tex = pcall(ui.decodeImage, body)
        if ok and tex ~= nil then
            avatar_textures[url] = tex
            avatar_failed_at[url] = nil
        else
            avatar_textures[url] = false
            avatar_failed_at[url] = os.clock()
        end
    end

    if ok_wq and web_queue ~= nil and web_queue.get ~= nil then
        web_queue.get(url, "avatar", on_avatar)
    elseif web ~= nil and web.get ~= nil then
        web.get(url, on_avatar)
    else
        avatar_loading[url] = false
        avatar_textures[url] = false
        avatar_failed_at[url] = os.clock()
    end
end

function images.tick()
    if web_slots_full() then return end
    local started = 0
    for pending_url, _ in pairs(avatar_pending) do
        if web_slots_full() then break end
        avatar_pending[pending_url] = nil
        images.request_avatar(pending_url)
        started = started + 1
        if started >= 2 then break end
    end
end

function images.get_avatar(url)
    if url == nil or url == "" then return nil end
    local cached = avatar_textures[url]
    if cached == false then return nil end
    images.request_avatar(url)
    return avatar_textures[url]
end

--- UV para recorte tipo "cover" (centra la foto dentro del círculo).
function images.cover_uv(tex)
    local ok, sz = pcall(ui.imageSize, tex)
    if not ok or sz == nil or sz.x <= 0 or sz.y <= 0 then
        return vec2(0, 0), vec2(1, 1)
    end

    local aspect = sz.x / sz.y
    if aspect > 1.001 then
        local w = 1 / aspect
        local off = (1 - w) * 0.5
        return vec2(off, 0), vec2(1 - off, 1)
    end
    if aspect < 0.999 then
        local h = aspect
        local off = (1 - h) * 0.5
        return vec2(0, off), vec2(1, 1 - off)
    end
    return vec2(0, 0), vec2(1, 1)
end

function images.corners_all()
    return corners_all()
end

local function full_tau()
    return math.tau or (math.pi * 2)
end

--- Textura recortada en círculo perfecto (CSP ui.drawPie). Devuelve false si hay que usar fallback.
function images.draw_texture_circle(center, radius, tex, tint)
    if tex == nil or center == nil then return false end
    radius = math.max(2, tonumber(radius) or 16)
    if ui.drawPie == nil then return false end
    ui.drawPie(center, radius, 0, full_tau(), tint or rgbm(1, 1, 1, 1), tex)
    return true
end

local function first_existing(paths)
    for _, path in ipairs(paths) do
        if path ~= nil and io.fileExists(path) then return path end
    end
    return nil
end

--- Fondo de tarjeta profile/rival (assets locales).
function images.get_card_panel()
    return first_existing({
        app_dir .. "/assets/panel_card.png",
        app_dir .. "/assets/tiers/panel_card.png",
    })
end

--- Capa opcional encima de panel_card (profile/rival). Solo assets locales.
function images.get_card_panel_overlay()
    return first_existing({
        app_dir .. "/assets/panel_overlay.png",
        app_dir .. "/assets/panel_gradient.png",
    })
end

--- Logo del HUD (cabecera leaderboard).
function images.get_logo()
    return first_existing({
        app_dir .. "/assets/logo.png",
        app_dir .. "/logo.png",
        app_dir .. "/icon.png",
    })
end

--- Fondo vertical del Top 10 / leaderboard.
function images.get_leaderboard_panel()
    return first_existing({
        app_dir .. "/assets/leaderboard_panel.png",
        app_dir .. "/assets/tiers/leaderboard_panel.png",
    })
end

--- Capa encima del leaderboard (NO reutiliza el gradiente de profile).
function images.get_leaderboard_panel_overlay()
    return first_existing({
        app_dir .. "/assets/leaderboard_overlay.png",
        app_dir .. "/assets/leaderboard_gradient.png",
    })
end

--- Fondo de filas del HUD Competition / rivals.
function images.get_competition_rivals_overlay()
    return first_existing({
        app_dir .. "/assets/overlay_rivals.png",
    })
end

--- Battle HUD — fondo completo (assets/battle/bg.png).
function images.get_battle_bg()
    return first_existing({
        app_dir .. "/assets/battle/bg.png",
    })
end

--- Marco / contenedor del bar (debajo o encima del bg según diseño — se dibuja primero).
function images.get_battle_container()
    return first_existing({
        app_dir .. "/assets/battle/container.png",
        app_dir .. "/assets/battle/battle_container.png",
    })
end

--- Centro battle: center_*.png según fase (matchmaking, countdown, …).
function images.get_battle_center(state_key)
    local key = string.lower(tostring(state_key or "matchmaking"))
    local names = {
        matchmaking = {
            "center_matchmaking.png",
            "center_looking.png",
        },
        vs = { "center_vs.png" },
        countdown = { "center_countdown.png" },
        points = { "center_points.png" },
        result = {
            "center-result.png",
            "center_result.png",
        },
        draw = {
            "center-draw.png",
            "center_draw.png",
        },
        finished = { "center-result.png", "center_result.png", "center_points.png" },
        cancelled = { "center_cancelled.png" },
    }
    local candidates = names[key] or names.matchmaking
    local paths = {}
    for _, name in ipairs(candidates) do
        paths[#paths + 1] = app_dir .. "/assets/battle/" .. name
    end
    return first_existing(paths)
end

--- Overlay derecho sin rival (searching rival + avatar ?).
function images.get_battle_searching_overlay()
    return first_existing({
        app_dir .. "/assets/battle/searching_rival_text_and_playeravatarUndefine.png",
        app_dir .. "/assets/battle/searching_rival.png",
    })
end

function images.get_battle_gap_track()
    return first_existing({
        app_dir .. "/assets/battle/gap_track.png",
        app_dir .. "/assets/battle/gap_progress_bar.png",
    })
end

function images.get_battle_gap_fill()
    return first_existing({
        app_dir .. "/assets/battle/gap_fill.png",
    })
end

function images.get_battle_gap_bar()
    return first_existing({
        app_dir .. "/assets/battle/gap_progress_bar.png",
    })
end

function images.init()
    for t = 0, 10 do
        images.get_tier_path(t)
    end
end

return images
