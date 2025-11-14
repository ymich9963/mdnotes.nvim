local mdnotes = require("mdnotes")

if mdnotes.config.auto_list then
    vim.keymap.set("i", "<CR>", function ()
        return mdnotes.list_remap(1)
    end,
    {
        expr = true,
        desc = "Mdnotes <CR> remap for auto-lists",
        buffer = true
    })

    vim.keymap.set("n", "o", function ()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local list_remap = mdnotes.list_remap(1):gsub("[\n]","")

        vim.api.nvim_buf_set_lines(0, row, row, false, { list_remap })
        vim.api.nvim_win_set_cursor(0, { row + 1, 0 })

        if list_remap == "" then
            vim.cmd.startinsert()
        else
            vim.api.nvim_input("$i ")
        end
    end,
    {
        desc = "Mdnotes 'o' remap for auto-lists",
        buffer = true
    })

    vim.keymap.set("n", "O", function ()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local list_remap = mdnotes.list_remap(-1):gsub("[\n]","")

        vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { list_remap })
        vim.api.nvim_win_set_cursor(0, { row, 0 })

        if list_remap == "" then
            vim.cmd.startinsert()
        else
            vim.api.nvim_input("$i ")
        end
    end,
    {
        desc = "Mdnotes 'O' remap for auto-lists",
        buffer = true
    })
end

if mdnotes.config.default_keymaps then
    vim.keymap.set('n', 'gf', ':Mdn open_wikilink<CR>', { buffer = true, desc = "Open markdown file from Wikilink" })
    vim.keymap.set({"v", "n"}, "<C-K>", ":Mdn hyperlink_toggle<CR>", { buffer = true, desc = "Toggle hyperlink" })
    vim.keymap.set("n", "<Left>", ":Mdn go_back<CR>", { buffer = true, desc = "Go to back to previously visited Markdown buffer" })
    vim.keymap.set("n", "<Right>", ":Mdn go_forward<CR>", { buffer = true, desc = "Go to next visited Markdown buffer" })
    vim.keymap.set({"v", "n"}, "<C-B>", ":Mdn bold_toggle<CR>", { buffer = true, desc = "Toggle bold formatting" })
    vim.keymap.set({"v", "n"}, "<C-I>", ":Mdn italic_toggle<CR>", { buffer = true, desc = "Toggle italic formatting" })
end

if mdnotes.config.default_settings then
    vim.wo[vim.api.nvim_get_current_win()][0].wrap = true -- Enable wrap for current .md buffer
    vim.diagnostic.enable(false, { bufnr = 0 }) -- Disable diagnostics for current .md buffer
end

if mdnotes.config.os_windows_settings and vim.fn.has("win32") then
    vim.opt.isfname:remove('[') -- To enable path completion on Windows :h i_CTRL-X_CTRL-F
    vim.opt.isfname:remove(']')
end
