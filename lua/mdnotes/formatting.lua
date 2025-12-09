local M = {}

M.patterns = require('mdnotes.patterns')

function M.check_md_format(pattern)
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, _, end_pos in line:gmatch(pattern) do
        if start_pos < current_col and end_pos > current_col then
            return true
        end
    end

    return false
end

local function insert_format(format_char)
    local line = vim.api.nvim_get_current_line()
    local new_line = ""

    -- Get the selected text
    local col_start = vim.fn.getpos("'<")[3]
    local col_end = vim.fn.getpos("'>")[3]
    local selected_text = line:sub(col_start, col_end)

    -- This would happen when executing in NORMAL mode
    if selected_text == "" then
        -- Get the word under cursor and cursor position
        local current_col = vim.fn.col('.')
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
    new_line = line:sub(1, col_start - 1) .. format_char .. selected_text .. format_char .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

function M.hyperlink_insert()
    local reg = vim.fn.getreg('+')

    -- Set if empty
    if reg == '' then
        vim.fn.setreg('+','"+ register empty')
    end

    -- Sanitize text to prevent chaos
    vim.fn.setreg('+', reg:gsub("[%c]", ""))

    -- Get the selected text
    local col_start = vim.fn.getpos("'<")[3]
    local col_end = vim.fn.getpos("'>")[3]
    local line = vim.api.nvim_get_current_line()
    local selected_text = line:sub(col_start, col_end)

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. '[' .. selected_text .. '](' .. reg .. ')' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

function M.hyperlink_delete()
    vim.api.nvim_input('F[di[F[vf)p')
end

local function delete_format_bold()
    local bold_char = require('mdnotes').bold_char
    vim.api.nvim_input('F' .. bold_char .. ';dwvf' .. bold_char .. 'hdvlp')
end

local function delete_format_italic()
    local italic_char = require('mdnotes').italic_char
    vim.api.nvim_input('F' .. italic_char .. 'dwvf' .. italic_char ..'hdvp')
end

local function delete_format_strikethrough()
    vim.api.nvim_input('F~;dwvf~hdvlp')
end

local function delete_format_inline_code()
    vim.api.nvim_input('F`dwvf`hdvp')
end

function M.bold_toggle()
    local bold_char = require('mdnotes').bold_char
    if M.check_md_format(M.patterns.bold) then
        delete_format_bold()
    else
        insert_format(bold_char .. bold_char)
    end
end

function M.italic_toggle()
    local italic_char = require('mdnotes').italic_char
    if M.check_md_format(M.patterns.italic) then
        delete_format_italic()
    else
        insert_format(italic_char)
    end
end

function M.strikethrough_toggle()
    if M.check_md_format(M.patterns.strikethrough) then
        delete_format_strikethrough()
    else
        insert_format('~~')
    end
end

function M.inline_code_toggle()
    if M.check_md_format(M.patterns.inline_code) then
        delete_format_inline_code()
    else
        insert_format('`')
    end
end

function M.hyperlink_toggle()
    if M.check_md_format(M.patterns.hyperlink) then
        M.hyperlink_delete()
    else
        M.hyperlink_insert()
    end
end

function M.task_list_toggle(line1, line2)
    local lines = {}
    local new_lines = {}
    if line1 == line2 then
        lines = {vim.api.nvim_get_current_line()}
    else
        lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    end
    for i, line in ipairs(lines) do
        local _, list_marker, list_text = line:match(M.patterns.unordered_list)
        local _, ordered_marker, separator, ordered_text = line:match(M.patterns.ordered_list)
        local text = list_text or ordered_text
        local marker = list_marker or ordered_marker .. separator
        local new_text = ""

        if marker then
            local task_marker = text:match(M.patterns.task)
            if task_marker == "[x]" then
                new_text, _ = line:gsub(M.patterns.task, " ", 1)
            elseif task_marker == "[ ]" then
                new_text, _ = line:gsub(M.patterns.task, " [x] ", 1)
            elseif not task_marker then
                new_text = line:gsub(marker, marker .. " [ ]", 1)
            end
            table.insert(new_lines, new_text)
        else
            vim.notify(("Mdn: Unable to detect a task list marker at line ".. tostring(line1 - 1 + i) .. "."), vim.log.levels.ERROR)
            break
        end
    end
    vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, new_lines)
end

function M.ordered_list_renumber(silent)
    local cur_line = vim.api.nvim_get_current_line()
    local cur_lnum = vim.fn.line('.')
    local ordered_list_pattern = require('mdnotes.patterns').ordered_list
    local spaces, num, separator, text = cur_line:match(ordered_list_pattern)
    local detected_separator = separator
    local new_list_lines = {}
    local line = ""
    local list_startl = 0
    local list_endl = 0


    if not num or not separator then
        if silent == true then
            return nil
        else
            vim.notify("Mdn: Unable to detect an ordered list", vim.log.levels.ERROR)
            return
        end
    end

    -- Find where list starts
    for i = cur_lnum, vim.fn.line('0'), -1 do
        line = vim.fn.getline(i)
        _, num, separator, _ = line:match(ordered_list_pattern)
        if num and separator == detected_separator then
            list_startl = i - 1
        else
            break
        end
    end

    -- Find where the list ends
    for i = cur_lnum, vim.fn.line('$') do
        line = vim.fn.getline(i)
        _, num, separator, _ = line:match(ordered_list_pattern)
        if num and separator == detected_separator then
            list_endl = i
        else
            break
        end
    end

    -- Just in case idk
    if list_startl == 0 or list_endl == 0 then
        return
    end

    -- Get list
    local list_lines = vim.api.nvim_buf_get_lines(0, list_startl, list_endl, false)

    for i, v in ipairs(list_lines) do
        spaces, num, separator, text = v:match(ordered_list_pattern)
        if tonumber(num) ~= i then
            num = tostring(i)
        end
        table.insert(new_list_lines, spaces .. num .. separator .. text)
    end

    vim.api.nvim_buf_set_lines(0, list_startl, list_endl, false, new_list_lines)
end

return M
