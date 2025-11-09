# 📓 mdnotes.nvim
![Neovim](https://img.shields.io/badge/Built%20for-Neovim-green?logo=neovim&color=%2357A143&link=https%3A%2F%2Fmit-license.org%2F)
![Lua badge](https://img.shields.io/badge/Made%20with-Lua-purple?logo=lua&color=%23000080&link=https%3A%2F%2Flua.org%2F)
![MIT license](https://img.shields.io/badge/License-MIT-blue?link=https%3A%2F%2Fmit-license.org%2F)

**Simple and improved Markdown note taking.**

---


## ☀️ Introduction
Markdown Notes (mdnotes or Mdn) aims to improve the Neovim Markdown note-taking experience by providing features like better Wikilink support, adding/removing hyperlinks to images/files/URLs, file history, asset management, referencing, backlinks, and formatting. All this without relying on any LSP but using one is recommended.

Read the documentation with `:h mdnotes.txt`.

## 🔥 Features

### 🧭 Navigation
- Open hyperlinks to files and URLs with `:Mdn open`.
- Set your index file and go there with `:Mdn home`.
- Set your journal file and go there with `:Mdn journal`.
- Can go backwards and forwards in notes history by using `:Mdn go_back` and  `:Mdn go_forward`.
- Open Wikilinks (`[[link]]` or `[[link#Section]])` with `:Mdn open_wikilink`.

### 💁 Formatting
- Toggle hyperlinks with `:Mdn toggle_hyperlink` which pastes your copied hyperlink over the selected text or removes it.
- Toggle the appropriate formatting with `:Mdn bold/italic/inline_code/strikethrough_toggle`.

### 🖇️ Wikilinks
- Rename link references and the file itself using `:Mdn rename_link_references`.
- Show backlinks of the current file with `:Mdn show_backlinks` or to show the backlinks of a Wikilink by hovering over the link and executing the same command.

### 👩‍💼 Asset Management
- Use `:Mdn cleanup_unused_assets` to easily cleanup assets that you no longer use.
- Use `:Mdn move_unused_assets` to move unused assets to a separate folder.
- Insert an image or file from clipboard using `:Mdn insert_image` or `:Mdn insert_file` which creates the appropriate link and copies or moves the image to your assets folder. Requires `xclip` or `wl-clipboard` for Linux.

### 🧍‍♂️ Uncategorised
- Implements an outliner mode by doing `:Mdn toggle_outliner`. Make sure to exit afterwards by re-toggling.
- Supports Windows eccentricities.

## 👽 Setup
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

### 🌐 Default Config
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

### 💋 Recommendations
I've listed some recommended keymaps and settings below for a great experience with `mdnotes`. They are not applied by default and therefore have to be mapped manually. All suggestions here should ideally be in an `after/ftplugin/markdown.lua` file so that they are specific to Markdown files.

#### ⌨️ Keymaps
Here are some recommended keymaps for `mdnotes`,
```lua
vim.keymap.set('n', 'gf', ':Mdn open_wikilink<CR>', { buffer = true, desc = "Open markdown file from Wikilink" })
vim.keymap.set({"v", "n"}, "<C-K>", ":Mdn hyperlink_toggle<CR>", { buffer = true, desc = "Toggle hyperlink" })
vim.keymap.set("n", "<Left>", ":Mdn go_back<CR>", { buffer = true, desc = "Go to back to previously visited Markdown buffer" })
vim.keymap.set("n", "<Right>", ":Mdn go_forward<CR>", { buffer = true, desc = "Go to next visited Markdown buffer" })
vim.keymap.set({"v", "n"}, "<C-B>", ":Mdn bold_toggle<CR>", { buffer = true, desc = "Toggle bold formatting" })
vim.keymap.set({"v", "n"}, "<C-I>", ":Mdn italic_toggle<CR>", { buffer = true, desc = "Toggle italic formatting" })
```
If you really like outliner mode and want to indent entire blocks then these remaps are very helpful,
```lua
vim.keymap.set("v", "<", "<gv", { buffer = true, desc = "Indent left and reselect" }) -- Better indenting in visual mode
vim.keymap.set("v", ">", ">gv", { buffer = true, desc = "Indent right and reselect" })
```
#### 👩‍💻 Settings
If you are on Windows then setting these options will allow you to use the build in `<C-x> <C-f>` file completion,
```lua
vim.opt.isfname:remove('[') -- To enable path completion on Windows :h i_CTRL-X_CTRL-F
vim.opt.isfname:remove(']')
```
These other two settings are for enabling wrapping only in Markdown files, and to disable the LSP diagnostics if they annoy you.
```lua
vim.wo.wrap = true -- Enable wrap for current .md window
vim.diagnostic.enable(false, { bufnr = 0 }) -- Disable diagnostics for current .md buffer
```

## 🙊 LSPs
The main reason I started this project was dissatisfaction with MD LSPs at the time, and I really wanted to use Neovim as my notes editor. It is recommended to use LSPs with `mdnotes` since I'm trying to work with the LSPs and to not try to create something from scratch. So far certain LSP features haven't been working for me fully, but I do recommend [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide) and [marksman](https://github.com/artempyanykh/marksman).

## 🫰 Other Cool Markdown-related Plugins
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- [markdown-plus](https://github.com/yousefhadder/markdown-plus.nvim)
- [markview]( https://github.com/OXY2DEV/markview.nvim)
- [iwe.nvim](https://github.com/iwe-org/iwe.nvim)
- [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim)
