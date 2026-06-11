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

--- Strip invisible/control chars that Wine sometimes injects into sim strings.
function util.sanitize_param(value)
    value = util.safe_str(value)
    if value == "" then return "" end
    if string.sub(value, 1, 3) == "\239\187\191" then
        value = string.sub(value, 4)
    end
    value = value:gsub("%c", "")
    return value:gsub("%s+$", ""):gsub("^%s+", "")
end

--- CSP allows only 2 concurrent web.get; normalize callback args defensively (Wine varies).
function util.normalize_web_response(err, response)
    if type(err) == "number" and response ~= nil then
        if type(response) == "string" then
            return nil, { status = err, body = response }
        end
        if type(response) == "table" then
            if response.status == nil then response.status = err end
            return nil, response
        end
    end

    if type(err) == "boolean" then
        if err == false and util.is_web_error(response) then
            return response, nil
        end
        return nil, response
    end

    if type(err) == "table" and response == nil then
        if err.status ~= nil or err.body ~= nil or err.ok ~= nil or err.reason ~= nil then
            return nil, err
        end
        return nil, err
    end

    if type(response) == "string" and err == nil then
        return nil, { status = 200, body = response }
    end

    if type(err) == "string" and not util.is_web_error(err) and response == nil then
        return nil, { status = 200, body = err }
    end

    if type(err) == "string" and util.is_web_error(err) and type(response) == "table" then
        return err, response
    end

    return err, response
end

function util.response_snippet(response, max_len)
    max_len = max_len or 72
    local body = util.response_body(response)
    body = util.safe_str(body)
    if body == "" and type(response) == "table" then
        body = util.safe_str(response.reason or response.error)
    end
    if body == "" then return "" end
    body = body:gsub("%s+", " ")
    if #body > max_len then
        return string.sub(body, 1, max_len - 3) .. "..."
    end
    return body
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

function util.encode_json(data)
    if data == nil then return nil end
    if JSON ~= nil and JSON.stringify ~= nil then
        local ok, text = pcall(JSON.stringify, data)
        if ok and type(text) == "string" then return text end
    end
    if __util ~= nil and __util.jsonEncode ~= nil then
        local ok, text = pcall(__util.jsonEncode, data)
        if ok and type(text) == "string" then return text end
    end
    if __util ~= nil and __util.json ~= nil then
        local ok, text = pcall(__util.json, data)
        if ok and type(text) == "string" then return text end
    end
    return nil
end

function util.decode_json_quiet(body)
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
    local data = util.decode_json_quiet(body)
    if data == nil and body ~= nil and util.safe_str(body) ~= "" and state ~= nil then
        state.last_error = "json_parse_failed"
    end
    return data
end

--- ac-data returns HTTP 404 with JSON { ok:false, reason:"server_not_found" } — parse before treating as generic 404.
function util.read_api_payload(err, response)
    if util.is_web_error(err) then
        return nil, "network_error", util.http_status_code(response)
    end

    local raw = util.decode_json_quiet(util.response_body(response))
    if raw == nil and type(response) == "table" and (response.ok ~= nil or response.reason ~= nil or response.error ~= nil) then
        raw = response
    end

    local code = util.http_status_code(response)
    if raw ~= nil and raw.ok == false then
        local reason = util.safe_str(raw.reason or raw.error)
        if reason ~= "" then return raw, reason, code end
    end

    if not util.http_response_ok(response) then
        return raw, "http_" .. tostring(code or "nil"), code
    end

    if raw == nil then
        return nil, "json_parse_failed", code
    end

    return raw, nil, code
end

function util.url_encode(str)
    str = util.safe_str(str)
    if str == "" then return "" end
    return string.gsub(str, "([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

function util.normalize_server_name(name)
    name = util.sanitize_param(name)
    if name == "" then return "" end
    name = name:gsub("[%s%p]*[ℹiI]%d+%s*$", "")
    name = name:gsub("%s+$", "")
    return name
end

function util.build_query_url(base_url, path, ordered_params)
    local parts = {}
    for _, pair in ipairs(ordered_params or {}) do
        local key = util.safe_str(pair[1])
        local value = util.sanitize_param(pair[2])
        if key ~= "" and value ~= "" then
            parts[#parts + 1] = util.url_encode(key) .. "=" .. util.url_encode(value)
        end
    end
    if #parts == 0 then
        return util.safe_str(base_url) .. util.safe_str(path)
    end
    return util.safe_str(base_url) .. util.safe_str(path) .. "?" .. table.concat(parts, "&")
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
