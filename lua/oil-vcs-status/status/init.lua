local oil = require "oil"

local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"
local status_git = require "oil-vcs-status.status.git"

local api = vim.api

---@class oil-vcs-status.status.EntryStatus
---@field local_status oil-vcs-status.StatusType
---@field remote_status oil-vcs-status.StatusType

local M = {}

local NAMESPACE = vim.api.nvim_create_namespace("oil-vcs-status.status")

local vcs_list = {
    status_git
}

-- Map buffer number to directory path
---@type table<integer, string>
local bufnr_to_dir_map = {}

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

---@param dir string
---@return boolean
local function check_dir_status_dirty(dir)
    local is_dirty = false
    for _, vcs in ipairs(vcs_list) do
        local system = vcs.get_active_system(dir)
        is_dirty = system and system:check_entry_dirty(dir) or false
        if is_dirty then
            break
        end
    end

    return is_dirty
end

---@param bufnr integer
---@param line integer
---@param status oil-vcs-status.StatusType
local function add_symbol_to_buffer(bufnr, line, status)
    local text = config.status_symbol[status] or " "
    local hl = config.status_hl_group[status] or nil

    api.nvim_buf_set_extmark(bufnr, NAMESPACE, line - 1, 0, {
        sign_text = text,
        sign_hl_group = hl,
    })
end

-- Update status symbol for given entry line.
---@param bufnr integer
---@param line integer
---@param system oil-vcs-status.status.VcsSystem
local function update_entry_status(bufnr, line, system)
    local entry = oil.get_entry_on_line(bufnr, line)
    if not entry then return end

    if not entry.id then return end

    local dir = bufnr_to_dir_map[bufnr]
    if not dir then return end

    local name = entry.name
    local path = dir .. "/" .. name

    local status = system:get_entry_status(path)
    if not status then return end

    add_symbol_to_buffer(bufnr, line, status)
end

---@param bufnr integer
---@param dir string
---@param systems oil-vcs-status.status.VcsSystem[]
local function after_all_buffer_status_update(bufnr, dir, systems)
    bufnr_to_dir_map[bufnr] = dir
    api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)

    for _, system in ipairs(systems) do
        system:clear_entry_dirty(dir)

        local line_cnt = api.nvim_buf_line_count(bufnr)
        for i = 1, line_cnt do
            update_entry_status(bufnr, i, system)
        end
    end
end

-- Update status symbol for given oil buffer.
---@param bufnr integer
function M.update_status(bufnr)
    local dir = get_oil_buffer_dir(bufnr)
    if not dir then return end

    local old_dir = bufnr_to_dir_map[bufnr]
    if old_dir == dir and not check_dir_status_dirty(dir) then
        return
    end

    local systems = {} ---@type oil-vcs-status.status.VcsSystem[]
    for _, vcs in ipairs(vcs_list) do
        systems[#systems + 1] = vcs.get_active_system(dir)
    end


    local total_cnt = #systems
    local cnt = 0
    for _, system in ipairs(systems) do
        system.fs_event_callback = M.on_fs_event

        system:update_status(function(err)
            if err then
                log.warn(err)
            end

            cnt = cnt + 1
            if cnt < total_cnt then
                return
            end

            log.trace("update status:", dir)
            after_all_buffer_status_update(bufnr, dir, systems)
        end)
    end
end

---@param err? string
---@param system oil-vcs-status.status.VcsSystem
function M.on_fs_event(err, system)
    if err then
        log.warn(err)
        return
    end

    local targets = {}

    local wins = api.nvim_tabpage_list_wins(0)
    local visible_buf_set = {}
    for _, win in ipairs(wins) do
        local bufnr = api.nvim_win_get_buf(win)
        visible_buf_set[bufnr] = true
    end

    for bufnr, dir in pairs(bufnr_to_dir_map) do
        if not system:get_entry_status(dir) then
            -- pass
        elseif visible_buf_set[bufnr] then
            -- Visible buffers should be updated right away.
            targets[#targets + 1] = bufnr
        else
            -- Invisible buffers should be updated next time user enters it.
            bufnr_to_dir_map[bufnr] = nil
            api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)
        end
    end

    if #targets <= 0 then return end

    system:update_status(function(update_err)
        if update_err then
            log.warn(update_err)
            return
        end

        for _, target in ipairs(targets) do
            log.trace("fs event update", bufnr_to_dir_map[target] or "nil")
            api.nvim_buf_clear_namespace(target, NAMESPACE, 0, -1)

            local line_cnt = api.nvim_buf_line_count(target)
            for i = 1, line_cnt do
                update_entry_status(target, i, system)
            end
        end
    end)
end

return M
