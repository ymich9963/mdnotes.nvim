---@module 'mdnotes.formatting'
local M = {}

---@alias MdnotesFormats
---| '"emphasis"'
---| '"strong"'
---| '"strikethrough"'
---| '"inline_code"'
---| '"autolink"'

---@alias MdnotesFormatIndicators
---| '"**"'
---| '"__"'
---| '"*"'
---| '"_"'
---| '"~~"'
---| '"`"'
---| '"<>"'

---@class MdnotesFormatData
---@field indicator fun(): MdnotesFormatIndicators Function returning a string for the format indicator
---@field pattern fun(): MdnotesPattern Function returning the pattern for the specified Markdown format

---@type table<MdnotesFormats, MdnotesFormatData>
local md_format = {
    emphasis = {
        indicator = function() return require('mdnotes').config.emphasis_format end,
        pattern = function() return require('mdnotes.patterns').emphasis end,
    },
    strong = {
        indicator = function() return require('mdnotes').config.strong_format end,
        pattern = function() return require('mdnotes.patterns').strong end,
    },
    strikethrough = {
        indicator = function() return "~~" end,
        pattern = function() return require('mdnotes.patterns').strikethrough end,
    },
    inline_code = {
        indicator = function() return "`" end,
        pattern = function() return require('mdnotes.patterns').inline_code end,
    },
    autolink = {
        indicator = function() return "<>" end,
        pattern = function() return require('mdnotes.patterns').autolink end,
    },
}

---Check current line position for text in a Markdown format
---@param pattern MdnotesPattern Pattern that returns the start and end columns, as well as the text
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

---Get the text that was selected using Visual mode
function M.get_selected_text()
    local col_start = vim.fn.getpos("'<")[3]
    local col_end = vim.fn.getpos("'>")[3]
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local selected_text = line:sub(col_start, col_end)

    -- This would happen when executing in NORMAL mode
    if current_col ~= col_start then
        -- Get the word under cursor and cursor position
        selected_text = vim.fn.expand("<cword>")

        -- Search for the word in the line and check if it's under the cursor
        for start_pos, end_pos in line:gmatch("()" .. selected_text .. "()") do
            start_pos = vim.fn.str2nr(start_pos)
            end_pos = vim.fn.str2nr(end_pos)
            if start_pos <= current_col and end_pos > current_col then
                col_start = start_pos
                col_end = end_pos - 1
                break
            end
        end
    end

    return selected_text, col_start, col_end
end

---Get the text inside a pattern as well as the start and end columns under the cursor
---@param pattern MdnotesPattern Pattern that returns the start and end columns, as well as the text
function M.get_text_in_pattern(pattern)
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local col_start = 0
    local col_end = 0
    local found_text = ""

    for start_pos, text, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            found_text = text
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    return found_text, col_start, col_end
end

---Insert a Markdown format
---@param format_char MdnotesFormatIndicators
---@param split boolean? Should the inputted format indicator be separated
local function insert_format(format_char, split)
    if not split then split = false end
    local line = vim.api.nvim_get_current_line()
    local selected_text, col_start, col_end = M.get_selected_text()
    local fi1 = format_char
    local fi2 = format_char

    if split == true then
        fi1 = format_char:sub(1,1)
        fi2 = format_char:sub(2,2)
    end

    if fi2 == "" then
        fi2 = fi1
    end

    -- Create a new modified line
    local new_line = line:sub(1, col_start - 1) .. fi1 .. selected_text .. fi2 .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end})
end

---Check current line position for text in a Markdown format
---@param pattern MdnotesPattern Pattern that returns the start and end columns, as well as the text
local function delete_format(pattern)
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local col_start = 0
    local col_end = 0
    local found_text = ""

    for start_pos, text, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            found_text = text
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. found_text .. line:sub(col_end)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_start - 1})
end

---Toggle the strong Markdown formatting
function M.strong_toggle()
    if M.check_md_format(md_format.strong.pattern()) == true then
        delete_format(md_format.strong.pattern())
    else
        insert_format(md_format.strong.indicator())
    end
end

---Toggle the emphasis Markdown formatting
function M.emphasis_toggle()
    if M.check_md_format(md_format.emphasis.pattern()) == true then
        delete_format(md_format.emphasis.pattern())
    else
        insert_format(md_format.emphasis.indicator())
    end
