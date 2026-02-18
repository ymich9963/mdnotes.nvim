---@module 'mdnotes.history'
local M = {}

---@type table<integer> Table containing visited buffer numbers
M.buf_history = {}

---@type integer Current index when traversing the buffer history
M.current_index = 0

---Record buffer to buffer history
---@param buf_num integer? Buffer number to record. If nil it is the current buffer
function M.record_buf(buf_num)
    if buf_num == nil then buf_num = vim.api.nvim_get_current_buf() end
    vim.validate("buf_num", buf_num, "number")
    if M.current_index == 0 or M.buf_history[M.current_index] ~= buf_num then
        -- If the user has went back and the current buffer is not the same as the stored buffer
        -- Create a copy of the list up to the current index and then add the new buffer
        if M.current_index < #M.buf_history then
            M.buf_history = vim.list_slice(M.buf_history, 1, M.current_index)
        end
        table.insert(M.buf_history, buf_num)
        M.current_index = #M.buf_history
    end
end

---Go back in the buffer history
function M.go_back()
    if M.current_index > 1 then
        M.current_index = M.current_index - 1
        local prev_buf = M.buf_history[M.current_index]
        if vim.api.nvim_buf_is_valid(prev_buf) then
            vim.cmd("buffer " .. prev_buf)
        else
            vim.notify("Mdn: Attempting to access an invalid buffer", vim.log.levels.ERROR)
        end
    else
        vim.notify("Mdn: No more buffers to go back to", vim.log.levels.WARN)
    end
end

---Go forward in the buffer history
function M.go_forward()
    if M.current_index < #M.buf_history then
        M.current_index = M.current_index + 1
        local next_buf = M.buf_history[M.current_index]
        if vim.api.nvim_buf_is_valid(next_buf) then
            vim.cmd("buffer " .. next_buf)
        else
            vim.notify("Mdn: Attempting to access an invalid buffer", vim.log.levels.ERROR)
        end
    else
        vim.notify("Mdn: No more buffers to go forward to", vim.log.levels.WARN)
    end
end

---Clear the buffer history and reset the current index
function M.clear()
    M.buf_history = {}
    M.current_index = 0
end

return M
