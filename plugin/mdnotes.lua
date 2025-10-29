if vim.g.loaded_mdnotes then
    return
end
vim.g.loaded_mdnotes = true

local mdnotes = require('mdnotes')

-- To record buffer changes
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    callback = function(args)
        local bufnr = args.buf
        if mdnotes.current_index == 0 or mdnotes.buf_history[mdnotes.current_index] ~= bufnr then
            table.insert(mdnotes.buf_history, bufnr)
            mdnotes.current_index = #mdnotes.buf_history
        end
    end,
})

local subcommands = {
    home = mdnotes.go_to_index_file,
    journal = mdnotes.go_to_journal_file,
    open_wikilink = mdnotes.open_md_file_wikilink,
    toggle_hyperlink = mdnotes.toggle_hyperlink,
    show_backlinks = mdnotes.show_backlinks,
    toggle_outliner = mdnotes.toggle_outliner,
    insert_image = mdnotes.insert_image,
    insert_file = mdnotes.insert_file,
    go_back = mdnotes.go_back,
    go_forward = mdnotes.go_forward,
}

vim.api.nvim_create_user_command( "Mdn", function(opts)
    local args = vim.split(opts.args, "%s+")
    local subcmd = args[1]

    local func = subcommands[subcmd]
    if func then
        func()
    else
        vim.notify("Unknown subcommand: " .. (subcmd or ""), vim.log.levels.WARN)
    end
end,
{
    nargs = "+",
    complete = function(arg)
        return vim.tbl_filter(function(sub)
            return sub:match("^" .. arg)
        end, vim.tbl_keys(subcommands))
    end,
    desc = "Markdown-notes main command",
    range = true,
})

vim.keymap.set('n', 'gf', ':Mdn open_wikilink<CR>', { desc = "Open markdown file from Wikilink" })
vim.keymap.set({"v", "n"}, '<C-K>', ':Mdn toggle_hyperlink<CR>', { desc = "Toggle hyperlink" })
vim.opt.isfname:remove('[', ']') -- To enable path completion on Windows <C-x> <C-f>
