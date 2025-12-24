local M = {}

function M.insert()
    local reg = vim.fn.getreg('+')

    -- Set if empty
    if reg == '' then
        vim.notify("Mdn: Nothing detected in clipboard; \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    -- Sanitize text to prevent chaos
    vim.fn.setreg('+', reg:gsub("[%c]", ""))

    -- Get the selected text
    local col_start = vim.fn.getpos("'<")[3]
    local col_end = vim.fn.getpos("'>")[3]
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local selected_text = line:sub(col_start, col_end)

    -- This would happen when there is no selection
    if current_col ~= col_start then
        -- Get the word under cursor and cursor position
        selected_text = vim.fn.expand("<cword>")

        -- Search for the word in the line and check if it's under the cursor
        for start_pos, end_pos in line:gmatch("()" .. selected_text .. "()") do
            start_pos = vim.fn.str2nr(start_pos)
            end_pos = vim.fn.str2nr(end_pos)
            if start_pos < current_col and end_pos > current_col then
                col_start = start_pos
                col_end = end_pos - 1
            end
        end
    end

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. '[' .. selected_text .. '](' .. reg .. ')' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

function M.delete()
    vim.api.nvim_input('F["0di[f("+di(F[vf)"0p')
end

function M.toggle()
    local check_md_format = require('mdnotes.formatting').check_md_format
    if check_md_format(require("mdnotes.patterns").inline_link) then
        M.delete()
    else
        M.insert()
    end
end

return M
