local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"
local status_const = require "oil-vcs-status.constant.status"
local VcsSystem = require "oil-vcs-status.status.systems.vcs_system"
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

local UPSTREAM_STATUS_MAP = {
    [" "] = StatusType.UpstreamUnmodified,
    ["C"] = StatusType.UpstreamUnmerged,
}

IGNORE_FS_EVENT = {}

local super = VcsSystem

---@class oil-vcs-status.status.system.Svn : oil-vcs-status.status.system.VcsSystem
local Svn = util.inherit(super)
Svn.name = "svn"

---@param filename string
---@param events { change: boolean | nil, rename: boolean | nil }
---@return boolean
function Svn:fs_event_ignore_checker(filename, events)
    if util.check_should_ignore_fs_event_by_ignore_map(IGNORE_FS_EVENT, filename, events) then
        return true
    end

    return false
end

---@param stdout string
function Svn:status_updater(stdout)
    local status_tree = self.status_tree

    status_tree:reset()

    local lines = vim.split(stdout, "\r?\n")
    table_util.filter_in_place(lines, function(_, value)
        if value == "" then
            return false
        end

        -- ignore conflict detail information
        if value:sub(1, 7) == "      >" then
            return false
        end

        return true
    end)

    for _, line in ipairs(lines) do
        if line == "Summary of conflicts:" then
            break
        end

        local local_status_str = line:sub(1, 1)
        local remote_status_str = line:sub(7, 7)

        local path = line:sub(9)

        local local_status = STATUS_MAP[local_status_str]
        if not local_status then
            log.warn(("unknown svn status indicator: %q"):format(local_status_str))
        end

        local remote_status = UPSTREAM_STATUS_MAP[remote_status_str]
        if not local_status then
            log.warn(("unknown svn status indicator: %q"):format(remote_status_str))
        end

        if local_status and remote_status then
            status_tree:update_child(path, local_status, remote_status)
        end
    end
end

---@param callback fun(result: oil-vcs-status.util.CmdResult)
function Svn:status_cmd_runner(callback)
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
        cwd = self.root_dir,
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

-- Map repo root path to VcsSystem object.
---@type table<string, oil-vcs-status.status.system.VcsSystem>
local active_systems = {}

---@param dir string
---@return oil-vcs-status.status.system.VcsSystem?
function M.get_active_system(dir)
    local root_dir = find_repo_root(dir)
    if not root_dir then return nil end

    local system = active_systems[root_dir]
    if not system then
        system = Svn:new(root_dir)
        active_systems[root_dir] = system
        system:init_fs_event_listener()
    end

    if system.is_deleted then
        active_systems[root_dir] = nil
        return nil
    end

    return system
end

return M
