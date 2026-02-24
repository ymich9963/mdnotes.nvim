---@module 'mdnotes.formatting'

local M = {}

---@class MdnFormattingOpts
---@field location MdnLocation?
---@field move_cursor boolean?

---@alias MdnFormats
---| '"emphasis"'
---| '"strong"'
---| '"strikethrough"'
---| '"inline_code"'
---| '"autolink"'

---@alias MdnFormatIndicators
---| '"**"'
---| '"__"'
---| '"*"'
---| '"_"'
---| '"~~"'
---| '"`"'
---| '"<>"'

---@class MdnFormatData
---@field indicator fun(): MdnFormatIndicators Function returning a string for the format indicator
---@field pattern fun(): MdnPattern Function returning the pattern for the specified Markdown format

---@type table<MdnFormats, MdnFormatData>
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

---Check text for a Markdown format
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnLocation?}?
---@return boolean|nil
function M.check_md_format(pattern, opts)
    opts = opts or {}
    vim.validate("pattern", pattern, "string")

    local locopts = opts.location or {}
    local bufnum = locopts.buffer or vim.api.nvim_get_current_buf()
    local linenum = locopts.lnum or vim.fn.line('.')
    local cur_col = locopts.cur_col or vim.fn.col('.')

    local line = vim.api.nvim_buf_get_lines(bufnum, linenum - 1, linenum, false)[1]

    for start_pos, _, end_pos in line:gmatch(pattern) do
        if start_pos <= cur_col and end_pos > cur_col then
            return true
        end
    end

    return false
end

---Get the text that was either, selected using Visual mode, under cursor in Normal mode, or specified using the opts table
---@param opts {location: MdnLocation?}?
---@return MdnText
function M.get_text(opts)
    opts = opts or {}
    local locopts = opts.location or {}

    local bufnum = locopts.buffer or vim.api.nvim_get_current_buf()
    local linenum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.getpos("'<")[3]
    local col_end = locopts.col_end or vim.fn.getpos("'>")[3]
    local cur_col = locopts.cur_col or vim.fn.col('.')

    local line = vim.api.nvim_buf_get_lines(bufnum, linenum - 1, linenum, false)[1]
    local text = line:sub(col_start, col_end)

    -- This would happen by default when executing in Normal mode
    if col_start == col_end then
        -- Get the word under cursor and cursor position
        text = vim.fn.expand("<cWORD>")

        -- Search for the word in the line and check if it's under the cursor
        for i = 1, #line do
            local start_pos, end_pos = line:find(text, i, true)
            if start_pos and end_pos then
                if start_pos <= cur_col and end_pos >= cur_col then
                    col_start = start_pos
                    col_end = end_pos
                    break
                end
            end
        end
    end

    -- Reset markers
    vim.fn.setpos("'<", {0,1,1,0})
    vim.fn.setpos("'>", {0,1,1,0})

    return {
        buffer = bufnum,
        lnum = linenum,
        col_start = col_start,
        col_end = col_end,
        cur_col = cur_col,
        text = text,
    }
end

---Get the text inside a pattern as well as the start and end columns
---Can use opts.location to specify location of search
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnLocation?}?
---@return MdnText
function M.get_text_in_pattern(pattern, opts)
    opts = opts or {}

    vim.validate("pattern", pattern, "string")

    local locopts = opts.location or {}
    local bufnum = locopts.buffer or vim.api.nvim_get_current_buf()
    local linenum = locopts.lnum or vim.fn.line('.')
    local col_start = -1 or locopts.col_start
    local col_end = -1 or locopts.col_end
    local cur_col = locopts.cur_col or math.floor((col_start + col_end) / 2)

    if cur_col == -1 then
        cur_col = vim.fn.col('.')
    end

    local line = vim.api.nvim_buf_get_lines(bufnum, linenum - 1, linenum, false)[1]

    local found_text = ""
    for start_pos, search_text, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos <= cur_col and end_pos > cur_col then
            found_text = search_text
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    return {
        buffer = bufnum,
        lnum = linenum,
        col_start = col_start,
        col_end = col_end,
        cur_col = cur_col,
        text = found_text,
    }
end

