--[[ ProjectD HUD — API base URL (ac-data on VPS) ]]

local config = {}

config.API_BASE_URL = "http://13.140.160.131:3000"
config.SESSION_PATH = "/hud/session"
config.VERSION_PATH = "/hud/version"
config.TOP10_PATH = "/hud/top10"
config.PLAYER_PATH = "/hud/player"
config.BATTLE_VERSION_PATH = "/hud/battle/version"
config.BATTLE_PATH = "/hud/battle"
config.BATTLE_POLL_IDLE_MS = 2000
config.BATTLE_POLL_LOBBY_MS = 1000
config.BATTLE_POLL_LOBBY_MS_SLOW = 2000
config.BATTLE_POLL_PREP_MS = 500
config.BATTLE_POLL_PREP_MS_SLOW = 1000
config.BATTLE_POLL_ACTIVE_MS = 500
config.BATTLE_POLL_ACTIVE_MS_SLOW = 2000
config.BATTLE_RATE_LIMIT_KEY_PER_MIN = 110
config.BATTLE_RATE_LIMIT_NO_KEY_PER_MIN = 28
config.BATTLE_RESULT_HOLD_SEC = 3
config.BATTLE_CANCEL_HOLD_SEC = 2
config.BATTLE_BACKOFF_SEC = 2.5
config.BATTLE_EVENT_TOAST_SEC = 2
config.CACHE_TTL_SEC = 15
config.FILTER_CACHE_TTL_SEC = 90
config.VERSION_POLL_INTERVAL_SEC = 2.5
config.HUD_CACHE_SYNC_INTERVAL_SEC = 120
config.HUD_CACHE_SYNC_SKIP_AFTER_REFRESH_SEC = 90

--- Optional display-name fallbacks if race.ini / sim lack SERVER_NAME.
config.SERVER_NAME_FALLBACKS = { "ProjectD" }

return config
