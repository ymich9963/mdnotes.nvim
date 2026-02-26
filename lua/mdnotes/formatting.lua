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

local check_markdown_syntax = function(...) return require('mdnotes').check_markdown_syntax(...) end

---@class MdnListContent List item contents that have been deemed important by me
---@field indent string Indent of list item
---@field marker string List item marker
---@field separator string List item separator, only in ordered lists
---@field text string List item text
---@field type '"ordered"'|'"unordered"'

---@class MdnLineRange
---@field buffer integer?
---@field range {lnum_start: integer?, lnum_end: integer?}
---@field silent boolean?

---@class MdnInsertFormatOpts: MdnFormattingOpts
---@field split_fi boolean? Split formatting indicator

---Insert a Markdown format
---@param format_char MdnFormatIndicators
---@param opts MdnInsertFormatOpts?
function M.insert_format(format_char, opts)
    opts = opts or {}
    local split_fi = opts.split_fi or false
    local move_cursor = opts.move_cursor ~= false

    vim.validate("split_fi", split_fi, "boolean")
    vim.validate("format_char", format_char, "string")
    vim.validate("move_cursor", move_cursor, "boolean")

    if split_fi == nil then split_fi = false end
    local txtdata = require('mdnotes').get_text({ location = opts.location })
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

    local txtdata = require('mdnotes').get_text_in_pattern(pattern, {location = opts.location})
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
    local ret = check_markdown_syntax(md_format.emphasis.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.emphasis.pattern(), { location = opts.location, move_cursor = opts.move_cursor })
    elseif ret == false then
        M.insert_format(md_format.emphasis.indicator(), { location = opts.location, move_cursor = opts.move_cursor })
    end
end

---Toggle the strong Markdown formatting
---@param opts MdnFormattingOpts?
function M.strong_toggle(opts)
    opts = opts or {}
    local ret = check_markdown_syntax(md_format.strong.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.strong.pattern(), { location = opts.location, move_cursor = opts.move_cursor })
    elseif ret == false then
        M.insert_format(md_format.strong.indicator(), { location = opts.location, move_cursor = opts.move_cursor })
    end
end

---Toggle the strikethrough Markdown formatting
---@param opts MdnFormattingOpts?
function M.strikethrough_toggle(opts)
    opts = opts or {}
    local ret = check_markdown_syntax(md_format.strikethrough.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.strikethrough.pattern(), { location = opts.location, move_cursor = opts.move_cursor })
    elseif ret == false then
        M.insert_format(md_format.strikethrough.indicator(), { location = opts.location, move_cursor = opts.move_cursor })
    end
end

---Toggle the inline code Markdown formatting
---@param opts MdnFormattingOpts?
function M.inline_code_toggle(opts)
    opts = opts or {}
    local ret = check_markdown_syntax(md_format.inline_code.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.inline_code.pattern(), { location = opts.location, move_cursor = opts.move_cursor })
    elseif ret == false then
        M.insert_format(md_format.inline_code.indicator(), { location = opts.location, move_cursor = opts.move_cursor })
    end
end

---Toggle the autolink Markdown formatting
---@param opts MdnFormattingOpts?
function M.autolink_toggle(opts)
    opts = opts or {}
    local ret = check_markdown_syntax(md_format.autolink.pattern(), { location = opts.location })
    if ret == true then
        M.delete_format(md_format.autolink.pattern(), { location = opts.location, move_cursor = opts.move_cursor })
    elseif ret == false then
        M.insert_format(md_format.autolink.indicator(), { location = opts.location, move_cursor = opts.move_cursor, split_fi = true })
    end
end

---Get a consistent table containing all data on a list item whether it is ordered or unordered
---@param line string Line containing list item
---@return MdnListContent
function M.resolve_list_content(line)
    vim.validate("line", line, "string")

    local mdnotes_patterns = require('mdnotes.patterns')

    local ul_indent, ul_marker, ul_text = line:match(mdnotes_patterns.unordered_list)
    local ol_indent, ol_marker, ol_separator, ol_text = line:match(mdnotes_patterns.ordered_list)

    local indent = (ul_indent or ol_indent) or ""
    local marker = ul_marker or ol_marker
    local separator = ol_separator or ""
    local text = (ul_text or ol_text) or ""

    local type = ""
    if ol_separator == nil then
        type = "unordered"
    else
        type = "ordered"
    end

    return {
        indent = indent,
        marker = marker,
        separator = separator,
        text = text,
        type = type
    }
end

---Toggle task list state
---@param opts MdnLineRange?
function M.task_list_toggle(opts)
    opts = opts or {}
    local buffer = opts.buffer or 0
    local silent = opts.silent or false
    local range = opts.range or {}
    local lnum_start = range.lnum_start or vim.fn.line('.')
    local lnum_end = range.lnum_end or vim.fn.line('.')

    vim.validate("buffer", buffer, "number")
    vim.validate("silent", silent, "boolean")
    vim.validate("lnum_start", lnum_start, "number")
    vim.validate("lnum_end", lnum_end, "number")

    local mdnotes_patterns = require('mdnotes.patterns')
    local new_lines = {}
    local new_text = ""
    local lines = vim.api.nvim_buf_get_lines(buffer, lnum_start - 1, lnum_end, false)

    local cur_col = vim.fn.col('.')
    for i, line in ipairs(lines) do
        local lcontent = M.resolve_list_content(line) or {}
        local marker, separator, text = lcontent.marker, lcontent.separator, lcontent.text

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
            if silent == false then
                vim.notify(("Mdn: Unable to detect a task list marker at line ".. tostring(lnum_start - 1 + i)), vim.log.levels.ERROR)
            end
            return
        end
    end

    if cur_col < 1 then cur_col = 1 end

    if #lines == 1 then
        vim.fn.cursor(lnum_start, cur_col)
    end

    vim.api.nvim_buf_set_lines(buffer, lnum_start - 1, lnum_end, false, new_lines)
