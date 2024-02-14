local autocmd = require "oil-vcs-status.autocmd"
local log = require "oil-vcs-status.log"
local status = require "oil-vcs-status.status"

log.level = vim.log.levels.TRACE

local M = {}

local function setup_defualt_highlight()
    local hl_map = {
        OilVcsStatusAdded = {
            link = "DiffAdd",
        },
        OilVcsStatusCopied = {
            link = "DiffAdd",
        },
        OilVcsStatusDeleted = {
            link = "DiffDelete"
        },
        OilVcsStatusIgnored = {
            link = "Comment",
        },
        OilVcsStatusModified = {
            link = "DiffChange",
        },
        OilVcsStatusRenamed = {
            link = "DiffChange",
        },
        OilVcsStatusTypeChanged = {
            link = "DiffChange",
        },
        OilVcsStatusUnmodified = {
            link = "Normal",
        },
        OilVcsStatusUnmerged = {
            link = "",
        },
        OilVcsStatusUntracked = {
            link = "DiffText",
        },
    }

    for name, value in pairs(hl_map) do
        value.default = true
        vim.api.nvim_set_hl(0, name, value)
    end
end

local initialized = false

function M.init()
    if initialized then return end
    initialized = true

    autocmd.setup_autocmd()
    setup_defualt_highlight()

    status.on_dir_changed()
end

return M
