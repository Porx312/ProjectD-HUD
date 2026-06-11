--[[ Cross-window sync via ac.storage (survives separate Lua app instances per widget). ]]

local state = require("common.api.state")
local util = require("common.api.util")
local bundle = require("common.api.bundle")

local sync = {}

local ver_storage = ac.storage("ProjectD-HUD:sync_ver", 0)
local json_storage = ac.storage("ProjectD-HUD:sync_json", "")
local filter_storage = ac.storage("ProjectD-HUD:sync_filter", "global")
local err_storage = ac.storage("ProjectD-HUD:sync_error", "")
local web_storage = ac.storage("ProjectD-HUD:sync_web", "")
local fetch_storage = ac.storage("ProjectD-HUD:sync_fetch", 0)
local prof_storage = ac.storage("ProjectD-HUD:sync_prof", 0)
local lock_storage = ac.storage("ProjectD-HUD:g_fetch_lock", "")
local init_storage = ac.storage("ProjectD-HUD:did_init", false)
local tick_storage = ac.storage("ProjectD-HUD:last_tick_at", 0)

function sync.tick_throttle_ok()
    local now = os.clock()
    local last = tick_storage:get() or 0
    if (now - last) < state.TICK_INTERVAL_SEC then return false end
    tick_storage:set(now)
    return true
end

function sync.mark_inited()
    init_storage:set(true)
end

function sync.was_inited()
    return init_storage:get() == true
end

function sync.clear_init()
    init_storage:set(false)
end

function sync.acquire_fetch_lock(car_filter)
    local now = os.clock()
    local raw = lock_storage:get() or ""
    if raw ~= "" then
        local sep = raw:find("|", 1, true)
        local ts = sep and tonumber(raw:sub(sep + 1)) or 0
        if ts > 0 and (now - ts) < 20 then
            return false
        end
    end
    lock_storage:set(tostring(car_filter or "global") .. "|" .. tostring(now))
    return true
end

function sync.release_fetch_lock()
    lock_storage:set("")
    fetch_storage:set(0)
    prof_storage:set(0)
end

function sync.is_fetch_locked()
    local raw = lock_storage:get() or ""
    if raw == "" then return false end
    local sep = raw:find("|", 1, true)
    local ts = sep and tonumber(raw:sub(sep + 1)) or 0
    return ts > 0 and (os.clock() - ts) < 20
end

function sync.publish_meta()
    err_storage:set(util.safe_str(state.last_error))
    web_storage:set(util.safe_str(state.last_web_event))
    fetch_storage:set(state.fetch_pending and 1 or 0)
    prof_storage:set(state.profile_fetch_pending and 1 or 0)
end

function sync.pull_meta()
    local err = err_storage:get() or ""
    if err ~= "" then state.last_error = err end
    local web = web_storage:get() or ""
    if web ~= "" then state.last_web_event = web end
    if (fetch_storage:get() or 0) == 1 then state.fetch_pending = true end
    if (prof_storage:get() or 0) == 1 then state.profile_fetch_pending = true end
end

function sync.publish_bundle(car_filter)
    if state.cached_bundle == nil then
        sync.publish_meta()
        return
    end
    local payload = {
        ok = true,
        filter = car_filter or state.cached_filter or "global",
        profile = state.cached_bundle.profile,
        leaderboard = state.cached_bundle.leaderboard,
        context = state.cached_bundle.context,
        t = os.clock(),
    }
    local blob = util.encode_json(payload)
    if blob == nil or blob == "" then
        sync.publish_meta()
        return
    end
    local ver = (ver_storage:get() or 0) + 1
    ver_storage:set(ver)
    json_storage:set(blob)
    filter_storage:set(payload.filter)
    state.local_sync_ver = ver
    sync.publish_meta()
end

function sync.pull_bundle()
    sync.pull_meta()
    local ver = ver_storage:get() or 0
    if ver <= 0 then return false end
    if (state.local_sync_ver or 0) >= ver then return false end
    local blob = json_storage:get() or ""
    if blob == "" then return false end
    local data = util.decode_json(blob)
    if data == nil or type(data) ~= "table" then return false end

    local car_filter = data.filter or filter_storage:get() or "global"
    local merged = {
        ok = true,
        context = data.context,
        profile = data.profile,
        leaderboard = data.leaderboard,
    }
    bundle.apply_bundle(merged, car_filter)
    state.local_sync_ver = ver
    state.fetch_pending = false
    state.profile_fetch_pending = false
    return true
end

function sync.on_session_reset()
    ver_storage:set(0)
    json_storage:set("")
    filter_storage:set("global")
    err_storage:set("")
    web_storage:set("")
    fetch_storage:set(0)
    prof_storage:set(0)
    lock_storage:set("")
    init_storage:set(false)
    tick_storage:set(0)
    state.local_sync_ver = 0
end

return sync
