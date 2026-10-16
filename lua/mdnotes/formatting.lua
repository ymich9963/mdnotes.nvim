---@module 'mdnotes.formatting'

local M = {}

---@alias MdnFormatDelimiterType
---| '"emphasis"'
---| '"strong"'
---| '"strikethrough"'
---| '"inline_code"'
---| '"autolink"'
---| '"wikilink"'

---@class MdnFormattingOpts
---@field location MdnInLineLocation?
---@field move_cursor boolean?

---@class MdnListItemData
---@field indent string Indent of list item
---@field marker string List item marker
---@field separator string List item separator, only in ordered lists
---@field text string List item text
---@field type '"ordered"'|'"unordered"'
---@field task_state string Task state string

local check_markdown_syntax = function(...) return require('mdnotes').check_markdown_syntax(...) end

local emphasis_delim = function() return require('mdnotes').config.emphasis_format end
local strong_delim = function() return require('mdnotes').config.strong_format end

---@alias MdnFormatDelimiter {ldel: string, rdel: string}

---Fields should be the same as MdnFormatDelimiterType
---@class MdnFormatDelimiters
---@field strong MdnFormatDelimiter
---@field emphasis MdnFormatDelimiter
---@field strikethrough MdnFormatDelimiter
---@field inline_code MdnFormatDelimiter
---@field autolink MdnFormatDelimiter
---@field wikilink MdnFormatDelimiter
M.format_delimiters = {
    strong = {ldel = strong_delim(), rdel = strong_delim()},
    emphasis = {ldel = emphasis_delim(), rdel = emphasis_delim()},
    strikethrough = {ldel = "~", rdel = "~"},
    inline_code = {ldel = "`", rdel = "`"},
    autolink = {ldel = "<", rdel = ">"},
    wikilink = {ldel = "[[", rdel = "]]"},
}

---Insert a Markdown format
---@param fdtype MdnFormatDelimiterType Format delimeter type
---@param opts MdnFormattingOpts?
function M.insert_format(fdtype, opts)
    vim.validate("opts", opts, "table", true)
    vim.validate("fdtype", fdtype, "string")

    opts = opts or {}
    local move_cursor = opts.move_cursor ~= false

    vim.validate("move_cursor", move_cursor, "boolean")

    local txtdata = require('mdnotes').get_text({ location = opts.location })
    if txtdata.raw == nil then
        return
    end

    local delimiter = M.format_delimiters[fdtype]

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {delimiter.ldel .. txtdata.raw .. delimiter.rdel})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') + #delimiter.ldel})
    end
end

