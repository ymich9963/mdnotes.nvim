local mdnotes = require("mdnotes")

if mdnotes.config.auto_list then
    vim.keymap.set("i", "<CR>", function ()
        local _, list_remap = mdnotes.list_remap(1)
        return list_remap
    end,
    {
        expr = true,
        desc = "Mdnotes <CR> remap for auto-lists",
        buffer = true
    })

    vim.keymap.set("n", "o", function ()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local indent, list_remap = mdnotes.list_remap(1)
        list_remap = list_remap:gsub("[\n]","")

        if not indent then
            indent = ""
        end

        vim.api.nvim_buf_set_lines(0, row, row, false, { indent .. list_remap })
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
        local indent, list_remap = mdnotes.list_remap(-1)
        list_remap = list_remap:gsub("[\n]","")

        if not indent then
            indent = ""
        end

        vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { indent .. list_remap })
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
