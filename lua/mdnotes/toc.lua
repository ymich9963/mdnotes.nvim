---@module 'mdnotes.toc'

local M = {}

---Generate Table of Contents (ToC)
---@param opts {
    ---buffer: integer?,
    ---lnum: integer?,
    ---write: boolean?,
    ---depth: integer?,
    ---silent: boolean?}?
---@return table<string>|nil toc
function M.generate(opts)
    opts = opts or {}
    local buffer = opts.buffer or vim.api.nvim_get_current_buf()
    local lnum = opts.lnum or vim.fn.line('.')
    local depth = opts.depth or require('mdnotes').config.toc_depth
    local write = opts.write ~= false
    local silent = opts.silent or false

    vim.validate("depth", depth, "number")
    vim.validate("write", write, "boolean")
    vim.validate("silent", silent, "boolean")

    if vim.bo.filetype ~= "markdown" then
        if silent == false then
            vim.notify("Mdn: Cannot generate a ToC for a non-Markdown file", vim.log.levels.ERROR)
        end

        return nil
    end

    local toc = {}
    local fragments = {}
    local gfm_fragments = {}
    local found = false
    local buf_fragments = require('mdnotes').buf_fragments

    for _, v in ipairs(buf_fragments) do
        if v.buf_num == buffer then
            fragments = v.parsed.fragments
            gfm_fragments = v.parsed.gfm
            found = true
        end
    end

    if found == false then
        if silent == false then
            vim.notify("Mdn: Parsed fragments for buffer '" .. buffer .. "' not found", vim.log.levels.ERROR)
        end

        return nil
    end

    for i = 1, #fragments do
        local hash_count = select(2, fragments[i].hash:gsub("#", ""))
        if hash_count <= tonumber(depth) then
            local spaces = string.rep(" ", vim.o.shiftwidth * (hash_count - 1), "")
            table.insert(toc, ("%s- [%s](#%s)"):format(spaces, fragments[i].text, gfm_fragments[i]))
        end
    end

    if write == true then
        vim.api.nvim_buf_set_lines(buffer, lnum - 1, lnum, false, toc)
    end

    return toc
end

return M
