local M = {}

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

-- Find
---@param path string
---@param names string[]
---@return string?
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

    return root
end

return M
