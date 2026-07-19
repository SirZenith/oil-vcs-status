local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"
local StatusTree = require "oil-vcs-status.status.systems.status_tree"

local uv = vim.uv or vim.loop

---@class oil-vcs-status.status.system.VcsSystem
---@field name string
---@field root_dir string
---@field is_dirty boolean
---@field is_deleted boolean
---@field is_updating boolean
---@field status_tree oil-vcs-status.status.StatusTree
--
---@field fs_event_handles? any[]
---@field fs_timer_pool uv.uv_timer_t[]
---@field fs_debounce_timer_tbl table<string, uv.uv_timer_t>
--
---@field fs_event_callback? fun(err?: string, system: oil-vcs-status.status.system.VcsSystem)
local VcsSystem = {}
VcsSystem.name = "vcs system"

---@param root_dir string
function VcsSystem:new(root_dir)
    self.__index = self
    local name = self.name

    log.trace("new", name, "repo at", root_dir)

    local obj = setmetatable({}, self)

    obj.name = name
    obj.root_dir = root_dir
    obj.is_dirty = true
    obj.is_deleted = false
    obj.is_updating = false
    obj.status_tree = StatusTree:new(("<%s root>"):format(name))

    obj.fs_timer_pool = {}
    obj.fs_debounce_timer_tbl = {}

    return obj
end

---@param path string
---@return uv.uv_timer_t?
---@return string? err
function VcsSystem:get_fs_debounce_timer(path)
    local timer = self.fs_debounce_timer_tbl[path] --[[@as uv.uv_timer_t?]]
    if timer then
        return timer
    end

    local err
    local pool = self.fs_timer_pool
    if #pool > 0 then
        timer = table.remove(pool)
    else
        timer, err = uv.new_timer()
    end

    if timer then
        self.fs_debounce_timer_tbl[path] = timer
    end

    return timer, err
end

---@param path string
function VcsSystem:put_fs_debounce_timer(path)
    local timer = self.fs_debounce_timer_tbl[path]
    if not timer then return end

    self.fs_debounce_timer_tbl[path] = nil

    timer:stop()
    table.insert(self.fs_timer_pool, timer)
end

function VcsSystem:init_fs_event_listener()
    self:cancel_fs_event_listener()

    local paths = self:fs_watch_path_list_getter()
    if #paths == 0 then return end

    local handles = {}
    local flags = {
        recursive = true,
    }

    for _, path in ipairs(paths) do
        local handle, handle_err = uv.new_fs_event()
        if not handle then
            log.warn("failed to create fs event handle", handle_err)
            goto continue
        end

        local callback = vim.schedule_wrap(function(callback_err, filename, events)
            if filename then
                filename = path .. "/" .. filename
                filename = vim.fn.fnamemodify(filename, ":p")
                filename = vim.fs.normalize(filename)
            else
                filename = filename or self.root_dir
            end


            local timer, timer_err = self:get_fs_debounce_timer(filename)
            if not timer or timer_err then
                log.warn("FS event debounce timer error:", timer_err or "unknown error")
                self:on_fs_event(callback_err, filename, events)
                return
            end

            timer:start(config.fs_event_debounce, 0, vim.schedule_wrap(function()
                self:put_fs_debounce_timer(filename)
                self:on_fs_event(callback_err, filename, events)
            end))
        end)

        local _, event_err = handle:start(path, flags, callback)
        if event_err then
            log.warn("failed to watch vcs directory", event_err)
            goto continue
        end

        log.trace(self.name, "watching path:", path)
        handles[#handles + 1] = handle
        ::continue::
    end

    self.fs_event_handles = handles
end

function VcsSystem:cancel_fs_event_listener()
    local handles = self.fs_event_handles
    if not handles then return end

    for _, handle in ipairs(handles) do
        handle:stop()
    end

    self.fs_event_handles = nil
end

---@return string[]
function VcsSystem:fs_watch_path_list_getter()
    return { self.root_dir }
end

---@param filename string
---@param events { change: boolean | nil, rename: boolean | nil }
---@return boolean is_ignore
---@return string? reason
---@diagnostic disable-next-line: unused-local
function VcsSystem:fs_event_ignore_checker(filename, events)
    return false
end

---@param err string?
---@param filename string
---@param events ({ change: boolean | nil, rename: boolean | nil })?
function VcsSystem:on_fs_event(err, filename, events)
    local callback = self.fs_event_callback

    if err or not events then
        if callback then
            callback(err or "fs event error", self)
        end
        return
    end

    if vim.fn.isdirectory(self.root_dir) ~= 1 then
        self:cancel_fs_event_listener()
        self.is_deleted = true
        return
    end

    -- Status value update also trigger file system event. Ignore new event when
    -- there is an ongoing update.
    if self.is_updating then
        log.trace("status being updated, event skipped:", filename)
        return
    end

    local is_ignore, reason = self:fs_event_ignore_checker(filename, events)
    if is_ignore then
        log.trace("event ignored:", filename, "-", reason)
        return
    end

    log.trace(
        self.name, "fs event",
        "\npath:", filename,
        "\nchange:", events.change or "false",
        "\nrename:", events.rename or "false"
    )

    self.is_dirty = true

    if callback then
        vim.schedule(function() callback(err, self) end)
    end
end

function VcsSystem:mark_status_dirty()
    self.is_dirty = true
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

    log.trace(self.name, "run status cmd")
    self.is_updating = true
    self:status_cmd_runner(function(result)
        self.is_updating = false

        if result.code ~= 0 then
            local err = result.stderr
            callback(err ~= "" and err or "failed to get git status")
            return
        end

        self.is_dirty = false

        log.trace(self.name, "new status data:", self.root_dir)
        self:status_updater(result.stdout)
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

---@param callback fun(result: oil-vcs-status.util.CmdResult)
function VcsSystem:status_cmd_runner(callback)
    callback {
        code = 1,
        signal = 0,
        stdout = "",
        stderr = self.name .. ": empty status cmd implementation"
    }
end

---@param stdout string
---@diagnostic disable-next-line: unused-local
function VcsSystem:status_updater(stdout)
    log.warn(self.name .. ": empty status parser implementation")
end

return VcsSystem
