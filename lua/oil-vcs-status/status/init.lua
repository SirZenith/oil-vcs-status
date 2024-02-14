local oil = require "oil"

local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"

local api = vim.api

---@class oil-vcs-status.status.EntryStatus
---@field local_status oil-vcs-status.StatusType
---@field remote_status oil-vcs-status.StatusType

local M = {}

local NAMESPACE = vim.api.nvim_create_namespace("oil-vcs-status.status")

local systems = {
    git = require "oil-vcs-status.status.git",
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

    return fs.posix_to_os_path(path)
end

---@param dir string
---@return boolean
local function check_dir_status_dirty(dir)
    local abs_path = vim.fn.fnamemodify(dir, ":p")
    abs_path = vim.fs.normalize(dir)

    local is_dirty = false
    for _, system in ipairs(systems) do
        is_dirty = system.check_entry_dirty(abs_path)
        if is_dirty then
            break
        end
    end

    return is_dirty
end

---@param dir string
local function clear_dir_dirty(dir)
    local abs_path = vim.fn.fnamemodify(dir, ":p")
    abs_path = vim.fs.normalize(dir)

    for _, system in ipairs(systems) do
        system.clear_entry_dirty(abs_path)
    end
end

---@param bufnr integer
---@param line integer
---@param ... oil-vcs-status.StatusType
local function add_symbol_to_buffer(bufnr, line, ...)
    for i, status in ipairs { ... } do
        local text = config.status_symbol[status] or " "
        local hl = config.status_hl_group[status] or nil

        api.nvim_buf_set_extmark(bufnr, NAMESPACE, line - 1, 0, {
            sign_text = text,
            sign_hl_group = hl,
            priority = i,
        })
    end
end

-- Update status symbol for given entry line.
---@param bufnr integer
---@param line integer
local function update_entry_status(bufnr, line)
    local entry = oil.get_entry_on_line(bufnr, line)
    if not entry then return end

    if not entry.id then return end

    local dir = bufnr_to_dir_map[bufnr]
    local name = entry.name
    local path = dir .. "/" .. name
    path = vim.fn.fnamemodify(path, ":p")
    path = vim.fs.normalize(path)

    local status
    for _, system in pairs(systems) do
        if system.is_active() then
            status = system.get_entry_status(path)
            break
        end
    end

    if not status then return end

    add_symbol_to_buffer(bufnr, line, status.remote_status, status.local_status)
end

-- Update status symbol for given oil buffer.
---@param bufnr integer
function M.update_status(bufnr)
    local dir = get_oil_buffer_dir(bufnr)
    if not dir then return end

    local old_dir = bufnr_to_dir_map[bufnr]
    if old_dir == dir and not check_dir_status_dirty(dir) then
        log.trace("directory not dirty:", dir)
        return
    end

    log.trace("update status:", dir)

    bufnr_to_dir_map[bufnr] = dir
    clear_dir_dirty(dir)

    local line_cnt = api.nvim_buf_line_count(bufnr)
    for i = 1, line_cnt do
        update_entry_status(bufnr, i)
    end
end

---@param err? string
function M.on_status_updated(err)
    if err then
        log.warn(err)
    else
        M.update_status(0)
    end
end

-- Update version control system metadata after working directory changed.
function M.on_dir_changed()
    for _, system in pairs(systems) do
        system.update_root_dir()

        if system.is_active() then
            system.update_status(M.on_status_updated)
        end
    end
end

return M
