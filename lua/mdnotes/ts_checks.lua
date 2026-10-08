---@module 'mdnotes.ts_checks'

local M = {}

---@param node TSNode
---@param source string|integer Buffer or string from which the node is extracted
---@param type_tbl table<string> Which type to check the node is
---@param node_check_func (fun(n: TSNode, s: string|integer):boolean)? Optional function to do extra checks on the node
local function check(node, source, type_tbl, node_check_func)
    if node == nil then return nil end
    if node_check_func == nil then node_check_func = function() return true end end
    local ntype = node:type()
    if vim.tbl_contains(type_tbl, ntype) and node_check_func(node, source) == true then
        local row_start, col_start, _, col_end = node:range()
        return {
            col_start = col_start + 1,
            col_end = col_end + 1,
            lnum = row_start + 1,
        }
    else
        return nil
    end
end

-- TODO: Could have something like wikilink = {is_element = func(), get_data = func()}
-- to centralise everything as much as possible. Keep current parse lines implementation or have a ts implementation?
-- rename this file to treesitter.lua

---@class MdnTSNodeType
---@field wikilink (fun(node: TSNode, source: string|integer): table?)?
---@field inline_link (fun(node: TSNode, source: string|integer): table?)?
---@field strong (fun(node: TSNode, source: string|integer): table?)?
---@field emphasis (fun(node: TSNode, source: string|integer): table?)?
---@field strikethrough (fun(node: TSNode, source: string|integer): table?)?
---@field inline_code (fun(node: TSNode, source: string|integer): table?)?
---@field autolink (fun(node: TSNode, source: string|integer): table?)?
---@field reference_link (fun(node: TSNode, source: string|integer): table?)?
---@field footnote_reference (fun(node: TSNode, source: string|integer): table?)?
M = {
    wikilink = function(node, source)
        return check(node, source, {"shortcut_link"}, function(n, s)
            if type(s) == "string" then return false end -- s should always be a number

            local row_start, col_start, _, _ = n:range()
            local line = vim.api.nvim_buf_get_lines(s, row_start, row_start + 1, false)[1]
            if line:sub(col_start, col_start) == "[" and line:sub(col_start + 1, col_start + 1) == "[" then
                return true
            else
                return false
            end
        end)
    end,
    inline_link = function(node, source)
        return check(node, source, {"inline_link", "image"})
    end,
    strong = function(node, source)
        return check(node, source, {"strong_emphasis"})
    end,
    emphasis = function(node, source)
        return check(node, source, {"emphasis"})
    end,
    strikethrough = function(node, source)
        return check(node, source, {"strikethrough"})
    end,
    inline_code = function(node, source)
        return check(node, source, {"code_span"})
    end,
    autolink = function(node, source)
        return check(node, source, {"uri_autolink"})
    end,
    reference_link = function(node, source)
        return check(node, source, {"collapsed_reference_link", "full_reference_link"})
    end,
    footnote_reference = function(node, source)
        return check(node, source, {"shortcut_link"}, function(n, s)
            local text = vim.treesitter.get_node_text(n, s)
            if text:sub(2,2) == "^" then
                return true
            else
                return false
            end
        end)
    end,
}

return M
