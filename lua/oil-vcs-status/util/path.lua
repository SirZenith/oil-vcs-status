local M = {}

local uv = vim.uv or vim.loop

---@param path string
---@param names string[]
---@return boolean
local function check_child_dir_exists(path, names)
    local exists = false

    for _, name in ipairs(names) do
        local target = path .. "/" .. name
        exists = vim.fn.isdirectory(target) == 1
        if exists then
            break
        end
    end

    return exists
end

---@param path string
---@param names string[]
local function check_child_file_exists(path, names)
    local exists = false

    for _, name in ipairs(names) do
        local target = path .. "/" .. name
        exists = vim.fn.filereadable(target) == 1
        if exists then
            break
        end
    end

    return exists
end

-- Find root directory by existance of specific file or directory.
---@param path string
---@param names string[]
---@return string? root_dir # normalized absolute path of repo root.
function M.find_root_by_entry(path, names)
    local last_dir = ""
    local cur_dir = path
    local root

    while
        not root
        and cur_dir ~= last_dir
        and cur_dir ~= "."
    do
        if check_child_file_exists(cur_dir, names) then
            root = cur_dir
        elseif check_child_dir_exists(cur_dir, names) then
            root = cur_dir
        else
            last_dir = cur_dir
            cur_dir = vim.fs.dirname(cur_dir)
        end
    end

    if not root then return nil end

    root = vim.fn.fnamemodify(root, ":p")
    root = vim.fs.normalize(root)

    return root
end

-- Internal function, takes symlink path recursively resolve it's target path.
---@param path string
---@param recursion_level integer
---@return string?
local function get_actual_entry_path_recursive(path, recursion_level)
    local max_level = 50
    if recursion_level > max_level then
        return
    end

    local info = uv.fs_lstat(path)
    if info.type ~= "link" then
        return path
    end

    local target = uv.fs_readlink(path)

    return get_actual_entry_path_recursive(target, recursion_level + 1)
end

-- Takes path of symlink and returns the path it's pointing to. If this symlink
-- points to another symlink, then this function will be called recursively to
-- resolve file path to final non symlink entry.
---@param path string
---@return string
function M.get_actual_entry_path(path)
    return get_actual_entry_path_recursive(path, 1) or path
end

return M
