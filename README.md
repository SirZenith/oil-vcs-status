# oil-vcs-status.nvim

## Overview

This plugin shows status symbol of your version control system in oil.nvim
buffers.

Currently supported systems are:

- git
- svn

## Usage

Install this plugin with plugin manager of your choice.

This plugin depends on [oil.nvim](https://github.com/stevearc/oil.nvim), make
sure you install oil.nvim and load it before this plugin.

Then you should make sure you enable signcolumn in you oil.nvim buffers. For
example, you can add this to you oil.nvim config:

```lua
require "oil".setup {
    win_options = {
        signcolumn = "number",
    }
}
```

After that, you should be able to see VCS status symbols.

## Configuration

You don't have to set any option value to use this plugin, if you want to
customize status symbol appearance, you can pass you config table to plugin
like following:

```lua
local status_const = require "oil-vcs-status.constant.status"

local StatusType = status_const.StatusType

require "oil-vcs-status".setup {
    -- Executable path of each version control system.
    vcs_executable = {
        git = "git",
        svn = "svn",
    },

    -- Sign character used by each status.
    ---@type table<oil-vcs-status.StatusType, string>
    status_symbol = {
        [StatusType.Added]               = "A",
        [StatusType.Copied]              = "C",
        [StatusType.Deleted]             = "D",
        [StatusType.Ignored]             = "!",
        [StatusType.Modified]            = "M",
        [StatusType.Renamed]             = "R",
        [StatusType.TypeChanged]         = "T",
        [StatusType.Unmodified]          = " ",
        [StatusType.Unmerged]            = "U",
        [StatusType.Untracked]           = "?",
        [StatusType.External]            = "X",

        [StatusType.UpstreamAdded]       = "A",
        [StatusType.UpstreamCopied]      = "C",
        [StatusType.UpstreamDeleted]     = "D",
        [StatusType.UpstreamIgnored]     = "!",
        [StatusType.UpstreamModified]    = "M",
        [StatusType.UpstreamRenamed]     = "R",
        [StatusType.UpstreamTypeChanged] = "T",
        [StatusType.UpstreamUnmodified]  = " ",
        [StatusType.UpstreamUnmerged]    = "U",
        [StatusType.UpstreamUntracked]   = "?",
        [StatusType.UpstreamExternal]    = "X",
    },

    -- Highlight group name used by each status type.
    ---@type table<oil-vcs-status.StatusType, string | false>
    status_hl_group = {
        [StatusType.Added]               = "OilVcsStatusAdded",
        [StatusType.Copied]              = "OilVcsStatusCopied",
        [StatusType.Deleted]             = "OilVcsStatusDeleted",
        [StatusType.Ignored]             = "OilVcsStatusIgnored",
        [StatusType.Modified]            = "OilVcsStatusModified",
        [StatusType.Renamed]             = "OilVcsStatusRenamed",
        [StatusType.TypeChanged]         = "OilVcsStatusTypeChanged",
        [StatusType.Unmodified]          = "OilVcsStatusUnmodified",
        [StatusType.Unmerged]            = "OilVcsStatusUnmerged",
        [StatusType.Untracked]           = "OilVcsStatusUntracked",
        [StatusType.External]            = "OilVcsStatusExternal",

        [StatusType.UpstreamAdded]       = "OilVcsStatusUpstreamAdded",
        [StatusType.UpstreamCopied]      = "OilVcsStatusUpstreamCopied",
        [StatusType.UpstreamDeleted]     = "OilVcsStatusUpstreamDeleted",
        [StatusType.UpstreamIgnored]     = "OilVcsStatusUpstreamIgnored",
        [StatusType.UpstreamModified]    = "OilVcsStatusUpstreamModified",
        [StatusType.UpstreamRenamed]     = "OilVcsStatusUpstreamRenamed",
        [StatusType.UpstreamTypeChanged] = "OilVcsStatusUpstreamTypeChanged",
        [StatusType.UpstreamUnmodified]  = "OilVcsStatusUpstreamUnmodified",
        [StatusType.UpstreamUnmerged]    = "OilVcsStatusUpstreamUnmerged",
        [StatusType.UpstreamUntracked]   = "OilVcsStatusUpstreamUntracked",
        [StatusType.UpstreamExternal]    = "OilVcsStatusUpstreamExternal",
    },

    -- Sign priority of each staus. When sign column width is less then staus
    -- symbol number, symbol with higher priority will be shown.
    -- If signcolumn is wide enough, signs will be display from left to right in
    -- order of priority from low to high.
    ---@type table<oil-vcs-status.StatusType, number>
    status_priority = {
        [StatusType.UpstreamIgnored]     = 0,
        [StatusType.Ignored]             = 0,

        [StatusType.UpstreamUntracked]   = 1,
        [StatusType.Untracked]           = 1,

        [StatusType.UpstreamUnmodified]  = 2,
        [StatusType.Unmodified]          = 2,
        [StatusType.UpstreamExternal]    = 2,
        [StatusType.External]            = 2,

        [StatusType.UpstreamCopied]      = 3,
        [StatusType.UpstreamRenamed]     = 3,
        [StatusType.UpstreamTypeChanged] = 3,

        [StatusType.UpstreamDeleted]     = 4,
        [StatusType.UpstreamModified]    = 4,
        [StatusType.UpstreamAdded]       = 4,

        [StatusType.UpstreamUnmerged]    = 5,

        [StatusType.Copied]              = 13,
        [StatusType.Renamed]             = 13,
        [StatusType.TypeChanged]         = 13,

        [StatusType.Deleted]             = 14,
        [StatusType.Modified]            = 14,
        [StatusType.Added]               = 14,

        [StatusType.Unmerged]            = 15,
    },
}
```

### Priority

Each status type has its priority, when multiple items under them same
directory are modified, directory will take status with highest priority among
them as its status.

When signcolumn's width is less than the number of status symbol, only the
symbole with highest priority will be displayed.

Default priority value is suitable for signcolumn of one character wide. If you
want show both upstream status and local status from left to right at the same
time, you can set priority value like following:

```lua
require "oil".setup {
    win_options = {
        signcolumn = "yes:2",
    }
}

local status_const = require "oil-vcs-status.constant.status"

local StatusType = status_const.StatusType

require "oil-vcs-status".setup {
    status_priority = {
        [StatusType.UpstreamIgnored]     = 0,
        [StatusType.UpstreamUntracked]   = 1,
        [StatusType.UpstreamUnmodified]  = 2,

        [StatusType.UpstreamCopied]      = 3,
        [StatusType.UpstreamRenamed]     = 3,
        [StatusType.UpstreamTypeChanged] = 3,

        [StatusType.UpstreamDeleted]     = 4,
        [StatusType.UpstreamModified]    = 4,
        [StatusType.UpstreamAdded]       = 4,

        [StatusType.UpstreamUnmerged]    = 5,

        [StatusType.Ignored]             = 10,
        [StatusType.Untracked]           = 11,
        [StatusType.Unmodified]          = 12,

        [StatusType.Copied]              = 13,
        [StatusType.Renamed]             = 13,
        [StatusType.TypeChanged]         = 13,

        [StatusType.Deleted]             = 14,
        [StatusType.Modified]            = 14,
        [StatusType.Added]               = 14,

        [StatusType.Unmerged]            = 15,
    },
}
```

### Symbol Customization

This plugin use different character and highlight groups for local and upstream
status.

By default following highlight groups are used.

- Local status
  - OilVcsStatusAdded,
  - OilVcsStatusCopied,
  - OilVcsStatusDeleted,
  - OilVcsStatusIgnored,
  - OilVcsStatusModified,
  - OilVcsStatusRenamed,
  - OilVcsStatusTypeChanged,
  - OilVcsStatusUnmodified,
  - OilVcsStatusUnmerged,
  - OilVcsStatusUntracked,
  - OilVcsStatusExternal,
- Upstream status
  - OilVcsStatusUpstreamAdded,
  - OilVcsStatusUpstreamCopied,
  - OilVcsStatusUpstreamDeleted,
  - OilVcsStatusUpstreamIgnored,
  - OilVcsStatusUpstreamModified,
  - OilVcsStatusUpstreamRenamed,
  - OilVcsStatusUpstreamTypeChanged,
  - OilVcsStatusUpstreamUnmodified
  - OilVcsStatusUpstreamUnmerged,
  - OilVcsStatusUpstreamUntracked,
  - OilVcsStatusUpstreamExternal,
