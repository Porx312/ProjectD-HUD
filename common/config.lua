--[[ ProjectD HUD — API base URL (ac-data on VPS) ]]

local config = {}

config.API_BASE_URL = "http://176.57.150.251:3000"
config.SESSION_PATH = "/hud/session"
config.TOP10_PATH = "/hud/top10"
config.PLAYER_PATH = "/hud/player"
config.CACHE_TTL_SEC = 15
config.FILTER_CACHE_TTL_SEC = 90

--- Optional display-name fallbacks if race.ini / sim lack SERVER_NAME.
config.SERVER_NAME_FALLBACKS = { "ProjectD" }

return config
