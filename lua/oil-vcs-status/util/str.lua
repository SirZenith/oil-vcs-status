local M = {}

-- Prepend 0 to `value` if `value` has less digit than `digit`.
---@param value integer
---@param digit integer
function M.zero_pad(value, digit)
    if value < 1 then
        return tostring(value)
    end

    local cnt = 0
    local temp = value
    while temp >= 1 do
        temp = temp / 10
        cnt = cnt + 1
    end

    if cnt >= digit then
        return tostring(value)
    end

    return ("0"):rep(digit - cnt) .. tostring(value)
end

---@param now? integer
function M.get_time_str(now)
    local time_tbl = os.date("*t", now)
    local time_str = ("%s:%s:%s"):format(
        M.zero_pad(time_tbl.hour --[[@as integer]], 2),
        M.zero_pad(time_tbl.min --[[@as integer]], 2),
        M.zero_pad(time_tbl.sec --[[@as integer]], 2)
    )
    return time_str
end

return M
