--[[ HTTP/JSON/string helpers for ProjectD HUD API client. ]]

local state = require("common.api.state")

local util = {}

function util.safe_str(value)
    if value == nil then return "" end
    if type(value) == "string" then return value end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    local ok, text = pcall(tostring, value)
    if ok and text ~= nil then return text end
    return ""
end

function util.safe_call(fn)
    local ok, value = pcall(fn)
    if not ok then return nil end
    return value
end

function util.is_web_error(err)
    if err == nil or err == false then return false end
    if type(err) == "string" and err == "" then return false end
    return true
end

--- CSP allows only 2 concurrent web.get; normalize callback args defensively.
function util.normalize_web_response(err, response)
    if type(err) == "table" and response == nil then
        return nil, err
    end
    if type(response) == "string" and err == nil then
        return nil, { status = 200, body = response }
    end
    if type(err) == "string" and not util.is_web_error(err) and response == nil then
        return nil, { status = 200, body = err }
    end
    return err, response
end

function util.http_status_code(response)
    if response == nil or type(response) ~= "table" then return nil end
    return tonumber(response.status)
end

function util.http_response_ok(response)
    if response == nil then return false end
    if type(response) == "string" then return true end
    local code = util.http_status_code(response)
    if code == nil then return true end
    return code == 200
end

function util.response_body(response)
    if response == nil then return nil end
    if type(response) == "string" then return response end
    if type(response) == "table" then
        return response.body or response.text or response.content or response.data
    end
    return nil
end

function util.decode_json(body)
    if type(body) == "table" then return body end
    if body == nil then return nil end
    body = util.safe_str(body)
    if body == "" then return nil end

    if JSON ~= nil and JSON.parse ~= nil then
        local ok, data = pcall(JSON.parse, body)
        if ok and type(data) == "table" then return data end
    end

    if __util ~= nil and __util.jsonParse ~= nil then
        local ok, data = pcall(__util.jsonParse, body)
        if ok and type(data) == "table" then return data end
    end

    local ok, mod = pcall(require, "lib_jsonparse")
    if ok and mod ~= nil then
        local ok2, data = pcall(mod, body)
        if ok2 and type(data) == "table" then return data end
    end

    state.last_error = "json_parse_failed"
    return nil
end

function util.url_encode(str)
    str = util.safe_str(str)
    if str == "" then return "" end
    return string.gsub(str, "([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

function util.normalize_server_name(name)
    name = util.safe_str(name)
    if name == "" then return "" end
    name = name:gsub("[%s%p]*[ℹiI]%d+%s*$", "")
    name = name:gsub("%s+$", "")
    return name
end

function util.split_track_and_layout(track_id, layout_id)
    track_id = util.safe_str(track_id)
    layout_id = util.safe_str(layout_id)
    if layout_id ~= "" then return track_id, layout_id end
    local base, rest = track_id:match("^([^%-]+)%-(.+)$")
    if base ~= nil and rest ~= nil and rest ~= "" then
        return base, rest
    end
    return track_id, layout_id
end

return util
