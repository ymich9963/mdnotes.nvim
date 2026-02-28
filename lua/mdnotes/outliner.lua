---@module 'mdnotes.outliner'

local M = {}

---@type boolean
M.outliner_state = false

local config_autolist = function() return require('mdnotes').config.auto_list_continuation end

---Toggling the Outliner mode
function  M.toggle()
    local mdnotes = require('mdnotes')

    if M.outliner_state == true then
        M.outliner_state = false
        mdnotes.config.auto_list_continuation = config_autolist()

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

--TODO: Add location opts
---Indent the current parent-child list
function M.indent()
    local lsearch = require('mdnotes.formatting').check_list_valid({ outliner_list = true })
    local lines = vim.api.nvim_buf_get_lines(0, lsearch.startl - 1, lsearch.endl, false) or {}
    local cur_lnum = vim.fn.line('.') - 1
    local new_lines = {}

    for _, line in ipairs(lines) do
        table.insert(new_lines, (" "):rep(vim.o.shiftwidth) .. line)
    end

    vim.api.nvim_buf_set_lines(0, cur_lnum, cur_lnum + #new_lines, false, new_lines)

    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), vim.fn.col('.') + vim.o.shiftwidth - 1})
end

--TODO: Add location opts
---Unindent the current parent-child list
function M.unindent()
    local lsearch = require('mdnotes.formatting').check_list_valid({ outliner_list = true })
    local lines = vim.api.nvim_buf_get_lines(0, lsearch.startl - 1, lsearch.endl, false) or {}
    local cur_lnum = vim.fn.line('.') - 1
    local new_lines = {}

    for _, line in ipairs(lines or {}) do
        -- Prevent unindenting when there's no indent
        if line:sub(1,vim.o.shiftwidth) ~= (" "):rep(vim.o.shiftwidth) then return end
        table.insert(new_lines, line:sub(vim.o.shiftwidth + 1))
    end

    vim.api.nvim_buf_set_lines(0, cur_lnum, cur_lnum + #new_lines, false, new_lines)

    -- If indenting from a column close to the start
    local new_col = vim.fn.col('.') - vim.o.shiftwidth - 1
    if new_col < 1 then new_col = 1 end
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), new_col})
end

return M
