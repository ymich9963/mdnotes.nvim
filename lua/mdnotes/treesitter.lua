---@module 'mdnotes.treesitter'

local M = {}

---@param node TSNode
---@param source string|integer Buffer or string from which the node is extracted
---@param type_tbl table<string> Which type to check the node is
---@param get_data_func (fun(...):table) Function to get the data from the node. Different for each element
---@param is_node_type_func (fun(n: TSNode, s: string|integer):boolean) Optional function to do extra checks on the node
---@param location "'inline'"|"'multiline'"? Return the inline or multiline location. Leave nil for no location
---@return table?
local function process_node(node, source, type_tbl, get_data_func, is_node_type_func, location)
    if node == nil then return nil end

    local ntype = node:type()
    if vim.tbl_contains(type_tbl, ntype) and is_node_type_func(node, source) == true then
        local row_start, col_start, row_end, col_end = node:range()
        if location == "inline" then
            return {
                col_start = col_start + 1,
                col_end = col_end + 1,
                lnum = row_start + 1,
            }
        elseif location == "multiline" then
            return {
                startl = row_start + 1,
                endl = row_end,
            }
        end

        local data = get_data_func(node, source)
        if type(source) == "number" then
            data.buf = source
        end
        data.cur_col = math.floor((col_start + 1 + col_end + 1) / 2)

        return data
    else
        return nil
    end
end

