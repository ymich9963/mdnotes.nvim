---@module "mdnotes.list"

local M = {}

---@class MdnListItemData
---@field indent string Indent of list item
---@field marker string List item marker
---@field separator string List item separator, only in ordered lists
---@field text string List item text
---@field type '"ordered"'|'"unordered"'
---@field task_state string Task state string

---New line remaps
---@param key '"o"'|'"O"'|'"<CR>"'
---@return string?
function M.new_line_remap(key, inc_val)
    vim.validate("key", key, "string")

    local lnum = vim.fn.line('.')
    local line = vim.api.nvim_get_current_line()
    local ldata = M.parse_list_item(line)

    -- If no list item detected then use keys normally
    if ldata == nil then
        if key == "o" or key == "O" then
            vim.api.nvim_feedkeys(key, "n", true)
        elseif key == "<CR>" then
            return "\n"
        end

        return
    end

    local new_ldata = vim.deepcopy(ldata, true)
    if ldata.type == "unordered" then
        new_ldata.text = ""
    elseif ldata.type == "ordered" then
        new_ldata.text = ""
        new_ldata.marker = tostring(tonumber(ldata.marker) + inc_val)
    else
        return ""
    end

    local new_item = M.get_list_item_string(new_ldata)

    if key == "o" then
        vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { new_item })
        vim.fn.cursor({ lnum + 1, #new_item + 1 })
    elseif key == "O" then
        vim.api.nvim_buf_set_lines(0, lnum - 1, lnum - 1, false, { new_item })
        vim.fn.cursor({ lnum, #new_item + 1 })
    elseif key == "<CR>" then
        if ldata.text == "" then
            vim.api.nvim_input("<ESC>S")

            return
        end

        return "\n" .. new_item
    else
        return nil
    end

    vim.api.nvim_input('a')
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
            node_data = process_node(_node, line)
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

return M
