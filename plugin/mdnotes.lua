if vim.g.loaded_mdnotes then
    return
end
vim.g.loaded_mdnotes = true

local mdnotes = require('mdnotes')

local subcommands = {
    home = mdnotes.go_to_index_file,
    open_wikilink = mdnotes.open_md_file_wikilink,
    toggle_hyperlink = mdnotes.toggle_hyperlink,
    show_backlinks = mdnotes.show_backlinks,
    toggle_outliner = mdnotes.toggle_outliner,
    insert_image = mdnotes.insert_image,
    insert_file = mdnotes.insert_file,
}

vim.api.nvim_create_user_command( "Mdn", function(opts)
    local args = vim.split(opts.args, "%s+")
    local subcmd = args[1]

    local func = subcommands[subcmd]
    if func then
        func()
    else
        vim.notify("Unknown subcommand: " .. (subcmd or ""), vim.log.levels.INFO)
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

-- Put them in after/ftplugin/markdown.lua with buffer = true so that the keymaps are markdown only
-- Advise for these keymaps and everything else that might be put into a markdown.lua
vim.keymap.set('n', 'gf', ':Mdn open_wikilink<CR>', { desc = "Open markdown file from Wikilink" })
vim.keymap.set({"v", "n"}, '<C-K>', ':Mdn toggle_hyperlink<CR>', { desc = "Toggle hyperlink" })
