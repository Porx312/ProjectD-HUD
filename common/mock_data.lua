--[[
    Datos falsos — Initial D cast.
    Tier 0–10 según nivel en el anime (touge / downhill).
    Clave: serverId + trackId + layoutId [@ carId si filtro por coche]
]]

local mock = {}

mock.MOCK_CONTEXT = {
    server_id = "projectd-touge-01",
    track_id = "akina",
    track_name = "Akina",
    layout_id = "downhill",
    layout_name = "Downhill",
    car_id = "ae86_trueno",
    car_name = "Trueno AE86",
    player_steam_id = "76561198012345678",
}

--- Filtros del leaderboard (futuro: vienen del API del server).
mock.LEADERBOARD_FILTERS = {
    { id = "global",      label = "Global ranking" },
    { id = "ae86_trueno", label = "AE86" },
    { id = "rx7_fc",      label = "RX7" },
}

local function context_base(ctx)
    return ctx.server_id .. "@" .. ctx.track_id .. "@" .. ctx.layout_id
end

local function context_key(ctx, car_filter)
    local base = context_base(ctx)
    if car_filter == nil or car_filter == "global" then
        return base
    end
    return base .. "@" .. car_filter
end

local function avatar(name)
    local seed = string.gsub(name, "%s+", "")
    return "https://api.dicebear.com/7.x/notionists/png?seed=" .. seed .. "&size=128"
end

