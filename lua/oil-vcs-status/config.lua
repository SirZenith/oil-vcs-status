local status_const = require "oil-vcs-status.constant.status"

local StatusType = status_const.StatusType

local M = {
    vcs_executable = {
        git = "git",
    },

    ---@type table<oil-vcs-status.StatusType, string>
    status_symbol = {
        [StatusType.Added]       = "A",
        [StatusType.Copied]      = "C",
        [StatusType.Deleted]     = "D",
        [StatusType.Ignored]     = "!",
        [StatusType.Modified]    = "M",
        [StatusType.Renamed]     = "R",
        [StatusType.TypeChanged] = "T",
        [StatusType.Unmodified]  = " ",
        [StatusType.Unmerged]    = "U",
        [StatusType.Untracked]   = "?",
    },

    ---@type table<oil-vcs-status.StatusType, string | false>
    status_hl_group = {
        [StatusType.Added]       = "OilVcsStatusAdded",
        [StatusType.Copied]      = "OilVcsStatusCopied",
        [StatusType.Deleted]     = "OilVcsStatusDeleted",
        [StatusType.Ignored]     = "OilVcsStatusIgnored",
        [StatusType.Modified]    = "OilVcsStatusModified",
        [StatusType.Renamed]     = "OilVcsStatusRenamed",
        [StatusType.TypeChanged] = "OilVcsStatusTypeChanged",
        [StatusType.Unmodified]  = "OilVcsStatusUnmodified",
        [StatusType.Unmerged]    = "OilVcsStatusUnmerged",
        [StatusType.Untracked]   = "OilVcsStatusUntracked",
    },

    ---@type table<oil-vcs-status.StatusType, number>
    status_priority = {
        [StatusType.Ignored]     = 0,
        [StatusType.Unmodified]  = 1,
        [StatusType.Untracked]   = 2,

        [StatusType.Copied]      = 3,
        [StatusType.Renamed]     = 3,
        [StatusType.TypeChanged] = 3,

        [StatusType.Deleted]     = 4,
        [StatusType.Modified]    = 4,
        [StatusType.Added]       = 4,

        [StatusType.Unmerged]    = 5,
    },
}

return M
