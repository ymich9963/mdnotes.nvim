---@module 'mdnotes.heading'

local M = {}

---Get the Markdown heading that the specified line is under
---Defaults to current buffer and current line
---@param opts {buf: integer?, lnum: integer?, silent: boolean?}?
---@return MdnFragment? fragment
function M.get_heading(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local lnum = opts.lnum or vim.fn.line(".")
    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local silent = opts.silent or false

    local index = 0
    local get_buf_fragments = require('mdnotes').get_buf_fragments

    local fragments = get_buf_fragments({buf = buf})
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

---Go to the specified heading
---@param heading string? Heading to go to
---@param opts {buf: integer?, increment: integer?, picker: boolean?}?
function M.go_to(heading, opts)
    vim.validate("heading", heading, "string", true)
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local increment = opts.increment or 0
    local picker = opts.picker or false

    if heading == nil and picker == true then
        heading = M.picker(function(sel_obj) M.go_to(sel_obj) end, buf)
    end

    local fragments = require('mdnotes').get_buf_fragments({ buf = buf})

    -- Set to "" to not go anywhere
    if heading ~= "" then
        -- Go to heading
        for _, v in ipairs(fragments) do
            if v.text == heading then
                vim.fn.cursor(v.lnum, 1)
                break
            end
        end
    end

    local current_fragment = M.get_heading()
    if not current_fragment then return end

    if increment ~= 0 then
        -- Increment
        local heading_index = 0
        for i, v in ipairs(fragments) do
            if v.text == current_fragment.text then
                heading_index = i
                break
            end
        end

        local new_index = resolve_index(heading_index + increment, #fragments)
        vim.fn.cursor(fragments[new_index].lnum, 1)
        vim.api.nvim_input('zz')
    end
end

---Go to next Markdown heading
function M.next()
    M.go_to("", {increment = 1})
end

---Go to previous Markdown heading
function M.previous()
    M.go_to("", {increment = -1})
end

---Open a picker to select a heading
---@param on_end fun(sel_obj): any Callback function for when the coroutine finishes
---@param buf integer Buffer number
function M.picker(on_end, buf)
    vim.validate("on_end", on_end, "function")
    vim.validate("buf", buf, "number")
    if buf == 0 then buf = vim.api.nvim_get_current_buf() end

    local fragments = require('mdnotes').get_buf_fragments({ buf = buf, only_text = true})
    if fragments == nil then
        vim.notify("Mdn: No headings in current file", vim.log.levels.ERROR)
        return
    end

    local ui_opts = {
        prompt = "Select a heading:",
        format_item = function(item)
            return item
        end,
    }

    return require('mdnotes').mdn_picker(fragments, on_end, ui_opts)
end

return M