local LEADERBOARDS = {
    -- Global · Akina downhill (mix de coches)
    ["projectd-touge-01@akina@downhill"] = {
        { rank = 1, name = "Ryosuke Takahashi",  tier = 10, lap_ms = 277800, car_name = "RX-7 FC",     avatar_url = avatar("Ryosuke Takahashi") },
        { rank = 2, name = "Takumi Fujiwara",    tier = 9,  lap_ms = 279650, car_name = "Trueno AE86", avatar_url = avatar("Takumi Fujiwara") },
        { rank = 3, name = "Keisuke Takahashi",  tier = 9,  lap_ms = 281200, car_name = "RX-7 FD",     avatar_url = avatar("Keisuke Takahashi") },
        { rank = 4, name = "Wataru Akiyoshi",    tier = 8,  lap_ms = 284500, car_name = "Levin AE86",  avatar_url = avatar("Wataru Akiyoshi") },
        { rank = 5, name = "Itsuki Takeuchi",    tier = 5,  lap_ms = 292300, car_name = "AE85 Levin",  avatar_url = avatar("Itsuki Takeuchi") },
        { rank = 6, name = "Koichiro Iketani",   tier = 5,  lap_ms = 294800, car_name = "S13 Silvia",  avatar_url = avatar("Koichiro Iketani") },
        { rank = 7, name = "Kenta Ogata",        tier = 7,  lap_ms = 296200, car_name = "Sileighty",   avatar_url = avatar("Kenta Ogata") },
        { rank = 8, name = "Mako Sato",          tier = 7,  lap_ms = 298900, car_name = "SilEighty",   avatar_url = avatar("Mako Sato") },
        { rank = 9, name = "Nobuhiko Ueo",       tier = 8,  lap_ms = 300400, car_name = "Civic EG6",   avatar_url = avatar("Nobuhiko Ueo") },
        { rank = 10, name = "Shinji Inui",       tier = 9,  lap_ms = 302100, car_name = "Silvia S15",  avatar_url = avatar("Shinji Inui") },
    },

    ["projectd-touge-01@akina@downhill@ae86_trueno"] = {
        { rank = 1, name = "Bunta Fujiwara",     tier = 10, lap_ms = 278900, car_name = "Trueno AE86", avatar_url = avatar("Bunta Fujiwara") },
        { rank = 2, name = "Takumi Fujiwara",    tier = 9,  lap_ms = 279650, car_name = "Trueno AE86", avatar_url = avatar("Takumi Fujiwara") },
        { rank = 3, name = "Wataru Akiyoshi",    tier = 8,  lap_ms = 284500, car_name = "Levin AE86",  avatar_url = avatar("Wataru Akiyoshi") },
        { rank = 4, name = "Tomoyuki Tachi",     tier = 6,  lap_ms = 285100, car_name = "Evo V",       avatar_url = avatar("Tomoyuki Tachi") },
        { rank = 5, name = "Itsuki Takeuchi",    tier = 5,  lap_ms = 292300, car_name = "AE85 Levin",  avatar_url = avatar("Itsuki Takeuchi") },
        { rank = 6, name = "Koichiro Iketani",   tier = 5,  lap_ms = 298400, car_name = "S13 Silvia",  avatar_url = avatar("Koichiro Iketani") },
        { rank = 7, name = "Kai Kogashiwa",      tier = 9,  lap_ms = 299800, car_name = "86 GT",       avatar_url = avatar("Kai Kogashiwa") },
        { rank = 8, name = "Nobuhiko Ueo",       tier = 8,  lap_ms = 301500, car_name = "Civic EG6",   avatar_url = avatar("Nobuhiko Ueo") },
        { rank = 9, name = "Mako Sato",          tier = 7,  lap_ms = 303200, car_name = "SilEighty",   avatar_url = avatar("Mako Sato") },
        { rank = 10, name = "Seiji Iwaki",       tier = 6,  lap_ms = 305800, car_name = "Evo IV",      avatar_url = avatar("Seiji Iwaki") },
    },

    ["projectd-touge-01@akina@downhill@rx7_fc"] = {
        { rank = 1, name = "Ryosuke Takahashi",  tier = 10, lap_ms = 276900, car_name = "RX-7 FC",    avatar_url = avatar("Ryosuke Takahashi") },
        { rank = 2, name = "Keisuke Takahashi",  tier = 9,  lap_ms = 280100, car_name = "RX-7 FD",    avatar_url = avatar("Keisuke Takahashi") },
        { rank = 3, name = "Shinji Inui",        tier = 9,  lap_ms = 278400, car_name = "Silvia S15", avatar_url = avatar("Shinji Inui") },
        { rank = 4, name = "Kyoichi Sudo",       tier = 8,  lap_ms = 283600, car_name = "Evo IV",     avatar_url = avatar("Kyoichi Sudo") },
        { rank = 5, name = "Seiji Iwaki",        tier = 6,  lap_ms = 289800, car_name = "Evo IV",     avatar_url = avatar("Seiji Iwaki") },
        { rank = 6, name = "Tomoyuki Tachi",     tier = 6,  lap_ms = 291400, car_name = "Evo V",      avatar_url = avatar("Tomoyuki Tachi") },
        { rank = 7, name = "Kai Kogashiwa",      tier = 9,  lap_ms = 293100, car_name = "86 GT",      avatar_url = avatar("Kai Kogashiwa") },
        { rank = 8, name = "Kenta Ogata",        tier = 7,  lap_ms = 295600, car_name = "Sileighty",  avatar_url = avatar("Kenta Ogata") },
        { rank = 9, name = "Nobuhiko Ueo",       tier = 8,  lap_ms = 297200, car_name = "Civic EG6",  avatar_url = avatar("Nobuhiko Ueo") },
        { rank = 10, name = "Mako Sato",         tier = 7,  lap_ms = 299400, car_name = "SilEighty",  avatar_url = avatar("Mako Sato") },
    },

    ["projectd-touge-01@akina@uphill"] = {
        { rank = 1, name = "Bunta Fujiwara",     tier = 10, lap_ms = 301200, car_name = "Trueno AE86", avatar_url = avatar("Bunta Fujiwara") },
        { rank = 2, name = "Takumi Fujiwara",    tier = 9,  lap_ms = 305800, car_name = "Trueno AE86", avatar_url = avatar("Takumi Fujiwara") },
        { rank = 3, name = "Ryosuke Takahashi",  tier = 9,  lap_ms = 306100, car_name = "RX-7 FC",    avatar_url = avatar("Ryosuke Takahashi") },
        { rank = 4, name = "Nobuhiko Ueo",       tier = 8,  lap_ms = 308400, car_name = "Civic EG6",  avatar_url = avatar("Nobuhiko Ueo") },
        { rank = 5, name = "Mako Sato",          tier = 7,  lap_ms = 311500, car_name = "SilEighty",  avatar_url = avatar("Mako Sato") },
    },

    ["projectd-touge-02@myogi@downhill"] = {
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

local function copy_entries(list)
    local out = {}
    if list == nil then return out end
    for i, entry in ipairs(list) do
        out[i - 1] = {
            rank = entry.rank,
            name = entry.name,
            tier = entry.tier,
            lap_ms = entry.lap_ms,
            car_name = entry.car_name,
            avatar_url = entry.avatar_url,
        }
    end
    return out
end

function mock.get_context()
    return mock.MOCK_CONTEXT
end

function mock.get_leaderboard_filters()
    return mock.LEADERBOARD_FILTERS
end

function mock.get_leaderboard_header()
    local ctx = mock.get_context()
    return {
        title = "Top 10",
        map = ctx.track_name or ctx.track_id or "",
        layout = ctx.layout_name or ctx.layout_id or "",
    }
end

function mock.get_top10(car_filter)
    car_filter = car_filter or "global"
    local ctx = mock.MOCK_CONTEXT
    local key = context_key(ctx, car_filter)
    local list = LEADERBOARDS[key]

    if list == nil then
        list = LEADERBOARDS[context_base(ctx)]
    end
    if list == nil then
        list = LEADERBOARDS["projectd-touge-01@akina@downhill"]
    end

    return copy_entries(list)
end

function mock.get_top8(car_filter)
    return mock.get_top10(car_filter)
end

function mock.get_top5(car_filter)
    return mock.get_top10(car_filter)
end

--- Leaderboard del coche actual (mismo auto que conduces en pista).
local function car_leaderboard_entries()
    local ctx = mock.MOCK_CONTEXT
    return mock.get_top10(ctx.car_id)
end

function mock.get_player_profile()
    local ctx = mock.MOCK_CONTEXT
    local p = PROFILES[ctx.player_steam_id]
    if p == nil then return nil end

    local rank, tier, best_lap_ms = p.rank, p.tier, p.best_lap_ms
    local rows = car_leaderboard_entries()
    for i = 0, 9 do
        local e = rows[i]
        if e ~= nil and e.name == p.name then
            rank = e.rank
            tier = e.tier
            best_lap_ms = e.lap_ms
            break
        end
    end

    return {
        name = p.name,
        rank = rank,
        tier = tier,
        best_lap_ms = best_lap_ms,
        car_name = ctx.car_name,
        car_id = ctx.car_id,
        avatar_url = p.avatar_url,
        steam_id = ctx.player_steam_id,
    }
end

function mock.tick() end

function mock.get_status_message(kind)
    if kind == "profile" then return "No profile data" end
    if kind == "rival" then return "No rival data" end
    return "No data"
end

function mock.get_rival()
    local profile = mock.get_player_profile()
    if profile == nil or profile.rank <= 1 then return nil end

    local rows = car_leaderboard_entries()
    for i = 0, 9 do
        local e = rows[i]
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
