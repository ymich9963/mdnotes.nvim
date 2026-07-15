---@module 'mdnotes.heading'

local M = {}

---Get the Markdown heading that the specified line is under
---Defaults to current buffer and current line
---@param opts {buf: integer?, lnum: integer?, silent: boolean?}?
---@return MdnFragment? fragment
function M.get_heading(opts)
    opts = opts or {}

    local lnum = opts.lnum or vim.fn.line(".")
    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local silent = opts.silent or false

    local index = 0
    local buf_fragments = require('mdnotes').buf_fragments

    local fragments
    for _, v in ipairs(buf_fragments) do
        if v.buf == buf then
            fragments = v.fragments
            break
        end
    end

    if fragments == nil then
        if silent == false then
            vim.notify("Mdn: Buffer not parsed", vim.log.levels.ERROR)
        end

        return
    end

    local fragment
    for j, vv in ipairs(fragments) do
        -- Once the header entry's lnum is more than the current
        -- it means we have to subtract 1 to get the current heading
        if vv.lnum > lnum then
            fragment = fragments[j - 1]
            index = j - 1
            break
        end
    end

    -- If there is no next heading, do this to get the last one
    if index == 0 then
        fragment = fragments[#fragments]
        index = #fragments
    end

    return fragment
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

---Increment an amount of headings to move to from the current heading
---@param increment number Amount to increment
function M.move_to(increment)
    vim.validate("increment", increment, "number")

    local buf_fragments = require('mdnotes').buf_fragments
    local cur_buf = vim.api.nvim_get_current_buf()
    local fragment = M.get_heading()
    if not fragment then return end

    local fragments
    for _, v in ipairs(buf_fragments) do
        if v.buf == cur_buf then
            fragments = v.fragments
            break
        end
    end

    for i, v in ipairs(fragments) do
        if v.text == fragment.text then
            local new_index = resolve_index(i + increment, #fragments)
            local search = vim.fn.search(fragments[new_index].text)
            vim.fn.cursor(search, 1)
            vim.api.nvim_input('zz')
            return
        end
    end
end

---Go to next Markdown heading
function M.goto_next()
    M.move_to(1)
end

---Go to previous Markdown heading
function M.goto_previous()
    M.move_to(-1)
end

return M
