---@module 'mdnotes.treesitter'

local M = {}

---@param node TSNode
---@param source string|integer Buffer or string from which the node is extracted
---@param type_tbl table<string> Which type to check the node is
---@param get_data_func (fun(...):table) Function to get the data from the node. Different for each element
---@param location_only boolean Return only location data and skip the parsing
---@param is_node_type_func (fun(n: TSNode, s: string|integer):boolean)? Optional function to do extra checks on the node
---@return table?
local function process_node(node, source, type_tbl, get_data_func, location_only, is_node_type_func)
    if node == nil then return nil end
    if is_node_type_func == nil then is_node_type_func = function() return true end end

    local ntype = node:type()
    if vim.tbl_contains(type_tbl, ntype) and is_node_type_func(node, source) == true then
        local row_start, col_start, _, col_end = node:range()
        if location_only == true then
            return {
                col_start = col_start + 1,
                col_end = col_end + 1,
                lnum = row_start + 1,
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
        end
        if type == "link_destination" then
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
            identifier = identifier:sub(2, -1) -- remove ^ characte
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

---@alias MdnTSNodeFunc (fun(node: TSNode, source: string|integer, location_only: boolean): table?)?

---@class MdnTSNodeType
---@field wikilink MdnTSNodeFunc
---@field inline_link MdnTSNodeFunc
---@field strong MdnTSNodeFunc
---@field emphasis MdnTSNodeFunc
---@field strikethrough MdnTSNodeFunc
---@field inline_code MdnTSNodeFunc
---@field autolink MdnTSNodeFunc
---@field reference_link MdnTSNodeFunc
---@field footnote_reference MdnTSNodeFunc
M = {
    wikilink = function(node, source, location_only)
        return process_node(node, source, {"shortcut_link"}, get_il_data, location_only, is_wikilink)
    end,
    inline_link = function(node, source, location_only)
        return process_node(node, source, {"inline_link", "image"}, get_il_data, location_only)
    end,
    strong = function(node, source, location_only)
        return process_node(node, source, {"strong_emphasis"}, get_il_data, location_only)
    end,
    emphasis = function(node, source, location_only)
        return process_node(node, source, {"emphasis"}, get_il_data, location_only)
    end,
    strikethrough = function(node, source, location_only)
        return process_node(node, source, {"strikethrough"}, get_il_data, location_only)
    end,
    inline_code = function(node, source, location_only)
        return process_node(node, source, {"code_span"}, get_il_data, location_only)
    end,
    autolink = function(node, source, location_only)
        return process_node(node, source, {"uri_autolink"}, get_il_data, location_only)
    end,
    reference_link = function(node, source, location_only)
        return process_node(node, source, {"collapsed_reference_link", "full_reference_link"}, get_il_data, location_only)
    end,
    footnote_reference = function(node, source, location_only)
        return process_node(node, source, {"shortcut_link"}, get_fref_data, location_only, is_fref)
    end,
}

return M
