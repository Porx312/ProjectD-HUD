--[[ Facade: API live data or mocks for offline dev. ]]

local storage = ac.storage("ProjectD-HUD:use_api", true)
local use_api = storage:get()

if use_api then
    local ok, api_or_err = pcall(require, "common.api_data")
    if ok then
        return api_or_err
    end
    ac.debug("ProjectD-HUD api_data failed", tostring(api_or_err))
    local mock = require("common.mock_data")
    local err_text = tostring(api_or_err)
    function mock.get_status_message(kind)
        if kind == "leaderboard" or kind == "profile" or kind == "rival" then
            return "HUD API error — reinstall full ProjectD-HUD folder"
        end
        return err_text
    end
    function mock.get_diag_lines()
        return { "mode=mock", "err=api_data failed to load" }
    end
    function mock.should_show_diag() return true end
    return mock
end

local mock = require("common.mock_data")
function mock.get_diag_lines() return { "mode=mock", "use_api=false" } end
function mock.should_show_diag() return false end
return mock
