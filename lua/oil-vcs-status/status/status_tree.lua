local config = require "oil-vcs-status.config"
local status_const = require "oil-vcs-status.constant.status"
local table_util = require "oil-vcs-status.util.table"

local StatusType = status_const.StatusType

-- Check is old status value should be overrite by new status value.
---@param old oil-vcs-status.StatusType
---@param new oil-vcs-status.StatusType
---@return boolean
local function check_should_overwrite_status(old, new)
    local old_priority = config.status_priority[old]
    local new_priority = config.status_priority[new]
    return new_priority > old_priority
end

---@class oil-vcs-status.status.StatusTree
---@field name string
---@field is_dirty boolean
---@field local_status oil-vcs-status.StatusType
---@field remote_status oil-vcs-status.StatusType
---@field parent? oil-vcs-status.status.StatusTree
---@field children? table<string, oil-vcs-status.status.StatusTree>
local StatusTree = {}
StatusTree.__index = StatusTree

---@param name string
---@return oil-vcs-status.status.StatusTree
function StatusTree:new(name)
    local obj = setmetatable({}, self)

    obj.name = name
    obj.is_dirty = true
    obj.local_status = StatusType.Unmodified
    obj.remote_status = StatusType.Unmodified

    return obj
end

-- Discard all children reset current root to Unmodified state.
function StatusTree:reset()
    self.local_status = StatusType.Unmodified
    self.remote_status = StatusType.Unmodified
    self.is_dirty = true
    self.children = nil
end

-- Propagate status change upwards, mark parent entry as dirty and try to update
-- status value of parnet.
function StatusTree:update_parent_status()
    local parent = self.parent
    if not parent then return end

    parent.is_dirty = true
    if check_should_overwrite_status(parent.local_status, self.local_status) then
        parent.local_status = self.local_status
    end
    if check_should_overwrite_status(parent.remote_status, self.remote_status) then
        parent.remote_status = self.remote_status
    end

    parent:update_parent_status()
end

-- Update status value of a child entry.
---@param path string
---@param local_status oil-vcs-status.StatusType
---@param remote_status oil-vcs-status.StatusType
function StatusTree:update_child(path, local_status, remote_status)
    local segments = vim.split(path, "/")

    local walker = self
    for _, segment in ipairs(segments) do
        local children = walker.children
        if not children then
            children = {}
            walker.children = children
        end

        local next_step = children[segment]
        if not next_step then
            next_step = StatusTree:new(segment)
            next_step.parent = walker
            children[segment] = next_step
        end

        walker = next_step
    end

    walker.local_status = local_status
    walker.remote_status = remote_status
    walker.is_dirty = true
    walker:update_parent_status()
end

-- Clear dirty flag of current entry.
function StatusTree:clear_dirty()
    self.is_dirty = false
end

-- Get child entry by path.
---@param path string
---@return oil-vcs-status.status.StatusTree?
function StatusTree:get_child_by_path(path)
    local segments = vim.split(path, "/")
    table_util.filter_in_place(segments, function(_, value)
        return value ~= ""
    end)

    local walker = self ---@type oil-vcs-status.status.StatusTree?
    for _, segment in ipairs(segments) do
        if not walker then
            break
        end

        local children = walker.children
        if not children then
            walker = nil
            break
        end

        local next_step = children[segment]
        if not next_step then
            walker = nil
            break
        end

        walker = next_step
    end

    return walker
end

return StatusTree
