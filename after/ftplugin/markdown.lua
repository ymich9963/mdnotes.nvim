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