end

--TODO: Tests for function
---Check if the list surrounding the origin line is valid and return its line numbers
---@param opts {same_indent: boolean?, search: MdnSearchOpts?, outliner_list: boolean?}?
---@return boolean list_valid , integer list_startl, integer list_endl 
function M.check_list_valid(opts)
    opts = opts or {}

    local outliner_list = opts.outliner_list or false
    local same_indent = opts.same_indent or false
    local search_opts = opts.search or {}
    local buffer = search_opts.buffer or vim.api.nvim_get_current_buf()
    local origin_lnum = search_opts.origin_lnum or vim.fn.line('.')
    local upper_limit_lnum = search_opts.upper_limit_lnum or vim.fn.line('0')
    local lower_limit_lnum = search_opts.lower_limit_lnum or vim.fn.line('$')

    local origin_line = vim.api.nvim_buf_get_lines(buffer, origin_lnum - 1, origin_lnum, false)[1]
    local lcontent = M.resolve_list_content(origin_line)
    if lcontent.marker == nil or lcontent.separator == nil then
        return false, 0, 0
    end

    local cur_line = ""
    local list_startl = 0
    local list_endl = 0
    local detected_separator = lcontent.separator
    local detected_indent = lcontent.indent

    -- If the list should be treated as an outliner list
    if outliner_list == true then
        list_endl = origin_lnum
        for i = origin_lnum, lower_limit_lnum do
            cur_line = vim.fn.getline(i)
            lcontent = M.resolve_list_content(cur_line)
            if lcontent.indent == detected_indent and i > origin_lnum then break end
            if lcontent.indent >= detected_indent then
                list_endl = i
            end
        end

        return true, origin_lnum, list_endl
    end

    -- Find where list starts
    for i = origin_lnum, upper_limit_lnum, -1 do
        cur_line = vim.fn.getline(i)
        lcontent = M.resolve_list_content(cur_line)
        if not lcontent.marker and lcontent.separator ~= detected_separator then
            break
        end
        if same_indent == true and lcontent.indent ~= detected_indent  then
            break
        end
        list_startl = i - 1
    end

    -- Find where the list ends
    for i = origin_lnum, lower_limit_lnum do
        cur_line = vim.fn.getline(i)
        lcontent = M.resolve_list_content(cur_line)
        if not lcontent.marker and lcontent.separator ~= detected_separator and lcontent.indent ~= detected_indent then
            break
        end
        if same_indent == true and lcontent.indent ~= detected_indent  then
            break
        end
        list_endl = i
    end

    return true, list_startl, list_endl
end

---Renumber the ordered list
---@param opts {silent: boolean?, search: MdnSearchOpts}? opts.silent: Silence notifications
function M.ordered_list_renumber(opts)
    opts = opts or {}
    local silent = opts.silent or false
    local search_opts = opts.search or {}
    local origin_lnum = search_opts.origin_lnum or vim.fn.line('.')
    local buffer = search_opts.buffer or vim.api.nvim_get_current_buf()

    vim.validate("silent", silent, "boolean")

    local list_valid, list_startl, list_endl = M.check_list_valid(search_opts)
    if list_valid == false then
        if silent == false then
            vim.notify("Mdn: Unable to detect an ordered list", vim.log.levels.ERROR)
        end
        return
    end

    local ol_pattern = require('mdnotes.patterns').ordered_list
    local line = vim.api.nvim_buf_get_lines(buffer, origin_lnum - 1, origin_lnum, false)[1]
    local spaces, num, separator, text = line:match(ol_pattern)

    -- Only case where text is nil is when it detects an unordered list
    if text == nil then
        if silent == false then
            vim.notify("Mdn: Cannot reorder an unordered list", vim.log.levels.ERROR)
        end
        return
    end

    -- Get list
    local list_lines = vim.api.nvim_buf_get_lines(buffer, list_startl, list_endl, false)

    local new_list_lines = {}
    for i, v in ipairs(list_lines) do
        spaces, num, separator, text = v:match(ol_pattern)
        if tonumber(num) ~= i then
            num = tostring(i)
        end
        table.insert(new_list_lines, spaces .. num .. separator .. " " .. text)
    end

    vim.api.nvim_buf_set_lines(buffer, list_startl, list_endl, false, new_list_lines)
end

---Remove Markdown formatting from the selected lines
---@param opts MdnLineRange?
function M.unformat_lines(opts)
    opts = opts or {}
    local buffer = opts.buffer or 0
    local silent = opts.silent or false
    local range = opts.range or {}
    local lnum_start = range.lnum_start or vim.fn.line('.')
    local lnum_end = range.lnum_end or vim.fn.line('.')

    vim.validate("buffer", buffer, "number")
    vim.validate("silent", silent, "boolean")
    vim.validate("lnum_start", lnum_start, "number")
    vim.validate("lnum_end", lnum_end, "number")

    local mdnotes_patterns = require('mdnotes.patterns')
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

    local lines = vim.api.nvim_buf_get_lines(buffer, lnum_start - 1, lnum_end, false)

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

    vim.api.nvim_buf_set_lines(buffer, lnum_start - 1, lnum_end, false, new_lines)
end

return M
