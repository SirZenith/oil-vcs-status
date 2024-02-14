local M = {}

-- Filter out element that doesn't satisfy given predicate from list.
---@generic T
---@param list T[]
---@param cond fun(index: integer, value: T): boolean
function M.filter_in_place(list, cond)
    local total_cnt = #list
    local cnt = 0
    for i = 1, total_cnt do
        local value = list[i]
        local ok = cond(i, value)
        if ok then
            cnt = cnt + 1
            list[cnt] = value
        end
    end

    for i = cnt + 1, total_cnt do
        list[i] = nil
    end
end

return M
