--[[ HTTP / fetch diagnostics. ]]

return {
    last_http_status = nil,
    last_error = nil,
    last_fetch_url = "",
    last_fetch_kind = "",
    last_web_event = "",
    web_inflight = nil,
    web_queue = {},
    web_stream = nil,
}