end

---Toggle the strikethrough Markdown formatting
function M.strikethrough_toggle()
    if M.check_md_format(md_format.strikethrough.pattern()) == true then
        delete_format(md_format.strikethrough.pattern())
    else
        insert_format(md_format.strikethrough.indicator())
    end
end

---Toggle the inline code Markdown formatting
function M.inline_code_toggle()
    if M.check_md_format(md_format.inline_code.pattern()) == true then
        delete_format(md_format.inline_code.pattern())
    else
        insert_format(md_format.inline_code.indicator())
    end
end

---Toggle the autolink Markdown formatting
function M.autolink_toggle()
    if M.check_md_format(md_format.autolink.pattern()) == true then
        delete_format(md_format.autolink.pattern())
    else
        insert_format(md_format.autolink.indicator())
    end
end

---Toggle task list state
---@param line1 number First line of selection
---@param line2 number Last line of selection
function M.task_list_toggle(line1, line2)
    local mdnotes_patterns = require('mdnotes.patterns')

    local lines = {}
    local new_lines = {}
    if line1 == line2 then
        lines = {vim.api.nvim_get_current_line()}
    else
        lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    end
    for i, line in ipairs(lines) do
        local _, list_marker, list_text = line:match(mdnotes_patterns.unordered_list)
        local _, ordered_marker, separator, ordered_text = line:match(mdnotes_patterns.ordered_list)
        local text = list_text or ordered_text
        local marker = list_marker or ordered_marker .. separator
        local new_text = ""

        if marker then
            local task_marker = text:match(mdnotes_patterns.task)
            if task_marker == "[x]" then
                new_text, _ = line:gsub(mdnotes_patterns.task, " ", 1)
            elseif task_marker == "[ ]" then
                new_text, _ = line:gsub(mdnotes_patterns.task, " [x] ", 1)
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

---Renumber the ordered list
---@param silent boolean? Output error message or not
function M.ordered_list_renumber(silent)
    if not silent then silent = false end
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

---Remove Markdown formatting from the selected lines
---@param line1 number First line of selection
---@param line2 number Last line of selection
function M.unformat_lines(line1, line2)
    local mdnotes_patterns = require('mdnotes.patterns')
    local lines = {}
    local new_lines = {}

    local patterns = {
        mdnotes_patterns.strong,
        mdnotes_patterns.wikilink,
        mdnotes_patterns.emphasis,
        mdnotes_patterns.strikethrough,
        mdnotes_patterns.inline_code,
        mdnotes_patterns.heading,
        mdnotes_patterns.inline_link,
        mdnotes_patterns.ordered_list,
        mdnotes_patterns.unordered_list,
        mdnotes_patterns.task,
    }

    if line1 == line2 then
        lines = {vim.api.nvim_get_current_line()}
    else
        lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    end

    for _, line in ipairs(lines) do
        line = line:gsub("[^%d%a%p ]+", "")
        for _, pattern in ipairs(patterns) do
            if pattern == mdnotes_patterns.heading then
                local _, heading_text = line:match(pattern)
                if heading_text then line = heading_text end
            elseif pattern == mdnotes_patterns.inline_link then
                for start_pos, inline_link, end_pos in line:gmatch(pattern) do
                    local inline_text, _ = inline_link:match(mdnotes_patterns.text_uri)
                    if inline_text then line = line:sub(1, vim.fn.str2nr(start_pos) - 1) .. inline_text .. line:sub(vim.fn.str2nr(end_pos)) end
                end
            elseif pattern == mdnotes_patterns.ordered_list then
                local _, _, _, ol_text = line:match(pattern)
                if ol_text then line = ol_text end
            elseif pattern == mdnotes_patterns.unordered_list then
                local _, _, ul_text = line:match(pattern)
                if ul_text then line = ul_text end
            elseif pattern == mdnotes_patterns.task then
                line = line:gsub(pattern, "")
            else
                for start_pos, text, end_pos in line:gmatch(pattern) do
                    if text then line = line:sub(1, vim.fn.str2nr(start_pos) - 1) .. text .. line:sub(vim.fn.str2nr(end_pos)) end
                end
            end
        end
        table.insert(new_lines, line)
    end

    vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, new_lines)
end

return M
