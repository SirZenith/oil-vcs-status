local status = require "oil-vcs-status.status"

local api = vim.api
local loop = vim.loop

local M = {}

local AUGROUP_NAME = "oil-vcs-status"
local BUF_MODIFY_DEBOUNCE = 100

local watched_buf = {}

---@param bufnr integer
---@param augroup any
local function setup_buf_change_watcher(bufnr, augroup)
    if watched_buf[bufnr] then
        return
    end

    watched_buf[bufnr] = true
    local timer

    api.nvim_create_autocmd("BufModifiedSet", {
        group = augroup,
        buffer = bufnr,
        callback = function()
            if timer then
                timer:stop()
            else
                timer = loop.new_timer()
            end

            local callback = vim.schedule_wrap(function()
                timer:stop()
                timer:close()
                timer = nil
                status.update_status(bufnr)
            end)
            timer:start(BUF_MODIFY_DEBOUNCE, 0, callback)
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
