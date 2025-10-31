# Markdown Notes (mdnotes) for Neovim
A plugin to create a great note-taking experience in Neovim.

## Features
- Set your index file and go there with `:Mdn home`.
- Set your journal file and go there with `:Mdn journal`.
- Open Wikilinks (`[[link]]`) with `:Mdn open_wikilink`.
- Toggle hyperlinks with `:Mdn toggle_hyperlink` which pastes your copied hyperlink over the selected text or removes it.
- Show backlinks of your Wikilinks with `:Mdn show_backlinks`.
- Implements an outliner mode by doing `:Mdn toggle_outliner` (make sure to exit afterwards by re-toggling.
- Insert an image or file from clipboard using `:Mdn insert_image` or `:Mdn insert_file` which creates the appropriate link and copies or moves the image to your assets folder.
- Supports Windows eccentricities.

TODO: Mention in the docs that this can be done with LSP vim.lsp.buf.references()
TODO: Talk about LSPs
TODO: Renaming backlinks and the file
TODO: Talk about the link types
TODO: Support # in name open wiki links
TODO: Formatting like bold italic etc.
## Setup

### Recommendations
In your config path have an `after/ftplugin/markdown.lua` file which would have settings specific to Markdown files. In there place the recommended keymaps or any other settings that would enhance the note-taking experience,
```lua
vim.wo.wrap = true -- Enable wrap for current .md window
vim.keymap.set('n', 'gf', ':Mdn open_wikilink<CR>', { desc = "Open markdown file from Wikilink" })
vim.keymap.set({"v", "n"}, '<C-K>', ':Mdn toggle_hyperlink<CR>', { desc = "Toggle hyperlink" })
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
