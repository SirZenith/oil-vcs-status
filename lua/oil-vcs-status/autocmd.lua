local status = require "oil-vcs-status.status"

local api = vim.api
local loop = vim.loop

local M = {}

local AUGROUP_NAME = "oil-vcs-status"
local BUF_MODIFY_DEBOUNCE = 200

---@param bufnr integer
---@param augroup any
local function setup_buf_change_watcher(bufnr, augroup)
    local last_trigger = 0

    api.nvim_create_autocmd("BufModifiedSet", {
        group = augroup,
        buffer = bufnr,
        callback = function()
            local now = loop.now()
            local delta_time = now - last_trigger
            if delta_time < BUF_MODIFY_DEBOUNCE then
                return
            end

            last_trigger = now
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

    api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function(args)
            local bufnr = args.buf
            status.update_status(bufnr)
        end,
    })
end

return M
