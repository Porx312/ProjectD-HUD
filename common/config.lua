--[[ ProjectD HUD — API base URL (ac-data on VPS) ]]

local config = {}

config.API_BASE_URL = "http://13.140.160.131:3000"
config.SESSION_PATH = "/hud/session"
config.VERSION_PATH = "/hud/version"
config.TOP10_PATH = "/hud/top10"
config.PLAYER_PATH = "/hud/player"
config.BATTLE_STREAM_PATH = "/hud/battle/stream"
config.BATTLE_SSE_RECONNECT_SEC = 3
config.BATTLE_SSE_IDLE_ROTATE_SEC = 12
config.BATTLE_RESULT_HOLD_SEC = 5
config.BATTLE_CANCEL_HOLD_SEC = 5
config.BATTLE_EVENT_TOAST_SEC = 3.5
--- Internal battle server ids (telemetry Redis keys), tried after race.ini / sim.
config.BATTLE_SERVER_DEFAULTS = { "testing" }
config.CACHE_TTL_SEC = 15
config.FILTER_CACHE_TTL_SEC = 90
config.VERSION_POLL_INTERVAL_SEC = 2.5
config.HUD_CACHE_SYNC_INTERVAL_SEC = 120
config.HUD_CACHE_SYNC_SKIP_AFTER_REFRESH_SEC = 90
--- Optional display-name fallbacks if race.ini / sim lack SERVER_NAME.
config.SERVER_NAME_FALLBACKS = { "ProjectD" }

return config
