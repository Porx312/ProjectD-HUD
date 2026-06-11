--[[ HTTP transport for CSP — web.request / web.get with Wine/Linux-safe callbacks. ]]

local state = require("common.api.state")
local util = require("common.api.util")

local http_client = {}

local function finish_callback(item, pump, err, response)
    state.web_inflight = nil
    state.web_inflight_started_at = 0
    local norm_err, norm_resp = util.normalize_web_response(err, response)
    local code = util.http_status_code(norm_resp)
    if util.is_web_error(norm_err) then
        state.last_web_event = item.kind .. " err " .. tostring(norm_err)
    else
        state.last_web_event = item.kind .. " ok http=" .. tostring(code or "?")
    end
    state.last_response_snip = util.response_snippet(norm_resp)
    item.callback(norm_err, norm_resp)
    if pump ~= nil then pump() end
end

local function try_web_request(url, item, pump)
    if web == nil or web.request == nil then return false end
    local ok, err_call = pcall(web.request, {
        url = url,
        method = "GET",
        headers = {
            ["Accept"] = "application/json",
            ["User-Agent"] = "ProjectD-HUD/" .. util.safe_str(state.hud_version),
        },
    }, function(a, b)
        finish_callback(item, pump, a, b)
    end)
    if not ok then
        ac.debug("ProjectD-HUD web.request throw", tostring(err_call))
        return false
    end
    state.last_http_transport = "web.request"
    return true
end

local function try_web_get(url, item, pump)
    if web == nil or web.get == nil then return false end
    local ok, err_call = pcall(web.get, url, function(a, b)
        finish_callback(item, pump, a, b)
    end)
    if not ok then
        ac.debug("ProjectD-HUD web.get throw", tostring(err_call))
        return false
    end
    state.last_http_transport = "web.get"
    return true
end

local function try_ac_http(url, item, pump)
    if ac == nil or ac.httpRequest == nil then return false end
    local ok, err_call = pcall(ac.httpRequest, {
        url = url,
        method = "GET",
        headers = "Accept: application/json\r\nUser-Agent: ProjectD-HUD\r\n",
    }, function(a, b)
        finish_callback(item, pump, a, b)
    end)
    if not ok then
        ac.debug("ProjectD-HUD ac.httpRequest throw", tostring(err_call))
        return false
    end
    state.last_http_transport = "ac.httpRequest"
    return true
end

function http_client.dispatch(url, item, pump)
    state.last_http_transport = ""
    if try_web_request(url, item, pump) then return true end
    if try_web_get(url, item, pump) then return true end
    if try_ac_http(url, item, pump) then return true end
    return false
end

return http_client
