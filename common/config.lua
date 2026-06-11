--[[ ProjectD HUD — API base URL (ac-data on VPS) ]]

local config = {}

config.API_BASE_URL = "http://176.57.150.251:3000"
config.API_BASE_URLS = {
    "http://176.57.150.251:3000",
}
config.SESSION_PATH = "/hud/session"
config.PLAYER_PATH = "/hud/player"
config.CACHE_TTL_SEC = 10
--- Leaderboard por coche: se reutiliza al volver a un filtro ya cargado.
config.FILTER_CACHE_TTL_SEC = 90

--- Slugs Convex/telemetry si sim.serverName no resuelve (ej. "server-1").
config.SERVER_SLUG_FALLBACKS = {}

return config
