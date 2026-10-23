---@module 'mdnotes.formatting'

local M = {}

---@class MdnFormattingOpts
---@field location MdnInLineLocation?
---@field move_cursor boolean?

local check_inline_markdown_syntax = function(...) return require('mdnotes').check_inline_markdown_syntax(...) end

local emphasis_delim = function() return require('mdnotes').config.emphasis_format end
local strong_delim = function() return require('mdnotes').config.strong_format end

---@alias MdnFormatDelimiters table<MdnSupportedInlineMEType, {ldel: string, rdel: string}>
M.format_delimiters = {
    strong = {ldel = strong_delim(), rdel = strong_delim()},
    emphasis = {ldel = emphasis_delim(), rdel = emphasis_delim()},
    strikethrough = {ldel = "~", rdel = "~"},
    inline_code = {ldel = "`", rdel = "`"},
    autolink = {ldel = "<", rdel = ">"},
    wikilink = {ldel = "[[", rdel = "]]"},
    inline_link = {ldel = "[", rdel = "]()"},
    reference_link = {ldel = "[", rdel = "][]"},
    footnote_reference = {ldel = "[^", rdel = "]"},
}

---Insert a Markdown format
---@param imetype MdnSupportedInlineMEType Inline Markdown element type
---@param opts MdnFormattingOpts?
function M.insert_format(imetype, opts)
    vim.validate("imetype", imetype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}
    local move_cursor = opts.move_cursor ~= false

    vim.validate("move_cursor", move_cursor, "boolean")

    local txtdata = require('mdnotes').get_text({ location = opts.location })
    if txtdata.raw == nil then
        return
    end

    local delimiter = M.format_delimiters[imetype]

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {delimiter.ldel .. txtdata.raw .. delimiter.rdel})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') + #delimiter.ldel})
    end
end

---Delete the format indicators around a Markdown element
---@param imetype MdnSupportedInlineMEType Inline Markdown element type
---@param opts MdnFormattingOpts?
function M.delete_format(imetype, opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.delete_format_re(imetype, opts)
    elseif parser == "treesitter" then
        return M.delete_format_ts(imetype, opts)
    end
end

---Delete the format indicators around a Markdown element using Lua patterns
---@param imetype MdnSupportedInlineMEType Inline Markdown element type
---@param opts MdnFormattingOpts?
function M.delete_format_re(imetype, opts)
    vim.validate("imetype", imetype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    vim.validate("move_cursor", move_cursor, "boolean")

    local pattern = require('mdnotes.patterns')[imetype]
    local txtdata = require('mdnotes').get_text_in_pattern(pattern, {location = opts.location})
    local delimiter = M.format_delimiters[imetype]

    local new_text = txtdata.raw:sub(#delimiter.ldel + 1, #txtdata.raw - #delimiter.rdel)

    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end - 1, {new_text})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') - #delimiter.ldel})
    end
end

---Delete the format indicators around a Markdown element using treesitter
---@param imetype MdnSupportedInlineMEType Inline Markdown element type
---@param opts MdnFormattingOpts?
function M.delete_format_ts(imetype, opts)
    vim.validate("imetype", imetype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    vim.validate("move_cursor", move_cursor, "boolean")

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')

    local node_data
    local process_node = require('mdnotes.treesitter')[imetype] or function(...) return {} end ---@diagnostic disable-line
    local function get_node_data(_node)
        if _node ~= nil then
            node_data = process_node(_node, buf)
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

    local delimiter = M.format_delimiters[imetype]

    local new_text = node_data.raw:sub(#delimiter.ldel + 1, #node_data.raw - #delimiter.rdel)

    vim.api.nvim_buf_set_text(node_data.buf, node_data.lnum - 1, node_data.col_start - 1, node_data.lnum - 1, node_data.col_end - 1, {new_text})

    if move_cursor == true then
        vim.cmd.buffer(node_data.buf)
        vim.fn.cursor({node_data.lnum, vim.fn.col('.') - #delimiter.ldel})
    end
end

---Toggle the emphasis Markdown formatting
---@param imetype MdnSupportedInlineMEType Inline Markdown element type
---@param opts MdnFormattingOpts?
function M.toggle(imetype, opts)
    vim.validate("imetype", imetype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local ret = check_inline_markdown_syntax(imetype, { location = opts.location })
    if ret == true then
        M.delete_format(imetype, opts)
    elseif ret == false then
        M.insert_format(imetype, opts)
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
