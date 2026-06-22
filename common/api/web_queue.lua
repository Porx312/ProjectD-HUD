--[[ Serializes all web.get calls (CSP max 2 concurrent; 3 HUD windows share this queue). ]]

local state = require("common.api.state")
local util = require("common.api.util")

local web_queue = {}

local function battle_poll_priority()
    local now = os.clock()
    if now < (state.battle_result_hold_until or 0) and state.battle_finish_latch_snapshot ~= nil then
        return true
    end
    if state.battle_fetch_pending or state.battle_version_pending then
        return true
    end
    local applied = util.safe_str(state.battle_applied_version)
    if applied ~= "" and applied ~= "0" then return true end
    if state.battle_ui ~= nil then return true end
    return false
end

local function battle_queue_insert(item, kind)
    kind = kind or "http"
    if not battle_poll_priority() or (kind ~= "battle" and kind ~= "battle_version") then
        state.web_queue[#state.web_queue + 1] = item
        return
    end
    if kind == "battle" then
        table.insert(state.web_queue, 1, item)
        return
    end
    local insert_at = 1
    for i = 1, #state.web_queue do
        if state.web_queue[i].kind ~= "battle" then
            insert_at = i
            break
        end
        insert_at = i + 1
    end
    table.insert(state.web_queue, insert_at, item)
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

function web_queue.pump()
    if state.web_inflight ~= nil then return end
    local q = state.web_queue
    if q == nil or #q == 0 then return end

    ensure_web_timeouts()
    local item = table.remove(q, 1)
    state.web_inflight = item.kind
    state.last_fetch_url = item.url
    state.last_fetch_kind = item.kind or ""

    if web == nil or web.get == nil then
        state.web_inflight = nil
        log_event(item.kind .. " fail", "web_unavailable")
        item.callback("web_unavailable", nil)
        web_queue.pump()
        return
    end

    log_event(item.kind .. " start", item.url)
    local ok, err_call = pcall(web.get, item.url, function(a, b)
        state.web_inflight = nil
        local err, response = util.normalize_web_response(a, b)
        local code = util.http_status_code(response)
        if util.is_web_error(err) then
            log_event(item.kind .. " err", tostring(err))
        else
            log_event(item.kind .. " ok", "http=" .. tostring(code or "?"))
        end
        item.callback(err, response)
        web_queue.pump()
    end)
    if not ok then
        state.web_inflight = nil
        log_event(item.kind .. " throw", tostring(err_call))
        item.callback(tostring(err_call), nil)
        web_queue.pump()
    end
end

function web_queue.get(url, kind, callback)
    if state.web_queue == nil then state.web_queue = {} end
    local item = {
        url = url,
        kind = kind or "http",
        callback = callback,
    }
    kind = kind or "http"
    battle_queue_insert(item, kind)
    web_queue.pump()
end

return web_queue
