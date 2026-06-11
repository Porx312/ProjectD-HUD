--[[ Facade: API live data or mocks for offline dev. ]]

local storage = ac.storage("ProjectD-HUD:use_api", true)
local use_api = storage:get()

if use_api then
    local ok, api_or_err = pcall(require, "common.api_data")
    if ok then
        return api_or_err
    end
    ac.debug("ProjectD-HUD api_data failed", tostring(api_or_err))
end

return require("common.mock_data")
