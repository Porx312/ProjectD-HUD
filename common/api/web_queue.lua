--[[ Serializes web.get with priority: session(0) < profile(1) < avatar(2). ]]

local state = require("common.api.state")
local util = require("common.api.util")
local http_client = require("common.api.http_client")

local web_queue = {}

local PRIORITY = {
    session = 0,
    profile = 1,
    avatar = 2,
    http = 1,
}

local function priority_for(kind)
    if kind == nil then return 1 end
    return PRIORITY[kind] or 1
end

local function log_event(kind, detail)
    state.last_web_event = util.safe_str(detail)
    ac.debug("ProjectD-HUD " .. kind, state.last_web_event)
end

local function ensure_web_timeouts()
    if web ~= nil and web.timeouts ~= nil then
        pcall(web.timeouts, 3000, 8000, 12000, 15000)
    end
end

function web_queue.queue_len()
    local q = state.web_queue or {}
    local n = #q
    if state.web_inflight ~= nil then n = n + 1 end
    return n
end

function web_queue.is_busy()
    return state.web_inflight ~= nil or #(state.web_queue or {}) > 0
end

function web_queue.watchdog()
    if state.web_inflight == nil then return end
    local started = state.web_inflight_started_at or 0
    if started <= 0 or (os.clock() - started) < 10 then return end
    ac.debug("ProjectD-HUD web", "inflight timeout " .. tostring(state.web_inflight))
    state.last_web_event = "web_stuck:" .. tostring(state.web_inflight)
    state.last_error = "web_stuck"
    state.web_inflight = nil
    state.web_inflight_started_at = 0
    state.fetch_pending = false
    state.profile_fetch_pending = false
    local ok_sync, sync = pcall(require, "common.api.sync")
    if ok_sync and sync ~= nil then
        pcall(sync.release_fetch_lock)
        pcall(sync.publish_meta)
    end
    web_queue.pump()
end

function web_queue.pump()
    if state.web_inflight ~= nil then return end
    local q = state.web_queue
    if q == nil or #q == 0 then return end

    ensure_web_timeouts()
    local item = table.remove(q, 1)
    state.web_inflight = item.kind
    state.web_inflight_started_at = os.clock()
    state.last_fetch_url = item.url
    state.last_fetch_kind = item.kind or ""

    log_event(item.kind .. " start", item.url)
    if not http_client.dispatch(item.url, item, web_queue.pump) then
        state.web_inflight = nil
        state.web_inflight_started_at = 0
        state.last_http_transport = "none"
        log_event(item.kind .. " fail", "web_unavailable")
        item.callback("web_unavailable", nil)
        web_queue.pump()
    end
end

function web_queue.get(url, kind, callback, priority)
    if state.web_queue == nil then state.web_queue = {} end
    local item = {
        url = url,
        kind = kind or "http",
        callback = callback,
        priority = priority or priority_for(kind),
    }
    local q = state.web_queue
    local inserted = false
    for i = 1, #q do
        if (q[i].priority or 1) > item.priority then
            table.insert(q, i, item)
            inserted = true
            break
        end
    end
    if not inserted then
        q[#q + 1] = item
    end
    web_queue.pump()
end

return web_queue