---Insert a Markdown format
---@param format_char MdnFormatIndicators
---@param opts {split_fi: boolean?, location: MdnLocation?, move_cursor: boolean?}?
function M.insert_format(format_char, opts)
    opts = opts or {}
    local split_fi = opts.split_fi or false
    local move_cursor = opts.move_cursor ~= false

    vim.validate("split_fi", split_fi, "boolean")
    vim.validate("format_char", format_char, "string")
    vim.validate("move_cursor", move_cursor, "boolean")

    if split_fi == nil then split_fi = false end
    local txtdata = M.get_text({ location = opts.location })
    local fi1, fi2 = "", ""

    if split_fi == true then
        fi1 = format_char:sub(1,#format_char / 2)
        fi2 = format_char:sub(-(#format_char / 2))
    else
        fi1 = format_char
        fi2 = format_char
    end

    -- Limit the end column value
    -- Visual mode and vimgrep can give end_col values after the line ending
    local line_len = #(vim.api.nvim_buf_get_lines(txtdata.buffer, txtdata.lnum - 1, txtdata.lnum, false)[1])
    if txtdata.col_end > line_len then
        txtdata.col_end = line_len
    end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buffer, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {fi1 .. txtdata.text .. fi2})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buffer)
        vim.fn.cursor({txtdata.lnum, vim.fn.getcurpos()[3] + #fi1})
    end
end

---Check current line position for text in a Markdown format
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnLocation?, move_cursor: boolean?}?
function M.delete_format(pattern, opts)
    opts = opts or {}
    local move_cursor = opts.move_cursor ~= false
    vim.validate("pattern", pattern, "string")
    vim.validate("move_cursor", move_cursor, "boolean")

    local txtdata = M.get_text_in_pattern(pattern, {location = opts.location})
    local line = vim.api.nvim_buf_get_lines(txtdata.buffer, txtdata.lnum - 1, txtdata.lnum, false)[1]

    -- Find the character count change before the cursor
    -- since only those characters change its position
    local new_line = line:sub(1, txtdata.col_start - 1) .. txtdata.text .. line:sub(txtdata.col_end)
    local char_count_change_bef_cursor = (#line - #new_line) / 2
    local new_col_pos = math.floor(vim.fn.getcurpos()[3] - char_count_change_bef_cursor)

    if new_col_pos < 0 then new_col_pos = 0 end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buffer, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end - 1, {txtdata.text})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buffer)
        vim.fn.cursor({txtdata.lnum, new_col_pos})
    end
end

---Toggle the emphasis Markdown formatting
---@param opts MdnFormattingOpts?
function M.emphasis_toggle(opts)
    opts = opts or {}
    local ret = M.check_md_format(md_format.emphasis.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.emphasis.pattern(), { location = opts.location, move_cursor = opts.move_cursor })
    elseif ret == false then
        M.insert_format(md_format.emphasis.indicator(), { location = opts.location, move_cursor = opts.move_cursor })
    end
end

---Toggle the strong Markdown formatting
function M.strong_toggle(opts)
    opts = opts or {}
    local ret = M.check_md_format(md_format.strong.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.strong.pattern(), {location = opts.location})
    elseif ret == false then
        M.insert_format(md_format.strong.indicator(), { location = opts.location })
    end
end

---Toggle the strikethrough Markdown formatting
function M.strikethrough_toggle(opts)
    opts = opts or {}
    local ret = M.check_md_format(md_format.strikethrough.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.strikethrough.pattern(), {location = opts.location})
    elseif ret == false then
        M.insert_format(md_format.strikethrough.indicator(), { location = opts.location })
    end
end

---Toggle the inline code Markdown formatting
function M.inline_code_toggle(opts)
    opts = opts or {}
    local ret = M.check_md_format(md_format.inline_code.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.inline_code.pattern(), {location = opts.location})
    elseif ret == false then
        M.insert_format(md_format.inline_code.indicator(), { location = opts.location })
    end
end

---Toggle the autolink Markdown formatting
function M.autolink_toggle(opts)
    opts = opts or {}
    local ret = M.check_md_format(md_format.autolink.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.autolink.pattern(), {location = opts.location})
    elseif ret == false then
        M.insert_format(md_format.autolink.indicator(), { split_fi = true, location = opts.location})
    end
end

---Resolve the list content
---@param line string Line containing list item
---@return string indent, string marker, string separator, string text List item contents that have been deemed important by me
function M.resolve_list_content(line)
    vim.validate("line", line, "string")

    local mdnotes_patterns = require('mdnotes.patterns')

    local ul_indent, ul_marker, ul_text = line:match(mdnotes_patterns.unordered_list)
    local ol_indent, ol_marker, ol_separator, ol_text = line:match(mdnotes_patterns.ordered_list)

    local indent = (ul_indent or ol_indent) or ""
    local marker = ul_marker or ol_marker
    local separator = ol_separator or ""
    local text = (ul_text or ol_text) or ""

    return indent, marker, separator, text
end

--TODO: More location options
---Toggle task list state
---@param line1 integer First line of selection
---@param line2 integer Last line of selection
function M.task_list_toggle(line1, line2)
    if line1 == nil then line1 = vim.fn.line('.') end
    if line2 == nil then line2 = line1 end

    vim.validate("line1", line1, "number")
    vim.validate("line2", line2, "number")

    local mdnotes_patterns = require('mdnotes.patterns')
    local new_lines = {}
    local new_text = ""
    local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)

    local cur_col = vim.fn.col('.')
    for i, line in ipairs(lines) do
        local _, marker, separator, text = M.resolve_list_content(line)

        if marker then
            marker = marker .. separator

            -- In the case where e.g. 1. or 1) then the . or ) need to be escaped
            if #marker == 2 then
                marker = marker:sub(1,1) .. "%" .. marker:sub(2,2)
            end

            local task_marker, _ = text:match(mdnotes_patterns.task)
            if task_marker == "[x]" then
                new_text, _ = line:gsub(mdnotes_patterns.task, " ", 1)
                cur_col = cur_col - 4
            elseif task_marker == "[ ]" then
                new_text, _ = line:gsub(mdnotes_patterns.task, " [x] ", 1)
            elseif task_marker == nil then
                new_text = line:gsub(marker, marker .. " [ ]", 1)
                cur_col = cur_col + 4
            end
            table.insert(new_lines, new_text)
        else
            vim.notify(("Mdn: Unable to detect a task list marker at line ".. tostring(line1 - 1 + i)), vim.log.levels.ERROR)
            break
        end
    end

    if cur_col < 1 then cur_col = 1 end

    if #lines == 1 then
        vim.fn.cursor(line1, cur_col)
    end

    vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, new_lines)
