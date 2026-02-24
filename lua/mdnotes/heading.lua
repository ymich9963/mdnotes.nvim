---@module 'mdnotes.heading'

local M = {}

---Get the Markdown heading that the specified line is under
---Defaults to current buffer and current line
---@param opts {bufnum: integer?, lnum: integer?}?
---@return integer|nil index Index of current heading in the parsed fragments
---@return MdnFragment fragment
---@return integer total_fragments Total fragments in the parsed buffer
function M.get_current_heading(opts)
    opts = opts or {}

    local buf_fragments = require('mdnotes.toc').buf_fragments
    local lnum = opts.lnum or vim.fn.line(".")
    local bufnum = opts.bufnum or vim.api.nvim_get_current_buf()
    local fragment = {hash = "", text = "", lnum = 0}
    local index = 0
    local parsed = nil

    for _, v in ipairs(buf_fragments) do
        if v.buf_num == bufnum then
            parsed = v.parsed
            break
        end
    end

    if parsed == nil then
        vim.notify("Mdn: Buffer not parsed", vim.log.levels.ERROR)
        return nil, fragment, 0
    end

    local total_fragments = #parsed.fragments

    for j, vv in ipairs(parsed.fragments) do
        -- Once the header entry's lnum is more than the current
        -- it means we have to subtract 1 to get the current heading
        if vv.lnum > lnum then
            fragment = parsed.fragments[j - 1]
            index = j - 1
            break
        end
    end

    -- If there is no next heading, do this to get the last one
    if index == 0 then
        fragment = parsed.fragments[total_fragments]
        index = total_fragments
    end

    return index, fragment, total_fragments
end

---Resolve any index issues 
---@param index integer
---@param total integer
---@return integer index
local function resolve_index(index, total)
    if index < 1 then return total end
    if index > total then return 1 end
    return index
end

---Go to next Markdown heading
function M.goto_next()
    local buf_fragments = require('mdnotes.toc').buf_fragments
    local cur_buf_num = vim.api.nvim_get_current_buf()
    local index, _, total_fragments = M.get_current_heading()
    if not index then return end

    for _, v in ipairs(buf_fragments) do
        if v.buf_num == cur_buf_num then
            vim.fn.cursor(vim.fn.search(v.parsed.fragments[resolve_index(index + 1, total_fragments)].text), 1)
            vim.api.nvim_input('zz')
            break
        end
    end
end

---Go to previous Markdown heading
function M.goto_previous()
    local buf_fragments = require('mdnotes.toc').buf_fragments
    local cur_buf_num = vim.api.nvim_get_current_buf()
    local index, _, total_fragments = M.get_current_heading()
    if not index then return end

    for _, v in ipairs(buf_fragments) do
        if v.buf_num == cur_buf_num then
            vim.fn.cursor(vim.fn.search(v.parsed.fragments[resolve_index(index - 1, total_fragments)].text), 1)
            vim.api.nvim_input('zz')
            break
        end
    end
end

return M
