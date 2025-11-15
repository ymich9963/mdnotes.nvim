# 📓 mdnotes.nvim
![Neovim](https://img.shields.io/badge/Built%20for-Neovim-green?logo=neovim&color=%2357A143&link=https%3A%2F%2Fmit-license.org%2F)
![Lua badge](https://img.shields.io/badge/Made%20with-Lua-purple?logo=lua&color=%23000080&link=https%3A%2F%2Flua.org%2F)
![MIT license](https://img.shields.io/badge/License-MIT-blue?link=https%3A%2F%2Fmit-license.org%2F)

**Simple and improved Markdown note taking.**

---

## ☀️ Introduction
Markdown Notes (mdnotes or Mdn) aims to improve the Neovim Markdown note-taking experience by providing features like better Wikilink support, adding/removing hyperlinks to images/files/URLs, sequential Markdown buffer history, asset management, referencing, ordered/unordered/task lists, and formatting. All this without relying on any LSP but using one is recommended.

All documentation is available with `:h mdnotes.txt`.

## 🔥 Features
All the features of `mdnotes` and their associated commands are listed and categorised below.

### 🧭 Navigation
- Open hyperlinks to files and URLs with `:Mdn open`.
- Set your index and journal files and go there with `:Mdn home` and `:Mdn journal`.
- Can go backwards and forwards in notes history by using `:Mdn go_back` and  `:Mdn go_forward`.
- Open Wikilinks (`[[link]]` or `[[link#Section]])` with `:Mdn open_wikilink`.

### 💁 Formatting
- Toggle hyperlinks with `:Mdn toggle_hyperlink` which pastes your copied hyperlink over the selected text or removes it.
- Toggle the appropriate formatting with `:Mdn bold/italic/inline_code/strikethrough_toggle`.
- Automatically continue your ordered/unordered/task lists (can be disabled). Works with `<CR>`, `o`, and `O`.
- Toggle through checked, unchecked, and no checkbox in a list item with `:Mdn task_list_toggle`. Also works with linewise visual mode.

### 🖇️ Wikilinks
- Rename link references and the file itself using `:Mdn rename_link_references`.
- Rename references to current buffer and also the file of the current buffer with `:Mdn rename_references_cur_buf`.
- Show the references of a Wikilink by hovering over the link and executing `:Mdn show_references`. Also show references of the current buffer when not hovering over a Wikilink.

### 👩‍💼 Asset Management
- Use `:Mdn cleanup_unused_assets` to easily cleanup assets that you no longer use.
- Use `:Mdn move_unused_assets` to move unused assets to a separate folder.
- Insert an image or file from clipboard using `:Mdn insert_image` or `:Mdn insert_file` which creates the appropriate link and copies or moves the image to your assets folder. Requires `xclip` or `wl-clipboard` for Linux.

### 🧍‍♂️ Uncategorised
- Implements an outliner mode by doing `:Mdn toggle_outliner`. Make sure to exit afterwards by re-toggling.
- Insert a journal entry automatically by doing `:Mdn insert_journal_entry`. 
- Opt-out use of existing Markdown LSP functions.
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
    prefer_lsp = true,              -- to prefer LSP functions than the mdnotes functions
    auto_list = true,               -- automatic list continuation
    default_keymaps = false,
    default_settings = false,
    os_windows_settings = false,    -- for path completion using the builtin <C-X><C-F> on Windows
}
```

## 💋 Recommendations
I've listed some recommended keymaps and settings below for a great experience with `mdnotes`. All suggestions here should ideally be in an `after/ftplugin/markdown.lua` file - like in `mdnotes` - so that they are specific to Markdown files.

### ⌨️ Keymaps
 The keymappings below can be enabled by setting `default_keymaps = true` as they are not enabled by default.
 ```lua
vim.keymap.set('n', 'gf', ':Mdn open_wikilink<CR>', { buffer = true, desc = "Open markdown file from Wikilink" })
vim.keymap.set({"v", "n"}, "<C-K>", ":Mdn hyperlink_toggle<CR>", { buffer = true, desc = "Toggle hyperlink" })
vim.keymap.set("n", "<Left>", ":Mdn go_back<CR>", { buffer = true, desc = "Go to back to previously visited Markdown buffer" })
vim.keymap.set("n", "<Right>", ":Mdn go_forward<CR>", { buffer = true, desc = "Go to next visited Markdown buffer" })
vim.keymap.set({"v", "n"}, "<C-B>", ":Mdn bold_toggle<CR>", { buffer = true, desc = "Toggle bold formatting" })
vim.keymap.set({"v", "n"}, "<C-I>", ":Mdn italic_toggle<CR>", { buffer = true, desc = "Toggle italic formatting" })
```
### 👩‍💻 Settings
These other two settings are for enabling wrapping only in Markdown files, and to disable the LSP diagnostics if they annoy you. They can be enabled by setting `default_settings = true`.
```lua
vim.wo[vim.api.nvim_get_current_win()][0].wrap = true -- Enable wrap for current .md buffer
vim.diagnostic.enable(false, { bufnr = 0 }) -- Disable diagnostics for current .md buffer
```
If you are on Windows then setting these options will allow you to use the build in `<C-x> <C-f>` file completion for Wikilinks. They can be enabled by setting `os_windows_settings = true` and it is only possible and necessary for Windows.
```lua
vim.opt.isfname:remove('[') -- To enable path completion on Windows :h i_CTRL-X_CTRL-F
vim.opt.isfname:remove(']')
```

## 🙊 LSPs
The main reason I started this project was dissatisfaction with MD LSPs at the time, and I really wanted to use Neovim as my notes editor. It is recommended to use LSPs with `mdnotes` since I'm trying to work with the LSPs and to not try to create something from scratch. So far certain LSP features haven't been working for me fully, but I do recommend [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide) and [marksman](https://github.com/artempyanykh/marksman).

## 🫰 Other Cool Markdown-related Plugins
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- [markdown-plus](https://github.com/yousefhadder/markdown-plus.nvim)
- [markview]( https://github.com/OXY2DEV/markview.nvim)
- [iwe.nvim](https://github.com/iwe-org/iwe.nvim)
- [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim)
