--[[ Poll GET /hud/version — reconnect SSE when board version changes. ]]

local config = require("common.config")
local state = require("common.api.state")
local util = require("common.api.util")
local steam = require("common.api.steam")
local context = require("common.api.context")
local bundle = require("common.api.bundle")
local web_queue = require("common.api.web_queue")
local battle_sse = require("common.api.battle_sse")
local hud_transport = require("common.api.battle_transport")

local session_version = {}

function session_version.tick(ctx, now)
    now = now or os.clock()
    local interval = config.HUD_VERSION_POLL_SEC or 10
    if now < (state.version_poll_at or 0) then return end
    state.version_poll_at = now + interval

    if state.version_poll_inflight then return end
    if not context.context_is_ready(ctx) then return end
    if state.last_error == "user_invalidated" then return end

    local steam_id = steam.normalize_steam_id(ctx.player_steam_id)
    if steam_id == "" then return end

    local url = string.format(
        "%s%s?steamId=%s",
        config.API_BASE_URL,
        config.HUD_VERSION_PATH or "/hud/version",
        util.url_encode(steam_id)
    )

    state.version_poll_inflight = true
    web_queue.get(url, "hud_version", function(err, response)
        state.version_poll_inflight = false
        local _, err_reason = util.read_api_response(err, response)
        if err_reason ~= nil then return end

        local data = util.parse_json_body(util.response_body(response))
        if data == nil or type(data) ~= "table" then return end

        local ver = util.safe_str(data.version)
        if ver == "" then return end

        local prev = state.hud_version
        if prev == ver then return end

        bundle.clear_cache()
        state.hud_version = ver
        battle_sse.disconnect()
        state.battle_sse_reconnect_at = 0
        state.battle_sse_session_key = ""
        pcall(hud_transport.try_connect, ctx, os.clock())
    end)
end

return session_version
