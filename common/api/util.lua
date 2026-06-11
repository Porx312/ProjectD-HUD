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

function util.parse_json_body(body)
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

    return nil
end

function util.decode_json(body)
    local data = util.parse_json_body(body)
    if data == nil and body ~= nil and util.safe_str(body) ~= "" then
        state.last_error = "json_parse_failed"
    end
    return data
end

--- Parse ac-data response even when HTTP status is 404 (body is often { ok:false, reason }).
function util.read_api_response(err, response)
    if util.is_web_error(err) then
        return nil, "network_error", false
    end

    local code = util.http_status_code(response)
    local raw = util.parse_json_body(util.response_body(response))
    if raw == nil and type(response) == "table" then
        if response.ok ~= nil or response.reason ~= nil or response.entries ~= nil or response.leaderboard ~= nil then
            raw = response
        end
    end

    if raw ~= nil and raw.ok == false then
        local reason = tostring(raw.reason or "api_error")
        local retry_server = reason == "server_not_found" or reason == "track_not_found"
        return raw, reason, retry_server
    end

    if code ~= nil and code ~= 200 then
        if raw ~= nil and raw.reason ~= nil then
            local reason = tostring(raw.reason)
            return raw, reason, reason == "server_not_found" or reason == "track_not_found"
        end
        local retry = code == 404 or code == 502 or code == 503 or code == 504
        return raw, "http_" .. tostring(code), retry
    end

    if raw == nil and util.http_response_ok(response) then
        return nil, "json_parse_failed", false
    end

    return raw, nil, false
end

function util.url_encode(str)
    str = util.safe_str(str)
    if str == "" then return "" end
    return string.gsub(str, "([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

function util.trim_server_name(name)
    name = util.safe_str(name)
    if name == "" then return "" end
    name = name:gsub("[%s%p]*[ℹiI]%d+%s*$", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

--- Short label: first segment of "ProjectD | Track | Mode | ...".
function util.normalize_server_name(name)
    name = util.trim_server_name(name)
    if name == "" then return "" end
    local pipe = name:find("|", 1, true)
    if pipe ~= nil then
        name = name:sub(1, pipe - 1)
    end
    return util.trim_server_name(name)
end

function util.count_table_entries(list)
    if list == nil or type(list) ~= "table" then return 0 end
    local count = 0
    for _, entry in ipairs(list) do
        if type(entry) == "table" then count = count + 1 end
    end
    if count > 0 then return count end
    for _, entry in pairs(list) do
        if type(entry) == "table" then count = count + 1 end
    end
    return count
end

function util.count_ui_rows(rows)
    if rows == nil or type(rows) ~= "table" then return 0 end
    local count = 0
    for i = 0, 128 do
        if rows[i] == nil then break end
        count = count + 1
    end
    return count
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
