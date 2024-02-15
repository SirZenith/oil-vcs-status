local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"
local status_const = require "oil-vcs-status.constant.status"
local VcsSystem = require "oil-vcs-status.status.vcs_system"
local util = require "oil-vcs-status.util"
local path_util = require "oil-vcs-status.util.path"
local table_util = require "oil-vcs-status.util.table"

local StatusType = status_const.StatusType

local M = {}

---@type table<string, oil-vcs-status.StatusType>
local STATUS_MAP = {
    [" "] = StatusType.Unmodified,
    ["A"] = StatusType.Added,
    ["C"] = StatusType.Unmerged,
    ["D"] = StatusType.Deleted,
    ["I"] = StatusType.Ignored,
    ["M"] = StatusType.Modified,
    ["R"] = StatusType.Renamed,
    ["X"] = StatusType.External,
    ["?"] = StatusType.Untracked,
    ["!"] = StatusType.Deleted,
    ["~"] = StatusType.TypeChanged,
}

IGNORE_FS_EVENT = {
    -- [".svn/index.lock"] = true,
}

-- Map repo root path to VcsSystem object.
---@type table<string, oil-vcs-status.status.VcsSystem>
local active_systems = {}

---@param system oil-vcs-status.status.VcsSystem
---@param filename string
---@param events { change: boolean | nil, rename: boolean | nil }
---@return boolean
local function fs_event_ignore_checker(system, filename, events)
    if util.check_should_ignore_fs_event_by_ignore_map(IGNORE_FS_EVENT, filename, events) then
        return true
    end

    --[[ if vim.fn.filereadable(system.root_dir .. "/.svn/index.lock") == 1 then
        return true
    end ]]

    return false
end

---@param status_tree oil-vcs-status.status.StatusTree
---@param stdout string
local function load_status_data(status_tree, stdout)
    status_tree:reset()

    local lines = vim.split(stdout, "\r?\n")
    table_util.filter_in_place(lines, function(_, value)
        return value ~= ""
    end)

    for _, line in ipairs(lines) do
        local local_status_str = line:sub(1, 1)

        local path = line:sub(9)

        local local_status = STATUS_MAP[local_status_str]
        if not local_status then
            log.warn(("unknown git status indicator: %q"):format(local_status_str))
        end

        if local_status then
            status_tree:update_child(path, local_status, StatusType.Unmodified)
        end
    end
end

---@param root_dir string
---@param callback fun(result: oil-vcs-status.util.CmdResult)
local function status_cmd(root_dir, callback)
    local cmd = config.vcs_executable.svn
    if vim.fn.executable(cmd) ~= 1 then
        callback {
            code = 1,
            signal = 0,
            stdout = "",
            stderr = "svn executable not found",
        }
        return
    end

    local opt = {
        args = { "status" },
        cwd = root_dir,
    }

    util.run_cmd(cmd, opt, callback)
end

-- Find git repo root of given directory.
---@param dir string
---@return string? root_dir # normalized absolute path of repo root.
local function find_repo_root(dir)
    local root_dir = path_util.find_root_by_entry(dir, { ".svn" })
    return root_dir
end

---@param dir string
---@return oil-vcs-status.status.VcsSystem?
function M.get_active_system(dir)
    local root_dir = find_repo_root(dir)
    if not root_dir then return nil end

    local system = active_systems[root_dir]
    if not system then
        system = VcsSystem:new("svn", root_dir)
        active_systems[root_dir] = system

        system.status_cmd_runner = status_cmd
        system.status_updater = load_status_data

        system.fs_event_ignore_checker = fs_event_ignore_checker
        system:init_fs_event_listener()
    end

    if system.is_deleted then
        active_systems[root_dir] = nil
        return nil
    end

    return system
end

return M
