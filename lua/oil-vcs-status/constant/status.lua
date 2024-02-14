local M = {}

---@enum oil-vcs-status.StatusType
M.StatusType = {
    Added = "added",
    Copied = "copied",
    Deleted = "deleted",
    Ignored = "ignored",
    Modified = "modified",
    Renamed = "renamed",
    TypeChanged = "typechanged",
    Unmodified = "unmodified",
    Unmerged = "unmerged",
    Untracked = "untracked",
}

return M
