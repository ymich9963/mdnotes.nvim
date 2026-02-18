---@module 'mdnotes.outliner'
local M = {}

---@type boolean
M.outliner_state = false

local config_autolist = require('mdnotes').config.auto_list_continuation

---Toggling the Outliner mode
function  M.toggle()
    local mdnotes = require('mdnotes')

    if M.outliner_state == true then
        M.outliner_state = false
        mdnotes.config.auto_list_continuation = config_autolist

        vim.api.nvim_buf_del_keymap(0 ,'i', '<TAB>')
        vim.api.nvim_buf_del_keymap(0 ,'i', '<S-TAB>')
        vim.notify("Mdn: Exited Mdnotes Outliner Mode", vim.log.levels.INFO)
    elseif M.outliner_state == false then
        M.outliner_state = true
        mdnotes.config.auto_list_continuation = true

        vim.keymap.set('i', '<TAB>', '<cmd>Mdn outliner indent<CR>', { buffer = true })
        vim.keymap.set('i', '<S-TAB>', '<cmd>Mdn outliner unindent<CR>', { buffer = true })
        vim.keymap.set("i", "<CR>", function ()
            return mdnotes.new_line_remap("<CR>", true)
        end,
        {
            expr = true,
            desc = "Mdnotes <CR> remap for auto-lists",
            buffer = true
        })
        vim.api.nvim_put({"-  "}, "l", false, false)
        vim.api.nvim_win_set_cursor(0, {vim.fn.line('.') ,3})
        vim.cmd.startinsert()
    end
end

---Get the indent level of the current line
---@param line string? Optional line string
---@return integer
function M.get_indent(line)
    if line == nil then line = vim.api.nvim_get_current_line() end

    local indent, _, _ = require('mdnotes.formatting').resolve_list_content(line)

    local _, indent_lvl = indent:gsub("%s", "")

    return indent_lvl or 0
end

---Get the items of the list under the cursor
function M.get_cur_list_items()
    local buf_lines = vim.api.nvim_buf_get_lines(0, vim.fn.line('.') - 1, -1, false)
    local line_indent_lvl = M.get_indent()
    local list_lines = {}

    for i, line in ipairs(buf_lines) do
        local cur_indent_lvl = M.get_indent(line)
        if cur_indent_lvl == line_indent_lvl and i > 1 then break end
        if cur_indent_lvl >= line_indent_lvl then
            table.insert(list_lines, line)
        end
    end

    return list_lines
end

---Indent the current parent-child list
function M.indent()
    local lines = M.get_cur_list_items()
    local cur_lnum = vim.fn.line('.') - 1
    local cur_col = vim.fn.col('.')
    local new_lines = {}

    for _, line in ipairs(lines or {}) do
        table.insert(new_lines, (" "):rep(vim.o.shiftwidth) .. line)
    end

    vim.api.nvim_buf_set_lines(0, cur_lnum, cur_lnum + #new_lines, false, new_lines)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), cur_col + vim.o.shiftwidth - 1})
end

---Unindent the current parent-child list
function M.unindent()
    local lines = M.get_cur_list_items()
    local cur_lnum = vim.fn.line('.') - 1
    local cur_col = vim.fn.col('.')
    local new_lines = {}

    for _, line in ipairs(lines or {}) do
        -- Prevent unindenting when there's no indent
        if line:sub(1,vim.o.shiftwidth) ~= (" "):rep(vim.o.shiftwidth) then return end
        table.insert(new_lines, line:sub(vim.o.shiftwidth + 1))
    end

    -- If indenting from a column close to the start
    local new_col = cur_col - vim.o.shiftwidth - 1
    if new_col < 1 then new_col = 1 end

    vim.api.nvim_buf_set_lines(0, cur_lnum, cur_lnum + #new_lines, false, new_lines)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), new_col})
end

return M
