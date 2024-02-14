local str_util = require "oil-vcs-status.util.str"

local M = {}

M.level = vim.log.levels.WARN

---@param level number
---@param ... string
function M.notify(level, ...)
    if level < M.level then return end

    local buffer = { ... }
    for i = 1, #buffer do
        buffer[i] = tostring(buffer[i])
    end

    local str = ("[oil-vcs-status %s] %s"):format(
        str_util.get_time_str(),
        table.concat(buffer, " ")
    )
    vim.notify(str, level)
end

---@param ... any
function M.trace(...)
    M.notify(vim.log.levels.TRACE, ...)
end

---@param ... any
function M.debug(...)
    M.notify(vim.log.levels.DEBUG, ...)
end

---@param ... any
function M.info(...)
    M.notify(vim.log.levels.INFO, ...)
end

---@param ... any
function M.warn(...)
    M.notify(vim.log.levels.WARN, ...)
end

---@param ... any
function M.error(...)
    M.notify(vim.log.levels.ERROR, ...)
end

return M
