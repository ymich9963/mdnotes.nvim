local M = {}

local outliner_state = false
function  M.toggle()
    if outliner_state then
        vim.api.nvim_buf_del_keymap(0 ,'i', '<CR>')
        vim.api.nvim_buf_del_keymap(0 ,'i', '<TAB>')
        vim.api.nvim_buf_del_keymap(0 ,'i', '<S-TAB>')
        vim.notify("Mdn: Exited Mdnotes Outliner Mode.", vim.log.levels.INFO)
        outliner_state = false
    elseif not outliner_state then
        vim.api.nvim_input("<ESC>0i-  <ESC>")
        vim.keymap.set('i', '<CR>', '<CR>- ', { buffer = true })
        vim.keymap.set('i', '<TAB>', '<C-t>', { buffer = true })
        vim.keymap.set('i', '<S-TAB>', '<C-d>', { buffer = true })
        vim.notify("Mdn: Entered Mdnotes Outliner Mode.", vim.log.levels.INFO)
        outliner_state = true
    end
end

return M
