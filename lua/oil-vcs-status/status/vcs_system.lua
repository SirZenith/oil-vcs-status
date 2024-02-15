local log = require "oil-vcs-status.log"
local StatusTree = require "oil-vcs-status.status.status_tree"

---@alias oil-vcs-status.status.IgnoreFsEventMap table<string, true | { change?: true, rename?: true }>

---@class oil-vcs-status.status.VcsSystem
---@field name string
---@field root_dir string
---@field is_dirty boolean
---@field is_deleted boolean
---@field is_updating boolean
---@field status_tree oil-vcs-status.status.StatusTree
--
---@field fs_event_handle? table
---@field ignore_fs_event? oil-vcs-status.status.IgnoreFsEventMap
--
---@field status_cmd_runner? fun(root_dir: string, callback: fun(result: oil-vcs-status.util.CmdResult))
---@field status_updater? fun(status_tree: oil-vcs-status.status.StatusTree, stdout: string)
---@field fs_event_callback? fun(err?: string, system: oil-vcs-status.status.VcsSystem)
local VcsSystem = {}
VcsSystem.__index = VcsSystem

function VcsSystem:new(name, root_dir)
    log.trace("new", name, "repo at", root_dir)

    local obj = setmetatable({}, self)

    obj.name = name
    obj.root_dir = root_dir
    obj.is_dirty = true
    obj.is_deleted = false
    obj.is_updating = false
    obj.status_tree = StatusTree:new(("<%s root>"):format(name))

    return obj
end

function VcsSystem:init_fs_event_listener()
    self:cancel_fs_event_listener()

    local handle, err = vim.loop.new_fs_event()
    if not handle then
        log.warn("failed to create fs event handle", err)
        return
    end

    local flags = {
        recursive = true,
    }
    local callback = vim.schedule_wrap(function(callback_err, filename, events)
        self:on_fs_event(callback_err, filename, events)
    end)
    local _, event_err = handle:start(self.root_dir, flags, callback)
    if event_err then
        log.warn("failed to watch vcs directory", event_err)
        return
    end

    self.fs_event_handle = handle
end

function VcsSystem:cancel_fs_event_listener()
    if self.fs_event_handle then
        self.fs_event_handle:stop()
        self.fs_event_handle = nil
    end
end

---@param filename string
---@param events { change: boolean | nil, rename: boolean | nil }
---@return boolean
function VcsSystem:check_should_ignore_fs_event(filename, events)
    local ignore_map = self.ignore_fs_event
    if not ignore_map then return false end

    filename = vim.fs.normalize(filename)
    local ignore_data = ignore_map[filename]
    if not ignore_data then return false end

    local is_ignore = true

    if type(ignore_data) == "table" then
        for key in pairs(events) do
            if not ignore_data[key] then
                is_ignore = false
                break
            end
        end
    end

    return is_ignore
end

---@param err string?
---@param filename string
---@param events { change: boolean | nil, rename: boolean | nil }
function VcsSystem:on_fs_event(err, filename, events)
    if vim.fn.isdirectory(self.root_dir) ~= 1 then
        self:cancel_fs_event_listener()
        self.is_deleted = true
        return
    end

    if self.is_updating then
        return
    end

    self.is_dirty = true

    local is_ignore = self:check_should_ignore_fs_event(filename, events)
    if is_ignore then
        return
    end

    local callback = self.fs_event_callback;
    if callback then
        callback(err, self)
    end
end

---@param callback fun(err?: string)
function VcsSystem:update_status(callback)
    if not self.is_dirty then
        callback()
        return
    end

    if self.is_updating then
        callback()
        return
    end

    local cmd_runner = self.status_cmd_runner
    if not cmd_runner then
        callback("no status command binded with system: " .. self.name)
        return
    end

    local status_updater = self.status_updater
    if not status_updater then
        callback("no status parser provided for system: " .. self.name)
        return
    end

    self.is_updating = true
    cmd_runner(self.root_dir, function(result)
        self.is_updating = false

        if result.code ~= 0 then
            local err = result.stderr
            callback(err ~= "" and err or "failed to get git status")
            return
        end

        self.is_dirty = false

        status_updater(self.status_tree, result.stdout)
        callback()
    end)
end

---@param path string # normalized absolute path of entry
---@return oil-vcs-status.status.EntryStatus?
function VcsSystem:get_entry_status(path)
    local root_len = #self.root_dir
    if #path < root_len then
        return nil
    end

    local child_path = path:sub(root_len + 1)
    local entry = self.status_tree:get_child_by_path(child_path)
    if not entry then return nil end

    return {
        local_status = entry.local_status,
        remote_status = entry.remote_status,
    }
end

---@param path string
---@return boolean
function VcsSystem:check_entry_dirty(path)
    local root_len = #self.root_dir
    if #path < root_len then
        return false
    end

    local child_path = path:sub(root_len + 1)
    local entry = self.status_tree:get_child_by_path(child_path)
    if not entry then return false end

    return entry.is_dirty
end

---@param path string
function VcsSystem:clear_entry_dirty(path)
    local root_len = #self.root_dir
    if #path < root_len then
        return false
    end

    local child_path = path:sub(root_len + 1)
    local entry = self.status_tree:get_child_by_path(child_path)
    if entry then
        entry.is_dirty = false
    end
end

-- Check if given path is a sub directory of repo root
---@param dir string # normalized absolute path
---@return boolean
function VcsSystem:check_is_sub_dir(dir)
    local root_dir = self.root_dir
    return dir:sub(1, #root_dir) == root_dir
end

return VcsSystem
