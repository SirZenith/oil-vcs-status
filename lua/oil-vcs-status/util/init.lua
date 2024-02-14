local loop = vim.loop

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

return M
