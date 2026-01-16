local M = {}

function M.create_md_buffer(child, lines)
    local buf = child.api.nvim_create_buf(false, true)
    child.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    child.api.nvim_set_current_buf(buf)
    child.bo.filetype = "markdown"

    return buf
end

function M.visual_select_text(child, start_row, start_col, move_right, move_left, move_down, move_up)
    child.api.nvim_win_set_cursor(0, {start_row, start_col})
    local input_text = ""
    if move_right ~= 0 then input_text = input_text .. move_right .. "l" end
    if move_left ~= 0 then input_text = input_text .. move_left .. "h" end
    if move_up ~= 0 then input_text = input_text .. move_up .. "k" end
    if move_down ~= 0 then input_text = input_text .. move_down .. "j" end
    child.api.nvim_input("v" .. input_text)
end

return M
