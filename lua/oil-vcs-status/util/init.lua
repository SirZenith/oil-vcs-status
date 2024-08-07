local loop = vim.uv or vim.loop

local M = {}

---@class oil-vcs-status.util.CmdResult
---@field code integer
---@field signal integer
---@field stdout string
---@field stderr string

---@class oil-vcs-status.util.CmdOptions
---@field args string[]
---@field cwd string

---@param cmd string
---@param opt oil-vcs-status.util.CmdOptions
---@param callback? fun(result: oil-vcs-status.util.CmdResult)
function M.run_cmd(cmd, opt, callback)
    local stdout = loop.new_pipe()
    local stderr = loop.new_pipe()

    local out_buffer = {}
    local err_buffer = {}

    loop.spawn(cmd, {
        stdio = { nil, stdout, stderr },
        args = opt.args,
        cwd = opt.cwd,
        hide = true,
    }, function(code, signal)
        if not callback then
            return
        end

        vim.schedule(function()
            callback {
                code = code,
                signal = signal,
                stdout = table.concat(out_buffer),
                stderr = table.concat(err_buffer),
            }
        end)
    end)

    loop.read_start(stdout, function(err, data)
        if err or not data then return end
        out_buffer[#out_buffer + 1] = data
    end)

    loop.read_start(stderr, function(err, data)
        if err or not data then return end
        err_buffer[#err_buffer + 1] = data
    end)
end

---@alias oil-vcs-status.util.IgnoreFsEventMap table<string, true | { change?: true, rename?: true }>

---@param ignore_map oil-vcs-status.util.IgnoreFsEventMap
---@param filename string
---@param events { change: boolean | nil, rename: boolean | nil }
function M.check_should_ignore_fs_event_by_ignore_map(ignore_map, filename, events)
    filename = vim.fs.normalize(filename)

    local ignore_data = ignore_map[filename]
    if not ignore_data then return false end

    local is_ignore = true

    if type(ignore_data) == "table" then
        for key in pairs(events) do
            if not ignore_data[key] then
                is_ignore = false
                break
            end
        end
    end

    return is_ignore
end

-- Inherit class table by deep copy
---@param base_class table
---@return table
function M.inherit(base_class)
    local sub_class = vim.deepcopy(base_class)
    return sub_class
end

return M
