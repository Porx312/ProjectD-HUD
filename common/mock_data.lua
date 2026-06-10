--[[
    Datos falsos — Initial D cast.
    Tier 0–10 según nivel en el anime (touge / downhill).
    Clave futura: serverId + trackId + layoutId + carId
]]

local mock = {}

mock.MOCK_CONTEXT = {
    server_id = "projectd-touge-01",
    track_id = "akina",
    layout_id = "downhill",
    car_id = "ae86_trueno",
    car_name = "Trueno AE86",
    player_steam_id = "76561198012345678",
}

local function context_key(ctx)
    return ctx.server_id .. "@" .. ctx.track_id .. "@" .. ctx.layout_id .. "@" .. ctx.car_id
end

local function avatar(name)
    local seed = string.gsub(name, "%s+", "")
    return "https://api.dicebear.com/7.x/notionists/png?seed=" .. seed .. "&size=128"
end

--[[
    Tiers (anime):
    10 — Bunta, Ryosuke (récord de Akina)
     9 — Takumi (final), Keisuke, Shinji, Kai
     8 — Wataru, Ueo, Nakazato
     7 — Kenta, Mako
     6 — Seiji, Tomoyuki Tachi
     5 — Itsuki, Iketani
     4 — Kenji (Akagi local)
     3 — Kazumi, Hiroshi
     2 — novatos de club
     1 — debutantes
]]

local LEADERBOARDS = {
  -- Akina downhill · servidor principal
    ["projectd-touge-01@akina@downhill@ae86_trueno"] = {
        { rank = 1, name = "Ryosuke Takahashi",  tier = 10, lap_ms = 277800, car_name = "RX-7 FC",    avatar_url = avatar("Ryosuke Takahashi") },
        { rank = 2, name = "Takumi Fujiwara",    tier = 9,  lap_ms = 279650, car_name = "Trueno AE86", avatar_url = avatar("Takumi Fujiwara") },
        { rank = 3, name = "Keisuke Takahashi",  tier = 9,  lap_ms = 281200, car_name = "RX-7 FD",    avatar_url = avatar("Keisuke Takahashi") },
        { rank = 4, name = "Wataru Akiyoshi",    tier = 8,  lap_ms = 284500, car_name = "Levin AE86", avatar_url = avatar("Wataru Akiyoshi") },
        { rank = 5, name = "Itsuki Takeuchi",    tier = 5,  lap_ms = 292300, car_name = "AE85 Levin", avatar_url = avatar("Itsuki Takeuchi") },
    },

    -- Misma pista, tabla RX-7 FC (otro combo de coche)
    ["projectd-touge-01@akina@downhill@rx7_fc"] = {
        { rank = 1, name = "Ryosuke Takahashi",  tier = 10, lap_ms = 276900, car_name = "RX-7 FC",    avatar_url = avatar("Ryosuke Takahashi") },
        { rank = 2, name = "Shinji Inui",        tier = 9,  lap_ms = 278400, car_name = "Silvia S15", avatar_url = avatar("Shinji Inui") },
        { rank = 3, name = "Keisuke Takahashi",  tier = 9,  lap_ms = 280100, car_name = "RX-7 FD",    avatar_url = avatar("Keisuke Takahashi") },
        { rank = 4, name = "Kyoichi Sudo",       tier = 8,  lap_ms = 283600, car_name = "Evo IV",     avatar_url = avatar("Kyoichi Sudo") },
        { rank = 5, name = "Seiji Iwaki",        tier = 6,  lap_ms = 289800, car_name = "Evo IV",     avatar_url = avatar("Seiji Iwaki") },
    },

    -- Akina uphill
    ["projectd-touge-01@akina@uphill@ae86_trueno"] = {
        { rank = 1, name = "Bunta Fujiwara",     tier = 10, lap_ms = 301200, car_name = "Trueno AE86", avatar_url = avatar("Bunta Fujiwara") },
        { rank = 2, name = "Takumi Fujiwara",    tier = 9,  lap_ms = 305800, car_name = "Trueno AE86", avatar_url = avatar("Takumi Fujiwara") },
        { rank = 3, name = "Ryosuke Takahashi",  tier = 9,  lap_ms = 306100, car_name = "RX-7 FC",    avatar_url = avatar("Ryosuke Takahashi") },
        { rank = 4, name = "Nobuhiko Ueo",       tier = 8,  lap_ms = 308400, car_name = "Civic EG6",  avatar_url = avatar("Nobuhiko Ueo") },
        { rank = 5, name = "Mako Sato",          tier = 7,  lap_ms = 311500, car_name = "SilEighty",  avatar_url = avatar("Mako Sato") },
    },

    -- Segundo servidor — Myogi
    ["projectd-touge-02@myogi@downhill@ae86_trueno"] = {
        { rank = 1, name = "Kai Kogashiwa",      tier = 9,  lap_ms = 268400, car_name = "86 GT",      avatar_url = avatar("Kai Kogashiwa") },
        { rank = 2, name = "Takumi Fujiwara",    tier = 9,  lap_ms = 269100, car_name = "Trueno AE86", avatar_url = avatar("Takumi Fujiwara") },
        { rank = 3, name = "Ryosuke Takahashi",  tier = 10, lap_ms = 269800, car_name = "RX-7 FC",    avatar_url = avatar("Ryosuke Takahashi") },
        { rank = 4, name = "Kenta Ogata",        tier = 7,  lap_ms = 274200, car_name = "Sileighty",  avatar_url = avatar("Kenta Ogata") },
        { rank = 5, name = "Koichiro Iketani",   tier = 5,  lap_ms = 281900, car_name = "S13 Silvia", avatar_url = avatar("Koichiro Iketani") },
    },
}

local PROFILES = {
    ["76561198012345678"] = {
        name = "Takumi Fujiwara",
        rank = 2,
        tier = 9,
        best_lap_ms = 279650,
        avatar_url = avatar("Takumi Fujiwara"),
    },
}

function mock.get_context()
    return mock.MOCK_CONTEXT
end

function mock.get_top5()
    local ctx = mock.MOCK_CONTEXT
    local key = context_key(ctx)
    local list = LEADERBOARDS[key]

  -- Fallback: Akina downhill AE86 si no hay tabla para el combo actual
    if list == nil then
        list = LEADERBOARDS["projectd-touge-01@akina@downhill@ae86_trueno"]
    end

    local out = {}
    for i, entry in ipairs(list) do
        out[i - 1] = {
            rank = entry.rank,
            name = entry.name,
            tier = entry.tier,
            lap_ms = entry.lap_ms,
            car_name = entry.car_name or ctx.car_name,
            avatar_url = entry.avatar_url,
        }
    end
    return out
end

function mock.get_player_profile()
    local ctx = mock.MOCK_CONTEXT
    local p = PROFILES[ctx.player_steam_id]
    if p == nil then return nil end
    return {
        name = p.name,
        rank = p.rank,
        tier = p.tier,
        best_lap_ms = p.best_lap_ms,
        car_name = ctx.car_name,
        avatar_url = p.avatar_url,
        steam_id = ctx.player_steam_id,
    }
end

function mock.get_rival()
    local profile = mock.get_player_profile()
    if profile == nil or profile.rank <= 1 then return nil end

    local top5 = mock.get_top5()
    for i = 0, 4 do
        local e = top5[i]
        if e ~= nil and e.rank == profile.rank - 1 then
            return {
                name = e.name,
                rank = e.rank,
                tier = e.tier,
                best_lap_ms = e.lap_ms,
                car_name = e.car_name,
                avatar_url = e.avatar_url,
            }
        end
    end
    return nil
end

return mock
