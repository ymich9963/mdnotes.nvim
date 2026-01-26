---Mdnotes Markdown specific keymaps

local mdnotes = function() return require("mdnotes") end

---Auto-list keymaps
if mdnotes().config.auto_list then
    vim.keymap.set("i", "<CR>", function ()
        return mdnotes().new_line_remap("<CR>", true)
    end,
    {
        expr = true,
        desc = "Mdnotes <CR> remap for auto-lists",
        buffer = true
    })

    vim.keymap.set("n", "o", function ()
        mdnotes().new_line_remap("o")
    end,
    {
        desc = "Mdnotes 'o' remap for auto-lists",
        buffer = true
    })

    vim.keymap.set("n", "O", function ()
        mdnotes().new_line_remap("O")
    end,
    {
        desc = "Mdnotes 'O' remap for auto-lists",
        buffer = true
    })
end

---Default keymaps
if mdnotes().config.default_keymaps then
    vim.keymap.set('n', '<leader>mgx', ':Mdn inline_link open<CR>', { buffer = true, desc = "Open inline link URI under cursor" })
    vim.keymap.set('n', '<leader>mgf', ':Mdn wikilink follow<CR>', { buffer = true, desc = "Open markdown file from WikiLink" })
    vim.keymap.set('n', '<leader>mgrr', ':Mdn wikilink show_references<CR>', { buffer = true, desc = "Show references of link or buffer" })
    vim.keymap.set('n', '<leader>mgrn', ':Mdn wikilink rename_references<CR>', { buffer = true, desc = "Rename references of link or current buffer" })
    vim.keymap.set({"v", "n"}, "<leader>mk", ":Mdn inline_link toggle<CR>", { buffer = true, desc = "Toggle hyperlink" })
    vim.keymap.set("n", "<leader>mh", ":Mdn history go_back<CR>", { buffer = true, desc = "Go to back to previously visited Markdown buffer" })
    vim.keymap.set("n", "<leader>ml", ":Mdn history go_forward<CR>", { buffer = true, desc = "Go to next visited Markdown buffer" })
    vim.keymap.set({"v", "n"}, "<leader>mb", ":Mdn formatting strong_toggle<CR>", { buffer = true, desc = "Toggle strong formatting" })
    vim.keymap.set({"v", "n"}, "<leader>mi", ":Mdn formatting emphasis_toggle<CR>", { buffer = true, desc = "Toggle emphasis formatting" })
    vim.keymap.set({"v", "n"}, "<leader>mt", ":Mdn formatting task_list_toggle<CR>", { buffer = true, desc = "Toggle task list status" })
    vim.keymap.set("n", "<leader>mp", ":Mdn heading previous<CR>", { buffer = true, desc = "Go to previous Markdown heading" })
    vim.keymap.set("n", "<leader>mn", ":Mdn heading next<CR>", { buffer = true, desc = "Go to next Markdown heading" })
end
