local log = require "oil-vcs-status.log"
local status = require "oil-vcs-status.status"

local api = vim.api

local M = {}

local AUGROUP_NAME = "oil-vcs-status"

---@param bufnr integer
---@param augroup any
local function setup_buf_change_watcher(bufnr, augroup)
    api.nvim_create_autocmd("BufModifiedSet", {
        group = augroup,
        buffer = bufnr,
        callback = function()
            status.update_status(bufnr)
        end,
    })
end

function M.setup_autocmd()
    local augroup = api.nvim_create_augroup(AUGROUP_NAME, { clear = true })

    api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "oil",
        callback = function(args)
            local bufnr = args.buf
            setup_buf_change_watcher(bufnr, augroup)
        end,
    })

    api.nvim_create_autocmd("DirChanged", {
        group = augroup,
        callback = status.on_dir_changed,
    })
end

return M
