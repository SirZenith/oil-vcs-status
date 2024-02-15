local M = {}

---@enum oil-vcs-status.StatusType
M.StatusType = {
    Added               = "added",
    Copied              = "copied",
    Deleted             = "deleted",
    Ignored             = "ignored",
    Modified            = "modified",
    Renamed             = "renamed",
    TypeChanged         = "typechanged",
    Unmodified          = "unmodified",
    Unmerged            = "unmerged",
    Untracked           = "untracked",

    UpstreamAdded       = "upstream_added",
    UpstreamCopied      = "upstream_copied",
    UpstreamDeleted     = "upstream_deleted",
    UpstreamIgnored     = "upstream_ignored",
    UpstreamModified    = "upstream_modified",
    UpstreamRenamed     = "upstream_renamed",
    UpstreamTypeChanged = "upstream_typechanged",
    UpstreamUnmodified  = "upstream_unmodified",
    UpstreamUnmerged    = "upstream_unmerged",
    UpstreamUntracked   = "upstream_untracked",
}

return M