end

--TODO: More location options
---Renumber the ordered list
---@param opts {silent: boolean?}? opts.silent: Silence notifications
function M.ordered_list_renumber(opts)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local cur_line = vim.api.nvim_get_current_line()
    local cur_lnum = vim.fn.line('.')
    local ordered_list_pattern = require('mdnotes.patterns').ordered_list
    local spaces, num, separator, text = cur_line:match(ordered_list_pattern)
    local detected_separator = separator
    local new_list_lines = {}
    local line = ""
    local list_startl = 0
    local list_endl = 0


    if num == nil or separator == nil then
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

    -- Get list
    local list_lines = vim.api.nvim_buf_get_lines(0, list_startl, list_endl, false)

    for i, v in ipairs(list_lines) do
        spaces, num, separator, text = v:match(ordered_list_pattern)
        if tonumber(num) ~= i then
            num = tostring(i)
        end
        table.insert(new_list_lines, spaces .. num .. separator .. " " .. text)
    end

    vim.api.nvim_buf_set_lines(0, list_startl, list_endl, false, new_list_lines)
end

--TODO: More location options
---Remove Markdown formatting from the selected lines
---@param line1 number First line of selection
---@param line2 number Last line of selection
function M.unformat_lines(line1, line2)
    if line1 == nil then line1 = vim.fn.line('.') end
    if line2 == nil then line2 = vim.fn.line('.') end

    vim.validate("line1", line1, "number")
    vim.validate("line2", line2, "number")

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
            elseif pattern == mdnotes_patterns.task then
                line = line:gsub(pattern, "")
            elseif pattern == mdnotes_patterns.ordered_list then
                local _, _, _, ol_text = line:match(pattern)
                if ol_text then line = ol_text end
            elseif pattern == mdnotes_patterns.unordered_list then
                local _, _, ul_text = line:match(pattern)
                if ul_text then line = ul_text end
            elseif pattern == mdnotes_patterns.inline_link then
                for start_pos, inline_link, end_pos in line:gmatch(pattern) do
                    local inline_text, _ = inline_link:match(mdnotes_patterns.text_uri)
                    if inline_text then line = line:sub(1, vim.fn.str2nr(start_pos) - 1) .. inline_text .. line:sub(vim.fn.str2nr(end_pos)) end
                end
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
