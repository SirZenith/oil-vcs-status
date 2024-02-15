local autocmd = require "oil-vcs-status.autocmd"
local config = require "oil-vcs-status.config"
local log = require "oil-vcs-status.log"
local status = require "oil-vcs-status.status"

log.level = vim.log.levels.WARN

local M = {}

local function setup_defualt_highlight()
    local hl_map = {
        -- Work tree highlight groups
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
            link = "DiffDelete",
        },
        OilVcsStatusUntracked = {
            link = "DiffText",
        },
        OilVcsStatusExternal = {
            link = "Normal",
        },

        -- Upstream highlight groups
        OilVcsStatusUpstreamAdded = {
            link = "DiffAdd",
        },
        OilVcsStatusUpstreamCopied = {
            link = "DiffAdd",
        },
        OilVcsStatusUpstreamDeleted = {
            link = "DiffDelete"
        },
        OilVcsStatusUpstreamIgnored = {
            link = "Comment",
        },
        OilVcsStatusUpstreamModified = {
            link = "DiffChange",
        },
        OilVcsStatusUpstreamRenamed = {
            link = "DiffChange",
        },
        OilVcsStatusUpstreamTypeChanged = {
            link = "DiffChange",
        },
        OilVcsStatusUpstreamUnmodified = {
            link = "Normal",
        },
        OilVcsStatusUpstreamUnmerged = {
            link = "DiffDelete",
        },
        OilVcsStatusUpstreamUntracked = {
            link = "DiffText",
        },
        OilVcsStatusUpstreamExternal = {
            link = "Normal",
        },
    }

    for name, value in pairs(hl_map) do
        value.default = true
        vim.api.nvim_set_hl(0, name, value)
    end
end

local function merge_config_tbl(dst, src)
    for k, v in pairs(src) do
        local old_v = dst[k]

        if not old_v then
            dst[k] = v
        elseif type(old_v) ~= "table" then
            dst[k] = v
        else
            merge_config_tbl(old_v, v)
        end
    end
end

local initialized = false

function M.init()
    if initialized then return end
    initialized = true

    autocmd.setup_autocmd()
    setup_defualt_highlight()

    status.update_status(0)
end

---@param opts? table
function M.setup(opts)
    if opts then
        merge_config_tbl(config, opts)
    end
end

return M
