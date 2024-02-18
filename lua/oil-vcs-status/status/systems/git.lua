local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"
local status_const = require "oil-vcs-status.constant.status"
local VcsSystem = require "oil-vcs-status.status.systems.vcs_system"
local util = require "oil-vcs-status.util"
local path_util = require "oil-vcs-status.util.path"
local table_util = require "oil-vcs-status.util.table"

local loop = vim.loop
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
    ["m"] = StatusType.External,
}

---@type table<string, oil-vcs-status.StatusType>
local UPSTREAM_STATUS_MAP = {
    [" "] = StatusType.UpstreamUnmodified,
    ["!"] = StatusType.UpstreamIgnored,
    ["?"] = StatusType.UpstreamUntracked,
    ["M"] = StatusType.UpstreamModified,
    ["T"] = StatusType.UpstreamTypeChanged,
    ["A"] = StatusType.UpstreamAdded,
    ["D"] = StatusType.UpstreamDeleted,
    ["R"] = StatusType.UpstreamRenamed,
    ["C"] = StatusType.UpstreamCopied,
    ["U"] = StatusType.UpstreamUnmerged,
    ["m"] = StatusType.UpstreamExternal,
}

local super = VcsSystem
---@class oil-vcs-status.status.system.Git : oil-vcs-status.status.system.VcsSystem
---@field last_status_update_time integer
---@field index_lock_record table<string, boolean>
local Git = util.inherit(super)
Git.name = "git"

---@param root_dir string
function Git:new(root_dir)
    local obj = super.new(self, root_dir) --[[@as oil-vcs-status.status.system.Git]]

    obj.last_status_update_time = 0
    obj.index_lock_record = {}

    return obj
end

function Git:fs_watch_path_list_getter()
    local root_dir = self.root_dir

    local paths = { root_dir }
    local target = root_dir .. "/.git"
    if vim.fn.filereadable(target) ~= 1 then
        return paths
    end

    local file, open_err = io.open(target, "r")
    if not file or open_err then
        return paths
    end

    local prefix = "gitdir: "
    local prefix_len = #prefix
    local real_index_dir_path
    for line in file:lines() do
        if line:sub(1, prefix_len) == prefix then
            real_index_dir_path = line:sub(prefix_len + 1)
            break
        end
    end

    if real_index_dir_path then
        real_index_dir_path = root_dir .. "/" .. real_index_dir_path
        real_index_dir_path = vim.fn.fnamemodify(real_index_dir_path, ":p")
        real_index_dir_path = vim.fs.normalize(real_index_dir_path)
        paths[#paths + 1] = real_index_dir_path
    end

    return paths
end

---@param filename string
---@param _ { change: boolean | nil, rename: boolean | nil }
---@return boolean
---@return string? reason
function Git:fs_event_ignore_checker(filename, _)
    local now = loop.now()
    local update_debounce = config.vcs_specific.git.status_update_debounce
    if now - self.last_status_update_time < update_debounce then
        return true, "update cool down"
    end

    if filename:find("%.git/.*index.lock") then
        return true, "is lock file"
    end

    if vim.fs.basename(filename) == ".git"
        or filename:find("%.git/modules/.+")
    then
        local record = self.index_lock_record

        local was_locked = record[filename]
        local lock_file = filename .. "/index.lock"
        local is_locked = vim.fn.filereadable(lock_file) == 1
        record[filename] = is_locked

        if is_locked then
            return true, "index locked"
        end

        if was_locked then
            return true, "index lock clean up"
        end
    else
        local lock_file = self.root_dir .. "/.git/index.lock"
        local is_locked = vim.fn.filereadable(lock_file) == 1
        if is_locked then
            return true, "repo index locked"
        end
    end

    return false
end

---@param stdout string
function Git:status_updater(stdout)
    local status_tree = self.status_tree

    status_tree:reset()

    self.last_status_update_time = loop.now()

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

        local remote_status = UPSTREAM_STATUS_MAP[remote_status_str]
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

---@param callback fun(result: oil-vcs-status.util.CmdResult)
function Git:status_cmd_runner(callback)
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
        cwd = self.root_dir,
    }

    util.run_cmd(cmd, opt, callback)
end

-- Find git repo root of given directory.
---@param dir string
---@return string? root_dir # normalized absolute path of repo root.
local function find_repo_root(dir)
    local root_dir = path_util.find_root_by_entry(dir, { ".git" })
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
        system = Git:new(root_dir)
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
