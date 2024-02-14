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
    ["!"] = StatusType.Ignored,
    ["?"] = StatusType.Untracked,
    ["M"] = StatusType.Modified,
    ["T"] = StatusType.TypeChanged,
    ["A"] = StatusType.Added,
    ["D"] = StatusType.Deleted,
    ["R"] = StatusType.Renamed,
    ["C"] = StatusType.Copied,
    ["U"] = StatusType.Unmerged,

    ["m"] = StatusType.Modified,
}

local IGNORE_FS_EVENT = {
    [".git/index.lock"] = true,
}

-- Map repo root path to VcsSystem object.
---@type table<string, oil-vcs-status.status.VcsSystem>
local active_systems = {}

---@param status_tree oil-vcs-status.status.StatusTree
---@param stdout string
local function load_status_data(status_tree, stdout)
    status_tree:reset()

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

---@param root_dir string
---@param callback fun(result: oil-vcs-status.util.CmdResult)
local function status_cmd(root_dir, callback)
    local cmd = config.vcs_executable.git
    if vim.fn.executable(cmd) ~= 1 then
        callback {
            code = 1,
            signal = 0,
            stdout = "",
            stderr = "git executable not found",
        }
        return
    end

    local opt = {
        args = { "status", "--short", "--ignored" },
        cwd = root_dir,
    }

    util.run_cmd("git", opt, callback)
end

-- Find git repo root of given directory.
---@param dir string
---@return string? root_dir # normalized absolute path of repo root.
local function find_repo_root(dir)
    local root_dir = path_util.find_root_by_entry(dir, { ".git" })
    return root_dir
end

---@param dir string
---@return oil-vcs-status.status.VcsSystem?
function M.get_active_system(dir)
    local root_dir = find_repo_root(dir)
    if not root_dir then return nil end

    local system = active_systems[root_dir]
    if not system then
        system = VcsSystem:new("git", root_dir)
        active_systems[root_dir] = system

        system.status_cmd_runner = status_cmd
        system.status_updater = load_status_data

        system.ignore_fs_event = IGNORE_FS_EVENT
        system:init_fs_event_listener()
    end

    if system.is_deleted then
        active_systems[root_dir] = nil
        return nil
    end

    return system
end

return M
