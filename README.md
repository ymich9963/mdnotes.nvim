# Markdown Notes for Neovim (mdnotes.nvim) for Neovim
A plugin to create a great note-taking experience in Neovim.

## Features
- Set your index file and go there with `:Mdn home`.
- Set your journal file and go there with `:Mdn journal`.
- Open Wikilinks (`[[link]]` or `[[link#Section]])` with `:Mdn open_wikilink`.
- Toggle hyperlinks with `:Mdn toggle_hyperlink` which pastes your copied hyperlink over the selected text or removes it.
- Show backlinks of your Wikilinks with `:Mdn show_backlinks`.
- Implements an outliner mode by doing `:Mdn toggle_outliner` (make sure to exit afterwards by re-toggling.
- Insert an image or file from clipboard using `:Mdn insert_image` or `:Mdn insert_file` which creates the appropriate link and copies or moves the image to your assets folder.
- Supports Windows eccentricities.
- Use `:Mdn cleanup_unused_assets` to easily cleanup assets that you no longer use.
- Can go backwards and forwards in notes history by using `:Mdn go_back` and  `:Mdn go_forward`.
- Toggle the appropriate formatting with `:Mdn bold/italic/inline code/strikethrough_toggle`.
- Rename link references and the file itself using `:Mdn rename_link_references`.

## Setup
```lua
{
    "ymich9963/mdnotes.nvim",
    opts = {
        assets_path = "assets",     -- your assets path for assets related commands
        index_file = "MAIN.md",     -- your index file for :Mdn home
        journal_file = "JOURNAL.md",-- your journal file for :Mdn journal
    }
}
```

### Default Config
```lua
local default_config = {
    index_file = "",
    journal_file = "",
    assets_path = "",
    insert_file_behaviour = "copy", -- "copy" or "move" files when inserting from clipboard
    overwrite_behaviour = "error",  -- "overwrite" or "error" when finding assset file conflicts
    open_behaviour = "buffer",      -- "buffer" or "tab" to open when following links
}
```

### Recommendations
In your config path have an `after/ftplugin/markdown.lua` file which would have settings specific to Markdown files. In there place the recommended keymaps or any other settings that would enhance the note-taking experience,
```lua
vim.wo.wrap = true -- Enable wrap for current .md window
vim.keymap.set('n', 'gf', ':Mdn open_wikilink<CR>', { desc = "Open markdown file from Wikilink" })
vim.keymap.set({"v", "n"}, '<C-K>', ':Mdn hyperlink_toggle<CR>', { desc = "Toggle hyperlink" })
```
If you really like outliner mode and want to indent entire blocks then these remaps are very helpful,
```lua
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" }) -- Better indenting in visual mode
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })
```
If you are on Windows then setting this option will allow you to use the build in `<C-x> <C-f>` file completion,
```lua
vim.opt.isfname:remove('[', ']') -- To enable path completion on Windows <C-x> <C-f>
```
For the journal, it might be useful to insert the date with a custom command like this,
```lua
vim.api.nvim_create_user_command('InsertDate',
function()
    vim.cmd([[put =strftime('%a %d %b %Y')]])
end,
{ desc = 'Insert date' })
```

## LSPs
The main reason I made this plugin was dissatisfaction with MD LSPs at the time, and I really wanted to use Neovim as my notes editor. Now the plugin has more useful features for me than the editors I used to use, which is nice. It is recommended to use LSPs with the plugin since I'm trying to work with the LSPs and not try to create something from scratch. So far certain LSP features haven't been working for me fully, but I do recommend,

- [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide)

- [marksman](https://github.com/artempyanykh/marksman)

The plugin will hopefully be updated with these LSPs in mind as I also continue to use it. Some LSP functions that currently work is showing backlinks with `grn` or `vim.lsp.buf.references()`. Some functinalities that might not work is using the H1 headers for links instead of the MD file name.
