local log = require "oil-vcs-status.log"
local status_const = require "oil-vcs-status.constant.status"
local StatusTree = require "oil-vcs-status.status.status_tree"
local util = require "oil-vcs-status.util"
local path_util = require "oil-vcs-status.util.path"
local table_util = require "oil-vcs-status.util.table"

local StatusType = status_const.StatusType

local M = {}

---@type table<string, oil-vcs-status.StatusType>
local STATUS_MAP = {
    [" "] = StatusType.Unmodified,
    ["!"] = StatusType.Ignored,
    ["?"] = StatusType.Untracked,
    ["M"] = StatusType.Modified,
    ["T"] = StatusType.TypeChanged,
    ["A"] = StatusType.Added,
    ["D"] = StatusType.Deleted,
    ["R"] = StatusType.Renamed,
    ["C"] = StatusType.Copied,
    ["U"] = StatusType.Unmerged,
}

-- normalized absolute path of git repo root directory
local root_dir = nil ---@type string?

local status_tree = StatusTree:new("<git root>")

---@param stdout string
local function load_status_data(stdout)
    status_tree:reset()
    if not root_dir then
        return
    end

    local lines = vim.split(stdout, "\r?\n")
    table_util.filter_in_place(lines, function(_, value)
        return value ~= ""
    end)

    for _, line in ipairs(lines) do
        local remote_status_str = line:sub(1, 1)
        local local_status_str = line:sub(2, 2)

        local path_str = line:sub(4)
        local paths
        if path_str:find(" -> ", 1, true) then
            paths = vim.split(path_str, " -> ", { plain = true })
        else
            paths = { path_str }
        end

        local remote_status = STATUS_MAP[remote_status_str]
        if not remote_status then
            log.warn(("unknown git status indicator: %q"):format(remote_status_str))
        end

        local local_status = STATUS_MAP[local_status_str]
        if not local_status then
            log.warn(("unknown git status indicator: %q"):format(local_status_str))
        end

        if remote_status and local_status then
            for _, path in ipairs(paths) do
                status_tree:update_child(path, local_status, remote_status)
            end
        end
    end
end

-- ----------------------------------------------------------------------------

-- Update git root directory path after working directory changed.
function M.update_root_dir()
    local cwd = vim.fn.getcwd()
    root_dir = path_util.find_root_by_entry(cwd, { ".git" })
    if root_dir then
        root_dir = vim.fn.fnamemodify(root_dir, ":p")
    end

    log.trace("git root updated", root_dir or "nil")
end

---@param callback fun(err?: string)
function M.update_status(callback)
    log.trace("git update status")

    if not root_dir then
        callback "git repo root not found"
        return
    end

    local opt = {
        args = { "status", "--short", "--ignored" },
        cwd = root_dir,
    }
    util.run_cmd("git", opt, function(result)
        if result.code ~= 0 then
            local err = result.stderr
            callback(err ~= "" and err or "failed to get git status")
            return
        end

        load_status_data(result.stdout)
        callback()
    end)
end

---@return boolean
function M.is_active()
    return root_dir ~= nil
end

---@param abs_path string # normalized absolute path of entry
---@return oil-vcs-status.status.EntryStatus?
function M.get_entry_status(abs_path)
    if not M.is_active() then
        return nil
    end

    local root_len = #root_dir
    if #abs_path < root_len then
        return nil
    end

    local child_path = abs_path:sub(root_len + 1)
    local entry = status_tree:get_child_by_path(child_path)
    if not entry then return nil end

    return {
        local_status = entry.local_status,
        remote_status = entry.remote_status,
    }
end

---@param abs_path string
---@return boolean
function M.check_entry_dirty(abs_path)
    if not M.is_active then
        return false
    end

    local root_len = #root_dir
    if #abs_path < root_len then
        return false
    end

    local child_path = abs_path:sub(root_len + 1)
    local entry = status_tree:get_child_by_path(child_path)
    if not entry then return false end

    return entry.is_dirty
end

---@param abs_path string
function M.clear_entry_dirty(abs_path)
    if not M.is_active then
        return false
    end

    local root_len = #root_dir
    if #abs_path < root_len then
        return false
    end

    local child_path = abs_path:sub(#root_dir + 1)
    local entry = status_tree:get_child_by_path(child_path)
    if entry then
        entry.is_dirty = false
    end
end

return M
