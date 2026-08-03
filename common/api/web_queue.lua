--[[ Serializes web.get calls (CSP max 2 concurrent; SSE stream uses one slot). ]]

local state = require("common.api.state")
local util = require("common.api.util")

local web_queue = {}

local MAX_INFLIGHT = 2

local function log_event(kind, detail)
    state.last_web_event = util.safe_str(detail)
    ac.debug("ProjectD-HUD " .. kind, state.last_web_event)
end

local function ensure_web_timeouts(long_read)
    if web ~= nil and web.timeouts ~= nil then
        if long_read then
            pcall(web.timeouts, 5000, 60000, 0, 0)
        else
            pcall(web.timeouts, 3000, 8000, 12000, 15000)
        end
    end
end

function web_queue.inflight_count()
    local n = 0
    if state.web_inflight ~= nil then n = n + 1 end
    if state.web_stream ~= nil then n = n + 1 end
    return n
end

function web_queue.queue_len()
    local q = state.web_queue or {}
    return #q + web_queue.inflight_count()
end

function web_queue.is_busy()
    return web_queue.inflight_count() > 0 or #(state.web_queue or {}) > 0
end

local function extract_chunk(a, b)
    if type(a) == "string" and a ~= "" then
        if b == nil or type(b) == "number" then return a end
    end
    if type(b) == "string" and b ~= "" then return b end
    if type(a) == "table" then
        local body = util.response_body(a)
        if body ~= nil and body ~= "" then return body end
    end
    return nil
end

local function start_stream_item(item)
    ensure_web_timeouts(true)
    state.last_fetch_url = item.url
    state.last_fetch_kind = item.kind or "hud_sse"

    if web == nil or web.get == nil then
        state.web_stream = nil
        log_event(item.kind .. " fail", "web_unavailable")
        if item.callbacks and item.callbacks.on_complete then
            item.callbacks.on_complete("web_unavailable", nil)
        end
        return
    end

    log_event(item.kind .. " start", item.url)

    local function on_done(a, b)
        local err, response = util.normalize_web_response(a, b)
        if item.callbacks and item.callbacks.on_response then
            item.callbacks.on_response(err, response)
        end

        if item.expect_persistent and not util.is_web_error(err) then
            local code = util.http_status_code(response)
            if code == nil or code == 200 then
                if response ~= nil and response.complete == false then return end
                if response ~= nil and response.finished == false then return end
                if state.web_stream == item then return end
            end
        end

        state.web_stream = nil
        local code = util.http_status_code(response)
        if util.is_web_error(err) then
            log_event(item.kind .. " err", tostring(err))
        else
            log_event(item.kind .. " closed", "http=" .. tostring(code or "?"))
        end
        if item.callbacks and item.callbacks.on_complete then
            item.callbacks.on_complete(err, response)
        end
        ensure_web_timeouts(false)
        web_queue.pump()
    end

    local function on_chunk(a, b)
        local chunk = extract_chunk(a, b)
        if chunk ~= nil and item.callbacks and item.callbacks.on_chunk then
            item.callbacks.on_chunk(chunk)
        end
    end

    local function start_get()
        if type(web.request) == "function" then
            return web.request({
                url = item.url,
                method = "GET",
                headers = {
                    ["Accept"] = "text/event-stream",
                    ["Cache-Control"] = "no-cache",
                },
            }, on_done, on_chunk)
        end
        return web.get(item.url, on_done, on_chunk)
    end

    local ok, result = pcall(start_get)

    if not ok then
        item.streaming_via = "get_no_chunk"
        log_event(item.kind .. " warn", "web.request failed — web.get may buffer SSE until close")
        local ok2 = pcall(function()
            item.request = web.get(item.url, on_done)
        end)
        if not ok2 then
            state.web_stream = nil
            log_event(item.kind .. " throw", tostring(result))
            if item.callbacks and item.callbacks.on_complete then
                item.callbacks.on_complete(tostring(result), nil)
            end
            ensure_web_timeouts(false)
            web_queue.pump()
            return
        end
    elseif type(result) == "table" or type(result) == "userdata" then
        item.request = result
        item.streaming_via = "request"
    else
        item.streaming_via = "get"
    end

    if item.kind == "hud_sse" or item.kind == "battle_sse" then
        if item.callbacks and item.callbacks.on_open then
            pcall(item.callbacks.on_open)
        end
    end
end

function web_queue.poll_stream()
    local item = state.web_stream
    if item == nil then return end

    if item.request ~= nil then
        local req = item.request
        if req.ready == true and req.result ~= nil then
            if item.callbacks and item.callbacks.on_response then
                item.callbacks.on_response(nil, req.result)
            end
            return
        end
        local body = req.body or req.text or req.responseBody
        if body == nil or body == "" then return end
        item.last_body_len = item.last_body_len or 0
        if #body > item.last_body_len then
            local delta = body:sub(item.last_body_len + 1)
            item.last_body_len = #body
            if item.callbacks and item.callbacks.on_chunk then
                item.callbacks.on_chunk(delta)
            end
            if item.callbacks and item.callbacks.on_response then
                item.callbacks.on_response(nil, {
                    body = body,
                    complete = false,
                    finished = false,
                })
            end
        end
    end
end

function web_queue.open_stream(item)
    if state.web_stream ~= nil then return false end
    if web_queue.inflight_count() >= MAX_INFLIGHT then return false end
    state.web_stream = item
    start_stream_item(item)
    return true
end

function web_queue.close_stream(kind)
    if state.web_stream == nil then return end
    if kind ~= nil and kind ~= "" and state.web_stream.kind ~= kind then return end
    local item = state.web_stream
    state.web_stream = nil
    if web ~= nil then
        if web.cancel ~= nil and item.request ~= nil then
            pcall(web.cancel, item.request)
        end
        if web.abort ~= nil and item.request ~= nil then
            pcall(web.abort, item.request)
        end
    end
    ensure_web_timeouts(false)
end

function web_queue.pump()
    if state.web_inflight ~= nil then return end
    if web_queue.inflight_count() >= MAX_INFLIGHT then return end
    local q = state.web_queue
    if q == nil or #q == 0 then return end

    ensure_web_timeouts(false)
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
    if kind == "avatar" then
        table.insert(state.web_queue, 1, item)
    else
        state.web_queue[#state.web_queue + 1] = item
    end
    web_queue.pump()
end

return web_queue