---Delete the format indicators around a Markdown element
---@param fdtype MdnFormatDelimiterType Format delimeter type
---@param opts MdnFormattingOpts?
function M.delete_format(fdtype, opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.delete_format_re(fdtype, opts)
    elseif parser == "treesitter" then
        return M.delete_format_ts(fdtype, opts)
    end
end

---Delete the format indicators around a Markdown element using Lua patterns
---@param fdtype MdnFormatDelimiterType
---@param opts MdnFormattingOpts?
function M.delete_format_re(fdtype, opts)
    vim.validate("fdtype", fdtype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    vim.validate("move_cursor", move_cursor, "boolean")

    local pattern = require('mdnotes.patterns')[fdtype]
    local txtdata = require('mdnotes').get_text_in_pattern(pattern, {location = opts.location})
    local delimiter = M.format_delimiters[fdtype]

    local new_text = txtdata.raw:sub(#delimiter.ldel + 1, #txtdata.raw - #delimiter.rdel)

    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end - 1, {new_text})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') - #delimiter.ldel})
    end
end

---Delete the format indicators around a Markdown element using treesitter
---@param fdtype MdnFormatDelimiterType
---@param opts MdnFormattingOpts?
function M.delete_format_ts(fdtype, opts)
    vim.validate("fdtype", fdtype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    vim.validate("move_cursor", move_cursor, "boolean")

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')

    local node_data
    local process_node = require('mdnotes.treesitter')[fdtype] or function(...) return {} end ---@diagnostic disable-line
    local function get_node_data(_node)
        if _node ~= nil then
            node_data = process_node(_node, buf, false)
            if node_data == nil then
                get_node_data(_node:parent())
            end
        end
    end

    local node = vim.treesitter.get_node({
        bufnr = buf,
        ignore_injections = false,
        pos = {lnum - 1, col_start - 1}
    })
    get_node_data(node)

    if node_data == nil then
        return nil
    end

    local delimiter = M.format_delimiters[fdtype]

    local new_text = node_data.raw:sub(#delimiter.ldel + 1, #node_data.raw - #delimiter.rdel)

    vim.api.nvim_buf_set_text(node_data.buf, node_data.lnum - 1, node_data.col_start - 1, node_data.lnum - 1, node_data.col_end - 1, {new_text})

    if move_cursor == true then
        vim.cmd.buffer(node_data.buf)
        vim.fn.cursor({node_data.lnum, vim.fn.col('.') - #delimiter.ldel})
    end
end

---Toggle the emphasis Markdown formatting
---@param fdtype MdnFormatDelimiterType Format delimeter type
---@param opts MdnFormattingOpts?
function M.toggle(fdtype, opts)
    vim.validate("fdtype", fdtype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local ret = check_markdown_syntax(fdtype, { location = opts.location })
    if ret == true then
        M.delete_format(fdtype, opts)
    elseif ret == false then
        M.insert_format(fdtype, opts)
    end
end

---Toggle the emphasis Markdown formatting
---@param opts MdnFormattingOpts?
function M.emphasis_toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    M.toggle("emphasis", opts)
end

---Toggle the strong Markdown formatting
---@param opts MdnFormattingOpts?
function M.strong_toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    M.toggle("strong", opts)
end

---Toggle the strikethrough Markdown formatting
---@param opts MdnFormattingOpts?
function M.strikethrough_toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    M.toggle("strikethrough", opts)
end

---Toggle the inline code Markdown formatting
---@param opts MdnFormattingOpts?
function M.inline_code_toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    M.toggle("inline_code", opts)
end

---Toggle the autolink Markdown formatting
---@param opts MdnFormattingOpts?
function M.autolink_toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    M.toggle("autolink", opts)
end

---Get a consistent table containing all data on a list item
---@param line string Line containing list item
---@return MdnListItemData?
function M.parse_list_item(line)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.parse_list_item_re(line)
    elseif parser == "treesitter" then
        return M.parse_list_item_ts(line)
    end
end

---Get a consistent table containing all data on a list item using Lua patterns
---@param line string Line containing list item
---@return MdnListItemData?
function M.parse_list_item_re(line)
    vim.validate("line", line, "string")

    local mdnotes_patterns = require('mdnotes.patterns')

    local ul_indent, ul_marker, ul_text = line:match(mdnotes_patterns.unordered_list)
    local ol_indent, ol_marker, ol_separator, ol_text = line:match(mdnotes_patterns.ordered_list)

    local indent = (ul_indent or ol_indent) or ""
    local marker = ul_marker or ol_marker or ""
    local separator = ol_separator or ""
    local text = (ul_text or ol_text) or ""

    local type = ""
    if ol_separator == nil then
        type = "unordered"
    else
        type = "ordered"
    end

    if indent == "" and marker == "" and separator == "" and text == "" then
        return nil
    end

    local task_state = ""
    if text:match(mdnotes_patterns.task) then
        task_state = text:match(mdnotes_patterns.task)
        text = text:sub(#task_state + 2, -1)
    end

    return {
        indent = indent,
        marker = marker,
        separator = separator,
        text = text,
        type = type,
        task_state = task_state
    }
end

---Get a consistent table containing all data on a list item using treesitter
---@param line string Line containing list item
---@return MdnListItemData?
function M.parse_list_item_ts(line)
    vim.validate("line", line, "string")

    local node_data
    local process_node = require('mdnotes.treesitter')["list_item"] or function(...) return {} end ---@diagnostic disable-line
    local function get_node_data(_node)
        if _node ~= nil then
            node_data = process_node(_node, line, false)
            if node_data == nil then
                get_node_data(_node:child())
            end
        end
    end

    local parser = vim.treesitter.get_string_parser(line, "markdown")
    local tree = parser:parse()[1]
    local node = tree:root()
    get_node_data(node)

    if node_data == nil then
        -- BUG: Traversing the tree as usual gives error when there is no text in the list item e.g. "1) "
        -- or when the list item is indented. This is a valid node since it appears in InspectTree.
        -- Therefore have a fallback here which uses the Lua patterns implementation.
        node_data = M.parse_list_item_re(line)
        if node_data == nil then
            return
        end
    end

    local indent = line:match("^(%s+).+")
    node_data.indent = indent or ""
    node_data.cur_col = nil

   return node_data
end

---@param ldata MdnListItemData?
---@return string?
function M.get_list_item_string(ldata)
    if ldata == nil then return nil end

    if ldata.task_state ~= "" then
        return ldata.indent .. ldata.marker .. ldata.separator .. " " .. ldata.task_state .. " " .. ldata.text
    else
        return ldata.indent .. ldata.marker .. ldata.separator .. " " .. ldata.text
    end
end

---Toggle task list state
---@param opts {location: MdnMultiLineLocation?, silent: boolean?}?
function M.task_list_toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local silent = opts.silent or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')

    vim.validate("silent", silent, "boolean")
    vim.validate("buf", buf, "number")
    vim.validate("silent", silent, "boolean")
    vim.validate("startl", startl, "number")
    vim.validate("endl", endl, "number")

    local new_lines = {}
    local lines = vim.api.nvim_buf_get_lines(buf, startl - 1, endl, false)

    local cur_col = vim.fn.col('.')
    for i, line in ipairs(lines) do
        local ldata = M.parse_list_item(line) or {}

        if ldata.marker then
            if ldata.task_state == "[x]" then
                ldata.task_state = ""
                cur_col = cur_col - 4
            elseif ldata.task_state == "[ ]" then
                ldata.task_state = "[x]"
            elseif ldata.task_state == "" then
                ldata.task_state = "[ ]"
                cur_col = cur_col + 4
            end

            table.insert(new_lines, M.get_list_item_string(ldata))
        else
            if silent == false then
                vim.notify("Mdn: Unable to detect a list or task list marker at line ".. tostring(startl - 1 + i), vim.log.levels.ERROR)
            end

            return
        end
    end

    vim.api.nvim_buf_set_lines(buf, startl - 1, endl, false, new_lines)

    if cur_col < 1 then cur_col = 1 end

    if #lines == 1 then
        vim.fn.cursor(startl, cur_col)
    end
end

---Check if the list surrounding the origin line is valid and return its line numbers
---@param opts {same_indent: boolean?, same_marker: boolean?, search: MdnSearchOpts?, outliner_list: boolean?}?
---@return MdnSearchResult
function M.check_list_valid(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local search_opts = opts.search or {}
    vim.validate("search_opts", search_opts, "table")

    local buf = search_opts.buf or vim.api.nvim_get_current_buf()
    local origin_lnum = search_opts.origin_lnum or vim.fn.line('.')
    local lower_limit_lnum = search_opts.lower_limit_lnum or 1
    local upper_limit_lnum = search_opts.upper_limit_lnum or vim.fn.line('$')

    local outliner_list = opts.outliner_list or false
    local same_indent = opts.same_indent or false
    local same_marker = opts.same_marker ~= false

    -- Get the origin line's list content
    local origin_line = vim.api.nvim_buf_get_lines(buf, origin_lnum - 1, origin_lnum, false)[1]
    local lcontent = M.parse_list_item(origin_line)
    if lcontent == nil or lcontent.marker == nil or lcontent.separator == nil then
        return { valid = false }
    end

    local list_startl = 0
    local list_endl = 0
    local detected_marker = lcontent.marker
    local detected_separator = lcontent.separator
    local detected_indent = lcontent.indent

    -- If the list should be treated as an outliner list
    if outliner_list == true then
        list_endl = origin_lnum
        for i = origin_lnum, upper_limit_lnum do
            local cur_line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
            lcontent = M.parse_list_item(cur_line)
            if lcontent == nil then break end
            if lcontent.indent == detected_indent and i > origin_lnum then break end
            if lcontent.indent >= detected_indent then
                list_endl = i
            end
        end

        return {
            valid = true,
            buf = buf,
            startl = origin_lnum,
            endl = list_endl,
        }
    end

    -- Find where list starts
    for i = origin_lnum, lower_limit_lnum, -1 do
        local cur_line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
        if cur_line == "" then break end
        vim.print(cur_line)
        lcontent = M.parse_list_item(cur_line)
        if lcontent == nil then break end
        if same_marker == true and lcontent.marker ~= detected_marker and lcontent.separator ~= detected_separator then
            break
        end
        if same_indent == true and lcontent.indent ~= detected_indent  then
            break
        end
        list_startl = i
    end

    -- Find where the list ends
    for i = origin_lnum, upper_limit_lnum do
        local cur_line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
        if cur_line == "" then break end
        lcontent = M.parse_list_item(cur_line)
        if lcontent == nil then break end
        if same_marker == true and lcontent.marker ~= detected_marker and lcontent.separator ~= detected_separator then
            break
        end
        if same_indent == true and lcontent.indent ~= detected_indent  then
            break
        end
        list_endl = i
    end

    if list_startl == 0 and list_endl == 0 then
        return {
            valid = false,
            buf = buf,
            startl = list_startl,
            endl = list_endl,
        }
    end

    return {
        valid = true,
        buf = buf,
        startl = list_startl,
        endl = list_endl,
    }
end

---Renumber the ordered list
---@param opts {silent: boolean?, search: MdnSearchOpts}?
function M.ordered_list_renumber(opts)
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local silent = opts.silent or false
    local search_opts = opts.search or {}
    local origin_lnum = search_opts.origin_lnum or vim.fn.line('.')
    local buf = search_opts.buf or vim.api.nvim_get_current_buf()

    vim.validate("silent", silent, "boolean")

    local lsearch = M.check_list_valid({ search = search_opts, same_marker = false })
    if lsearch.valid == false then
        if silent == false then
            vim.notify("Mdn: Unable to detect a valid list", vim.log.levels.ERROR)
        end
        return
    end

    local line = vim.api.nvim_buf_get_lines(buf, origin_lnum - 1, origin_lnum, false)[1]
    local ldata = M.parse_list_item(line)
    if ldata == nil then
        if silent == false then
            vim.notify("Mdn: Unable to detect a valid list", vim.log.levels.ERROR)
        end
        return
    end

    if ldata.type == "unordered" then
        if silent == false then
            vim.notify("Mdn: Cannot reorder an unordered list", vim.log.levels.ERROR)
        end
        return
    end

    -- Get list
    local list_lines = vim.api.nvim_buf_get_lines(buf, lsearch.startl - 1, lsearch.endl, false)

    local new_list_lines = {}
    local cur_number = 1
    for _, v in ipairs(list_lines) do
        vim.print(v)
        ldata = M.parse_list_item(v)
        if ldata == nil then break end
        if ldata.type == "ordered" then
            if tonumber(ldata.marker) ~= cur_number then
                ldata.marker = tostring(cur_number)
            end
            cur_number = cur_number + 1
        end
        table.insert(new_list_lines, M.get_list_item_string(ldata))
    end

    vim.api.nvim_buf_set_lines(buf, lsearch.startl - 1, lsearch.endl, false, new_list_lines)
end

---Check if there fence block in the specified search range or under the cursor
---@param opts {search: MdnSearchOpts?}?
---@return MdnSearchResult
function M.check_fence_valid(pattern, opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local search_opts = opts.search or {}
    vim.validate("search_opts", search_opts, "table")

    local buf = search_opts.buf or vim.api.nvim_get_current_buf()
    local origin_lnum = search_opts.origin_lnum or vim.fn.line('.')
    local lower_limit_lnum = search_opts.lower_limit_lnum or 1
    local upper_limit_lnum = search_opts.upper_limit_lnum or vim.fn.line('$')

    local fence_startl = 0
    local fence_endl = 0

    -- A file needs more than 2 lines to have a valid fenced code block
    if upper_limit_lnum < 2 then
        return { valid = false }
    end

    for i = origin_lnum, lower_limit_lnum, -1 do
        local cur_line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
        if cur_line:match(pattern) then
            fence_startl = i
            break
        end
    end

    if fence_startl == 0 then
        return { valid = false }
    end

    for i = origin_lnum, upper_limit_lnum do
        local cur_line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
        if cur_line:match(pattern) then
            fence_endl = i
            break
        end
    end

    if fence_endl == 0 then
        return { valid = false }
    end

    if (fence_endl - fence_startl) < 2 then
        return { valid = false }
    end

    return {
        valid = true,
        buf = buf,
        startl = fence_startl,
        endl = fence_endl,
    }
end

---Insert a fence
---@param fence string Fence text
---@param opts {location: MdnMultiLineLocation?}?
function M.insert_fence(fence, opts)
    vim.validate("fence", fence, "string")
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')

    vim.validate("buf", buf, "number")
    vim.validate("startl", startl, "number")
    vim.validate("endl", endl, "number")

    vim.api.nvim_buf_set_lines(buf, endl, endl, false, {fence})
    vim.api.nvim_buf_set_lines(buf, startl - 1, startl - 1, false, {fence})
end

---Delete a fence
---@param opts {location: MdnMultiLineLocation?}?
function M.delete_fence(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')

    vim.validate("buf", buf, "number")
    vim.validate("startl", startl, "number")
    vim.validate("endl", endl, "number")

    vim.api.nvim_buf_set_lines(buf, endl - 1, endl, false, {})
    vim.api.nvim_buf_set_lines(buf, startl - 1, startl, false, {})
end

---Toggle fenced code block
---@param opts {location: MdnMultiLineLocation?}?
function M.fenced_code_block_toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local locopts = opts.location or {}
    local pattern = require('mdnotes.patterns').code_fence
    local fcbvalid = M.check_fence_valid(pattern, {search = {buf = locopts.buf}})
    if fcbvalid.valid == true then
        M.delete_fence({location = {
            buf = fcbvalid.buf,
            startl = fcbvalid.startl,
            endl = fcbvalid.endl,
        }})
    else
        M.insert_fence("```", {location = locopts})
    end

end

return M
