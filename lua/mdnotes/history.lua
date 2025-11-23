local M = {}

M.buf_history = {}
M.current_index = 0

function M.go_back()
    if M.current_index > 1 then
        M.current_index = M.current_index - 1
        local prev_buf = M.buf_history[M.current_index]
        if vim.api.nvim_buf_is_valid(prev_buf) then
            vim.cmd("buffer " .. prev_buf)
        else
            vim.notify("Mdn: Attempting to access an invalid buffer.", vim.log.levels.ERROR)
        end
    else
        vim.notify("Mdn: No more buffers to go back to.", vim.log.levels.WARN)
    end
end

function M.go_forward()
    if M.current_index < #M.buf_history then
        M.current_index = M.current_index + 1
        local next_buf = M.buf_history[M.current_index]
        if vim.api.nvim_buf_is_valid(next_buf) then
            vim.cmd("buffer " .. next_buf)
        else
            vim.notify("Mdn: Attempting to access an invalid buffer.", vim.log.levels.ERROR)
        end
    else
        vim.notify("Mdn: No more buffers to go forward to.", vim.log.levels.WARN)
    end
end

function M.clear_history()
    M.buf_history = {}
    M.current_index = 0
end

return M
