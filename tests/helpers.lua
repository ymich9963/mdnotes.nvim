local M = {}

M.unordered_list_indicators = {"-", "+", "*"}
M.ordered_list_indicators = {".", ")"}

function M.create_md_buffer(child, lines)
    local buf = child.api.nvim_create_buf(false, true)
    child.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    child.api.nvim_set_current_buf(buf)
    child.bo.filetype = "markdown"

    return buf
end

return M
