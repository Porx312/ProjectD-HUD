--[[
    Avatares por URL e iconos de tier locales.
    Tier icons: assets/tiers/tier0.png … tier10.png
]]

local images = {}

local avatar_textures = {}   ---@type table<string, ui.ImageSource|string|false|nil>
local avatar_loading = {}    ---@type table<string, boolean>
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
    avatar_loading[url] = true

    web.get(url, function(err, response)
        avatar_loading[url] = false
        if err ~= nil or response == nil or response.status ~= 200 then
            avatar_textures[url] = false
            return
        end
        local ok, tex = pcall(function()
            return ui.decodeImage(response.body)
        end)
        if ok and tex ~= nil then
            avatar_textures[url] = tex
        else
            avatar_textures[url] = false
        end
    end)
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

--- Fondo de tarjeta: máscara blanca + tinte en draw (ver draw.cmrt_panel).
function images.get_card_panel()
    local candidates = {
        app_dir .. "/assets/panel_card.png",
        app_dir .. "/assets/tiers/panel_card.png",
    }
    for _, path in ipairs(candidates) do
        if io.fileExists(path) then return path end
    end

    local lua_root = app_dir:match("^(.*)[/\\][^/\\]+[/\\]?$")
    if lua_root ~= nil then
        local cmrt = lua_root .. "CMRT-Essential-HUD/assets/GEARBOX.png"
        if io.fileExists(cmrt) then return cmrt end
    end

    return nil
end

function images.init()
    for t = 0, 10 do
        images.get_tier_path(t)
    end
end

return images