local function ret_true()
    return true
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return boolean
local function is_wikilink(n, s)
    local row_start, col_start, _, _ = n:range()
    local text = ""
    if type(s) == "string" then
        text = s
    elseif type(s) == "number" then
        text = vim.api.nvim_buf_get_lines(s, row_start, row_start + 1, false)[1]
    end

    if text:sub(col_start, col_start) == "[" and text:sub(col_start + 1, col_start + 1) == "[" then
        return true
    else
        return false
    end
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return boolean
local function is_fref(n, s)
    local isfref = false
    local ntext = vim.treesitter.get_node_text(n, s)
    if ntext:sub(2,2) == "^" then
        isfref = true
    end

    local text = ""
    local row_start, col_start, _, col_end = n:range()
    if type(s) == "string" then
        text = s
    elseif type(s) == "number" then
        text = vim.api.nvim_buf_get_lines(s, row_start, row_start + 1, false)[1]
    end

    if col_start == 0 and text:sub(col_end + 1, col_end + 1) == ":" then
        isfref = false
    end

    return isfref
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnInlineLinkData
local function get_il_data(n, s)
    local img_char = ""
    if n:type() == "image" then
        img_char = "!"
    end

    local raw = vim.treesitter.get_node_text(n, s)
    local row_start, col_start, _, col_end = n:range()

    local text, destination, title = "", "", ""
    for child in n:iter_children() do
        local type = child:type()
        if type == "link_text" or type  == "image_description" then
            text = vim.treesitter.get_node_text(child, s)
        elseif type == "link_destination" then
            destination = vim.treesitter.get_node_text(child, s)
        end
        if type == "link_title" then
            title = vim.treesitter.get_node_text(child, s)
        end
    end

    return {
        raw = raw,
        text = text,
        destination = destination,
        title = title,
        img_char = img_char,
        lnum = row_start + 1,
        col_start = col_start + 1,
        col_end = col_end + 1,
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnFootnoteReferenceData
local function get_fref_data(n, s)
    local raw = vim.treesitter.get_node_text(n, s)
    local row_start, col_start, _, col_end = n:range()

    local identifier = ""
    for child in n:iter_children() do
        local type = child:type()
        if type == "link_text" then
            identifier = vim.treesitter.get_node_text(child, s)
            identifier = identifier:sub(2, -1) -- remove ^ character
        end
    end

    return {
        raw = raw,
        identifier = identifier,
        lnum = row_start + 1,
        col_start = col_start + 1,
        col_end = col_end + 1,
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnText
local function get_fd_data(n, s)
    local raw = vim.treesitter.get_node_text(n, s)
    local row_start, col_start, _, col_end = n:range()

    return {
        raw = raw,
        lnum = row_start + 1,
        col_start = col_start + 1,
        col_end = col_end + 1,
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnListItemData
local function get_list_item_data(n, s)
    local marker, separator, text, list_type, task_state = "", "", "", "", ""
    for child in n:iter_children() do
        local type = child:type()
        if type == "list_marker_plus"
            or type == "list_marker_minus"
            or type == "list_marker_star" then
            marker = vim.treesitter.get_node_text(child, s):sub(-2, -2)
            list_type = "unordered"
        elseif type == "list_marker_dot"
            or type == "list_marker_parenthesis" then
            separator = vim.treesitter.get_node_text(child, s):sub(-2, -2)
            marker = vim.treesitter.get_node_text(child, s):sub(1, -3)
            list_type = "ordered"
        elseif type == "paragraph" then
            text = vim.treesitter.get_node_text(child, s)
        elseif type == "task_list_marker_checked" or type == "task_list_marker_unchecked" then
            task_state = vim.treesitter.get_node_text(child, s)
        end
    end

    return {
        marker = marker,
        separator = separator,
        text = text,
        type = list_type,
        task_state = task_state
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnReferenceLinkData
local function get_rl_data(n, s)
    local raw = vim.treesitter.get_node_text(n, s)
    local row_start, col_start, _, col_end = n:range()

    local text, label = "", ""
    for child in n:iter_children() do
        local type = child:type()
        if type == "link_text" then
            text = vim.treesitter.get_node_text(child, s)
        elseif type == "link_label" then
            label = vim.treesitter.get_node_text(child, s):sub(2,-2)
        end
    end

    if label == "" then
        label = text
    end

    return {
        raw = raw,
        text = text,
        label = label,
        lnum = row_start + 1,
        col_start = col_start + 1,
        col_end = col_end + 1,
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnWikiLinkData
local function get_wl_data(n, s)
    local row_start, col_start, _, col_end = n:range()

    local text = ""
    for child in n:iter_children() do
        local type = child:type()
        if type == "link_text" then
            text = vim.treesitter.get_node_text(child, s)
        end
    end

    if type(s) == "string" then
        text = s
    elseif type(s) == "number" then
        text = vim.api.nvim_buf_get_lines(s, row_start, row_start + 1, false)[1]
    end

    local raw = text:sub(col_start, col_end + 1)

    local fragment_start, _ = raw:find("#", 1, true)
    local alias_start, _ = raw:find("|", 1, true)

    local file = raw:sub(3, (fragment_start or -2) - 1)

    local fragment = ""
    if fragment_start ~= nil then
        fragment = raw:sub(fragment_start + 1, (alias_start or 0) - 1)
    end

    local alias = ""
    if alias_start ~= nil then
        alias = raw:sub(alias_start + 1, -3)
    end

    return {
        raw = raw,
        file = file,
        fragment = fragment,
        alias = alias,
        lnum = row_start + 1,
        col_start = col_start,
        col_end = col_end + 2,
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnTable
local function get_table_data(n, s)
    local row_start, _, row_end, _ = n:range()

    local contents = {}
    for child in n:iter_children() do
        local type = child:type()
        if type == "pipe_table_header" then
            local header = {}
            for c in child:iter_children() do
                local ctype = c:type()
                if ctype == "pipe_table_cell" then
                    table.insert(header, vim.treesitter.get_node_text(c, s))
                end
            end
            table.insert(contents, 1, header)
        end

        if type == "pipe_table_delimiter_row" then
            local delimiter = {}
            for c in child:iter_children() do
                local ctype = c:type()
                if ctype == "pipe_table_delimiter_cell" then
                    table.insert(delimiter, vim.treesitter.get_node_text(c, s))
                end
            end
            table.insert(contents, 2, delimiter)
        end

        if type == "pipe_table_row" then
            local row = {}
            for c in child:iter_children() do
                local ctype = c:type()
                if ctype == "pipe_table_cell" then
                    table.insert(row, vim.treesitter.get_node_text(c, s))
                end
            end
            table.insert(contents, row)
        end
    end

    return {
        contents = contents,
        startl = row_start + 1,
        endl = row_end,
        buf = s
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnFragment
local function get_atx_headings(n, s)
    local row_start, _, _, _ = n:range()
    local atx_heading = vim.treesitter.get_node_text(n, s)
    local hash_end = atx_heading:find("%s")
    local hash = atx_heading:sub(1, hash_end - 1)
    local text = atx_heading:sub(hash_end + 1, -2)
    local convert_text_to_gfm = require('mdnotes').convert_text_to_gfm

    return {
        hash = hash,
        text = text,
        lnum = row_start + 1,
        gfm = convert_text_to_gfm(text)
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnReferenceLinkDefinition
local function get_rldef_data(n, s)
    local row_start, _, _, _ = n:range()
    local label, destination = "", ""
    for child in n:iter_children() do
        local type = child:type()
        if type == "link_label" then
            label = vim.treesitter.get_node_text(child, s):sub(2,-2)
        elseif type == "link_destination" then
            destination = vim.treesitter.get_node_text(child, s)
        end
    end

    return {
        label = string.lower(label),
        destination = destination,
        lnum = row_start + 1,
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return MdnReferenceLinkDefinition
local function get_fn_data(n, s)
    local row_start, _, _, col_end = n:range()

    local identifier = ""
    for child in n:iter_children() do
        local type = child:type()
        if type == "link_text" then
            identifier = vim.treesitter.get_node_text(child, s)
            identifier = identifier:sub(2, -1) -- remove ^ character
        end
    end

    local line
    if type(s) == "string" then
    elseif type(s) == "number" then
        line = vim.api.nvim_buf_get_lines(s, row_start, row_start + 1, false)[1]
    end

    local text = line:sub(col_end, -1):match("%s(.+)")

    return {
        identifier = identifier,
        text = text,
        lnum = row_start + 1,
    }
end

---@param n TSNode
---@param s string|integer Buffer or string from which the node is extracted
---@return boolean
local function is_fn(n, s)
    local text = ""
    local row_start, col_start, _, col_end = n:range()
    if type(s) == "string" then
        text = s
    elseif type(s) == "number" then
        text = vim.api.nvim_buf_get_lines(s, row_start, row_start + 1, false)[1]
    end

    local isfn = false
    local ntext = vim.treesitter.get_node_text(n, s)
    if col_start == 0 and text:sub(col_end + 1, col_end + 1) == ":" and ntext:sub(2,2) == "^" then
        isfn = true
    end

    return isfn
end

---Supported Markdown Treesitter types
---@alias MdnSupportedTSType MdnSupportedInlineMEType | '"list_item"' | '"table"' | '"fragments"' | '"reference_link_definition"'

---@alias MdnTSNodeFunc (fun(node: TSNode, source: string|integer, location: "'inline'"|"'multiline'"?): table?)?

---@alias MdnTSNodeType table<MdnSupportedTSType, MdnTSNodeFunc>
M = {
    wikilink = function(node, source, location)
        return process_node(node, source, {"shortcut_link"}, get_wl_data, is_wikilink, location)
    end,
    inline_link = function(node, source, location)
        return process_node(node, source, {"inline_link", "image"}, get_il_data, ret_true, location)
    end,
    strong = function(node, source, location)
        return process_node(node, source, {"strong_emphasis"}, get_fd_data, ret_true, location)
    end,
    emphasis = function(node, source, location)
        return process_node(node, source, {"emphasis"}, get_fd_data, ret_true, location)
    end,
    strikethrough = function(node, source, location)
        return process_node(node, source, {"strikethrough"}, get_fd_data, ret_true, location)
    end,
    inline_code = function(node, source, location)
        return process_node(node, source, {"code_span"}, get_fd_data, ret_true, location)
    end,
    autolink = function(node, source, location)
        return process_node(node, source, {"uri_autolink"}, get_fd_data, ret_true, location)
    end,
    reference_link = function(node, source, location)
        return process_node(node, source, {"collapsed_reference_link", "full_reference_link"}, get_rl_data, ret_true, location)
    end,
    footnote_reference = function(node, source, location)
        return process_node(node, source, {"shortcut_link"}, get_fref_data, is_fref, location)
    end,
    list_item = function(node, source, location)
        return process_node(node, source, {"list_item"}, get_list_item_data, ret_true, location)
    end,
    table = function(node, source, location)
        return process_node(node, source, {"pipe_table"}, get_table_data, ret_true, location)
    end,
    fragments = function(node, source, location)
        return process_node(node, source, {"atx_heading"}, get_atx_headings, ret_true, location)
    end,
    reference_link_definition = function(node, source, location)
        return process_node(node, source, {"link_reference_definition"}, get_rldef_data, ret_true, location)
    end,
    footnote = function(node, source, location)
        return process_node(node, source, {"shortcut_link"}, get_fn_data, is_fn, location)
    end,
}

return M
