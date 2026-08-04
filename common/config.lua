--[[ ProjectD HUD — ac-data API (unified SSE stream) ]]

local config = {}

config.API_BASE_URL = "https://dev-api.projectd.space"
config.HUD_STREAM_PATH = "/hud/stream"
config.HUD_SNAPSHOT_PATH = "/hud/snapshot"
config.HUD_SNAPSHOT_POLL_SEC = 5
config.HUD_SNAPSHOT_BATTLE_POLL_SEC = 2
config.HUD_VERSION_PATH = "/hud/version"
config.HUD_VERSION_POLL_SEC = 5
config.HUD_SSE_RECONNECT_SEC = 3
config.BATTLE_RESULT_HOLD_SEC = 5
config.BATTLE_CANCEL_HOLD_SEC = 5
config.BATTLE_EVENT_TOAST_SEC = 3.5

return config
