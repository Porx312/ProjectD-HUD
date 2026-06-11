--[[
    Avatares por URL e iconos de tier locales.
    Tier icons: assets/tiers/tier0.png … tier10.png
]]

local images = {}

local avatar_textures = {}   ---@type table<string, ui.ImageSource|string|false|nil>
local avatar_loading = {}    ---@type table<string, boolean>
local avatar_pending = {}    ---@type table<string, boolean>

local function api_web_busy()
    local ok, st = pcall(require, "common.api.state")
    if not ok or st == nil then return false end
    if st.fetch_pending or st.profile_fetch_pending then return true end
    if st.web_inflight ~= nil then return true end
    if st.web_queue ~= nil and #st.web_queue > 0 then return true end
    return false
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

function images.resolve_url(name, url)
    if url ~= nil and url ~= "" and avatar_textures[url] ~= false then
        return url
    end
    return images.placeholder_url(name)
end

function images.get_tier_path(tier)
    local n = math.max(0, math.min(10, math.floor(tier)))
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

function images.request_avatar(url)
    if url == nil or url == "" then return end
    if avatar_textures[url] ~= nil or avatar_loading[url] then return end
    if api_web_busy() then
        avatar_pending[url] = true
        return
    end
    avatar_loading[url] = true

    local ok_wq, web_queue = pcall(require, "common.api.web_queue")
    local ok_util, util = pcall(require, "common.api.util")
    local function on_avatar(err, response)
        avatar_loading[url] = false
        if ok_util and util ~= nil then
            err, response = util.normalize_web_response(err, response)
        end
        if ok_util and util ~= nil and util.is_web_error(err) then
            avatar_textures[url] = false
            return
        end
        if response == nil or not (ok_util and util ~= nil and util.http_response_ok(response)) then
            avatar_textures[url] = false
            return
        end
        local body = ok_util and util ~= nil and util.response_body(response) or response.body
        local ok, tex = pcall(function()
            return ui.decodeImage(body)
        end)
        if ok and tex ~= nil then
            avatar_textures[url] = tex
        else
            avatar_textures[url] = false
        end
    end

    if ok_wq and web_queue ~= nil and web_queue.get ~= nil then
        web_queue.get(url, "avatar", on_avatar, 2)
    elseif web ~= nil and web.get ~= nil then
        web.get(url, on_avatar)
    else
        avatar_loading[url] = false
        avatar_textures[url] = false
    end
end

--- Flush one deferred avatar per frame after API requests (CSP max 2 web.get).
function images.tick()
    if api_web_busy() then return end
    for pending_url, _ in pairs(avatar_pending) do
        avatar_pending[pending_url] = nil
        images.request_avatar(pending_url)
        return
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

function images.init()
    for t = 0, 10 do
        images.get_tier_path(t)
    end
end

return images
