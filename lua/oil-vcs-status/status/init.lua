local oil = require "oil"

local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"
local status_git = require "oil-vcs-status.status.systems.git"
local status_svn = require "oil-vcs-status.status.systems.svn"

local api = vim.api

---@class oil-vcs-status.status.EntryStatus
---@field local_status oil-vcs-status.StatusType
---@field remote_status oil-vcs-status.StatusType

---@class oil-vcs-status.status.BufUpdateInfo
---@field dir string
---@field wait_set table<oil-vcs-status.status.system.VcsSystem, true>

local M = {}

local NAMESPACE = vim.api.nvim_create_namespace("oil-vcs-status.status")

local VCS_LIST = {
    status_git,
    status_svn,
}

-- Map buffer number to directory path
---@type table<integer, oil-vcs-status.status.BufUpdateInfo>
local buf_update_info = {}

-- Get directory path of given oil buffer.
---@param bufnr integer
---@return string? path
local function get_oil_buffer_dir(bufnr)
    local oil_config = require("oil.config")
    local fs = require("oil.fs")
    local util = require("oil.util")

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local scheme, path = util.parse_url(bufname)

    if not path
        or oil_config.adapters[scheme] ~= "files"
    then
        return nil
    end

    if path == "/" and vim.fn.has("win32") then
        return nil
    end

    path = fs.posix_to_os_path(path)
    path = vim.fn.fnamemodify(path, ":p")
    path = vim.fs.normalize(path)

    return path
end

-- Write status symbols to given row.
---@param bufnr integer
---@param line integer
---@param status oil-vcs-status.StatusType
local function add_symbol_to_buffer(bufnr, line, status)
    api.nvim_buf_set_extmark(bufnr, NAMESPACE, line - 1, 0, {
        sign_text = config.status_symbol[status] or " ",
        sign_hl_group = config.status_hl_group[status] or nil,
        priority = config.status_priority[status] or 0,
    })
end

-- Update status symbol for given entry line.
---@param bufnr integer
---@param line integer
---@param system oil-vcs-status.status.system.VcsSystem
local function update_entry_status(bufnr, line, system)
    local entry = oil.get_entry_on_line(bufnr, line)
    if not entry then return end

    if not entry.id then return end

    local info = buf_update_info[bufnr]
    if not info then return end

    local name = entry.name
    local path = info.dir .. "/" .. name

    local status = system:get_entry_status(path)
    if not status then return end

    add_symbol_to_buffer(bufnr, line, status.remote_status)
    add_symbol_to_buffer(bufnr, line, status.local_status)
end

-- Update status sign in buffer with all active VCS system.
---@param bufnr integer
local function update_buffer_status_with_all_system(bufnr)
    if not api.nvim_buf_is_valid(bufnr)
        or not api.nvim_buf_is_loaded(bufnr)
    then
        buf_update_info[bufnr] = nil
        return
    end

    local info = buf_update_info[bufnr]
    if not info then return end

    api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)

    local dir = info.dir
    for _, vcs in ipairs(VCS_LIST) do
        local system = vcs.get_active_system(dir)
        if system then
            log.trace(system.name, "updating status in:", bufnr)
            system:clear_entry_dirty(dir)

            local line_cnt = api.nvim_buf_line_count(bufnr)
            for i = 1, line_cnt do
                update_entry_status(bufnr, i, system)
            end
        end
    end
end

-- Try update all pending buffer after status value updated.
---@param system oil-vcs-status.status.system.VcsSystem
local function on_status_updated(system)
    for bufnr, info in pairs(buf_update_info) do
        local wait_set = info.wait_set
        wait_set[system] = nil

        local wait_cnt = 0
        for _ in pairs(wait_set) do
            wait_cnt = wait_cnt + 1
        end

        if wait_cnt == 0 then
            update_buffer_status_with_all_system(bufnr)
        end
    end
end

-- File system event callback.
---@param err? string
---@param system oil-vcs-status.status.system.VcsSystem
local function on_fs_event(err, system)
    if err then
        log.trace("error occured in fs watcher:", system.root_dir)
        log.warn(err)
        return
    end

    -- Find visible buffers
    local wins = api.nvim_tabpage_list_wins(0)
    local visible_buf_set = {}
    for _, win in ipairs(wins) do
        if api.nvim_win_is_valid(win) then
            local bufnr = api.nvim_win_get_buf(win)
            visible_buf_set[bufnr] = true
        end
    end

    -- Check if a immediate update is needed
    local need_update = false
    for bufnr, info in pairs(buf_update_info) do
        if not system:check_is_sub_dir(info.dir) then
            -- pass
        elseif visible_buf_set[bufnr] then
            -- Visible buffers should be updated right away.
            info.wait_set[system] = true
            need_update = true
        else
            -- Invisible buffers should be updated next time user enters it.
            info.dir = ""
        end
    end

    if need_update then
        log.trace(system.name, "update buffer by fs event:", system.root_dir)
        system:update_status(function(update_err)
            if update_err then
                log.warn(update_err)
            end
            on_status_updated(system)
        end)
    end
end

-- Request status update for given buffer.
---@param bufnr integer
function M.update_status(bufnr)
    if bufnr == 0 then
        bufnr = api.nvim_win_get_buf(0)
    end

    local dir = get_oil_buffer_dir(bufnr)
    if not dir then return end

    local info = buf_update_info[bufnr]
    if not info then
        info = {
            dir = "",
            wait_set = {},
        }
        buf_update_info[bufnr] = info
    end

    info.dir = dir

    for _, vcs in ipairs(VCS_LIST) do
        local system = vcs.get_active_system(dir)
        if system then
            system.fs_event_callback = on_fs_event

            if not info.wait_set[system] then
                info.wait_set[system] = true

                log.trace(system.name, "update request:", dir)
                system:update_status(function(err)
                    if err then
                        log.warn(err)
                    end
                    on_status_updated(system)
                end)
            end
        end
    end
end

---@param file string
function M.on_file_buf_write(file)
    local dir = vim.fs.dirname(file)

    for _, vcs in ipairs(VCS_LIST) do
        local system = vcs.get_active_system(dir)
        if system then
            log.trace("bufwrite effect:", system.name)
            system:mark_status_dirty()
        end
    end
end

return M
