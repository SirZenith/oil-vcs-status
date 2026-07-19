local status = require "oil-vcs-status.status"

local api = vim.api
local loop = vim.uv or vim.loop

local M = {}

local AUGROUP_NAME = "oil-vcs-status"
local BUF_MODIFY_DEBOUNCE = 100

-- Neovim >= 0.13 removed the `BufModifiedSet` autocmd event in favor of
-- `OptionSet modified` (neovim/neovim#35610). Detect which one is available
-- so this keeps working across Neovim versions.
local HAS_BUF_MODIFIED_SET = vim.fn.exists "##BufModifiedSet" == 1

local watched_buf = {}

---@param bufnr integer
---@param augroup any
local function setup_buf_change_watcher(bufnr, augroup)
    if watched_buf[bufnr] then
        return
    end

    watched_buf[bufnr] = true
    local timer

    local function on_modified()
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
    end

    if HAS_BUF_MODIFIED_SET then
        api.nvim_create_autocmd("BufModifiedSet", {
            group = augroup,
            buffer = bufnr,
            callback = on_modified,
        })
    else
        -- `buffer` and `pattern` are mutually exclusive in nvim_create_autocmd,
        -- and `OptionSet`'s pattern matches the option name, not a buffer
        -- pattern, so filter on the triggering buffer inside the callback.
        api.nvim_create_autocmd("OptionSet", {
            group = augroup,
            pattern = "modified",
            callback = function(args)
                if args.buf ~= bufnr then
                    return
                end
                on_modified()
            end,
        })
    end
end

function M.setup_autocmd()
    local augroup = api.nvim_create_augroup(AUGROUP_NAME, { clear = true })

    -- update oil buffer when buffer gets modified
    api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "oil",
        callback = function(args)
            local bufnr = args.buf
            setup_buf_change_watcher(bufnr, augroup)
        end,
    })

    -- update status after entering oil buffer
    api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function(args)
            local bufnr = args.buf
            status.update_status(bufnr)
        end,
    })

    -- mark system status dirty after write to local file
    api.nvim_create_autocmd("BufWritePost", {
        group = augroup,
        callback = function(args)
            local file = args.match
            if file then
                status.on_file_buf_write(file)
            end
        end,
    })
end

return M
