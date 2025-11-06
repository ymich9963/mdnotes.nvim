# Markdown Notes for Neovim (mdnotes.nvim)
Markdown Notes (mdnotes or Mdn) is a plugin that aims to improve the Neovim Markdown note-taking experience by providing features like better Wikilink support, adding/removing hyperlinks to images/files/URLs, file history, asset management, referencing, backlinks, and formatting. All this without relying on any LSP but using one is recommended.

Please remember to read the docs with `:h mdnotes.txt` or in `doc/mdnotes.txt`. Most important items are detailed here in the README but they are written in more detail in there.

## Features
- Open hyperlinks to files and URLs with `:Mdn open`.
- Set your index file and go there with `:Mdn home`.
- Set your journal file and go there with `:Mdn journal`.
- Open Wikilinks (`[[link]]` or `[[link#Section]])` with `:Mdn open_wikilink`.
- Toggle hyperlinks with `:Mdn toggle_hyperlink` which pastes your copied hyperlink over the selected text or removes it.
- Show backlinks of the current file with `:Mdn show_backlinks` or to show the backlinks of a Wikilink by hovering over the link and executing the same command.
- Implements an outliner mode by doing `:Mdn toggle_outliner` (make sure to exit afterwards by re-toggling.
- Insert an image or file from clipboard using `:Mdn insert_image` or `:Mdn insert_file` which creates the appropriate link and copies or moves the image to your assets folder. Requires `xclip` or `wl-clipboard` for Linux.
- Supports Windows eccentricities.
- Use `:Mdn cleanup_unused_assets` to easily cleanup assets that you no longer use.
- Can go backwards and forwards in notes history by using `:Mdn go_back` and  `:Mdn go_forward`.
- Toggle the appropriate formatting with `:Mdn bold/italic/inline code/strikethrough_toggle`.
- Rename link references and the file itself using `:Mdn rename_link_references`.
- Quickly insert the date using `:Mdn insert_date` (in a customiseable format) when using your journal.

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
{
    index_file = "",
    journal_file = "",
    assets_path = "",
    insert_file_behaviour = "copy", -- "copy" or "move" files when inserting from clipboard
    overwrite_behaviour = "error",  -- "overwrite" or "error" when finding assset file conflicts
    open_behaviour = "buffer",      -- "buffer" or "tab" to open when following links
    date_format = "%a %d %b %Y"     -- date format based on :h strftime()
}
```

### Recommendations
In your config path have an `after/ftplugin/markdown.lua` file which would have settings specific to Markdown files. In there place the recommended keymaps or any other settings that would enhance the note-taking experience,
```lua
    vim.keymap.set("n", "gf", ":Mdn open_wikilink<CR>", { desc = "Open markdown file from Wikilink" })
    vim.keymap.set({"v", "n"}, "<C-K>", ":Mdn hyperlink_toggle<CR>", { desc = "Toggle hyperlink" })
    vim.keymap.set("n", "<Left>", ":Mdn go_back<CR>", { desc = "Go to back to previously visited Markdown buffer" })
    vim.keymap.set("n", "<Right>", ":Mdn go_forward<CR>", { desc = "Go to next visited Markdown buffer" })
    vim.keymap.set({"v", "n"}, "<C-B>", ":Mdn bold_toggle<CR>", { desc = "Toggle bold formatting" })
    vim.keymap.set({"v", "n"}, "<C-I>", ":Mdn italics_toggle<CR>", { desc = "Toggle italics formatting" })
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

## LSPs
The main reason I made this plugin was dissatisfaction with MD LSPs at the time, and I really wanted to use Neovim as my notes editor. Now the plugin has more useful features for me than the editors I used to use, which is nice. It is recommended to use LSPs with the plugin since I'm trying to work with the LSPs and not try to create something from scratch. So far certain LSP features haven't been working for me fully, but I do recommend [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide) and [marksman](https://github.com/artempyanykh/marksman).

## Other Cool Markdown-related Plugins
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- [markdown-plus](https://github.com/yousefhadder/markdown-plus.nvim)
- [markview]( https://github.com/OXY2DEV/markview.nvim)
- [iwe.nvim](https://github.com/iwe-org/iwe.nvim)
- [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim)
