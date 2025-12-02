# 📓 mdnotes.nvim
![Neovim](https://img.shields.io/badge/Built%20for-Neovim-green?logo=neovim&color=%2357A143&link=https%3A%2F%2Fmit-license.org%2F)
![Lua badge](https://img.shields.io/badge/Made%20with-Lua-purple?logo=lua&color=%23000080&link=https%3A%2F%2Flua.org%2F)
![MIT license](https://img.shields.io/badge/License-MIT-blue?link=https%3A%2F%2Fmit-license.org%2F)

**Simple and improved Markdown note taking.**

---

## ☀️ Introduction
Markdown Notes (mdnotes or Mdn) aims to improve the Neovim Markdown note-taking experience by providing features like better WikiLink support, adding/removing hyperlinks to images/files/URLs, sequential Markdown buffer history, asset management, referencing, ordered/unordered/task lists, generating ToC, and formatting.

Please see the [Features](#-features) below for a descriptive list of features and their commands. Also see the [Recommendations](#-recommendations) section for the recommended `mdnotes` setup, and the [Supported Markdown Format](#-supported-markdown-formatting) section to see how `mdnotes` aims to format your notes. If you are migrating from another note-taking application, then [MIGRATING.md](MIGRATING.md) might be of interest to you.

All documentation is available with `:h mdnotes.txt`.

## 🔥 Features
All the features of `mdnotes` and their associated commands are listed and categorised below.

### 🧭 Navigation
- Open hyperlinks to files and URLs with `:Mdn open`.
- Set your index and journal files and go there with `:Mdn home` and `:Mdn journal`.
- Can go backwards and forwards in notes history by using `:Mdn history_go_back` and  `:Mdn history_go_forward`.
- Open WikiLinks (`[[link]]` or `[[link#Section]])` with `:Mdn wikilink_follow`.

### 💁 Formatting
- Toggle hyperlinks with `:Mdn hyperlink_toggle` which pastes your copied hyperlink over the selected text or removes it.
- Toggle the appropriate formatting with `:Mdn bold/italic/inline_code/strikethrough_toggle`.
- Automatically continue your ordered/unordered/task lists. Works with `<CR>`, `o`, and `O` and can be disabled.
- Toggle through checked, unchecked, and no checkbox in a list item with `:Mdn task_list_toggle`. Also works with linewise visual mode to toggle multiple tasks at a time.

### 🫦 Tables
- Create a `ROW` by `COLS` table with `:Mdn table_create ROW COLS`.
- Set the best fit of your columns with `:Mdn table_best_fit` so that all your cells line up. Can also add padding around your cells.
- Insert columns to the left or right of your current column with `:Mdn table_column_insert_left/right`.

### 🖇️ WikiLinks
- Rename link references and the file itself using `:Mdn wikilink_rename_references`. Also rename references of the current buffer when not hovering over a Wikilink.
- Show the references of a Wikilink by hovering over the link and executing `:Mdn wikilink_show_references`. Also show references of the current buffer when not hovering over a Wikilink.
- Undo the most recent reference rename with `:Mdn wikilink_undo_rename`. **Only** available when `prefer_lsp = false`.

### 👩‍💼 Asset Management
- Use `:Mdn assets_cleanup_unused` to easily cleanup assets that you no longer use.
- Use `:Mdn assets_move_unused` to move unused assets to a separate folder.
- Insert an image or file from clipboard using `:Mdn insert_image` or `:Mdn insert_file` which creates the appropriate link and copies or moves the image to your assets folder. Requires `xclip` or `wl-clipboard` for Linux.

### 🧍‍♂️ Uncategorised
- Generate and insert at the cursor a Table Of Contents (ToC) for the current Markdown buffer with `:Mdn toc_generate`.
- Implements an outliner mode by doing `:Mdn outliner_toggle`. Make sure to exit afterwards by re-toggling.
- Insert a journal entry automatically by doing `:Mdn journal_insert_entry`. 
- Opt-out use of existing Markdown LSP functions.
- Supports Windows eccentricities.

## 👽 Setup
Using the lazy.nvim package manager,
```lua
{
    "ymich9963/mdnotes.nvim",
}
```

and specify your config using `opts = {}`, no `setup({})` function needed,
```lua
{
    "ymich9963/mdnotes.nvim",
    opts = {
        -- Config here
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
    prefer_lsp = false,             -- to prefer LSP functions than the mdnotes functions
    auto_list = true,               -- automatic list continuation
    default_keymaps = false,
	table_best_fit_padding = 0,     -- add padding around cell contents when using tables_best_fit
}
```
### 📂 Directory Setup
Sample directory structure for `mdnotes` is shown below. If this directory configuration doesn't suit you please make an issue and hopefully I'll be able to work around it,
```
notes/
├───assets/
│   ├───fire.png
│   └───water.pdf
├───music.md
├───electronics.md
etc.
```

## 💋 Recommendations
I've specified below some recommended plugins, keymaps, and optional settings for a great experience with `mdnotes`.

### 🔌 Plugins
For the best Neovim Markdown note-taking experience, I've listed some other projects to optionally install alongside `mdnotes`,
- [markview.nvim](https://github.com/OXY2DEV/markview.nvim) - Excellent viewing of Markdown files without any external preview.
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Tree-sitter for Neovim; with this also install the `markdown`, `markdown_inline`, and `latex` parsers.
- Live Previewer,
    - [markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim) - Older, more widely used, has dependencies.
    - [live-preview.nvim](https://github.com/brianhuster/live-preview.nvim) - Newer, no dependencies.
- LSP - Please see the [Using LSPs Section](#--using-lsps) for more information regarding LSPs, but I recommend,
    - [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide) or
    - [marksman](https://github.com/artempyanykh/marksman)


### ⌨️ Keymaps
 The keymappings below can be enabled by setting `default_keymaps = true` as they are not enabled by default, and they will only be available in Markdown buffers. Place any `mdnotes` keymaps in a  `<Neovim config path>/after/ftplugin/markdown.lua` file so that they're also Markdown specific. For organisation they use the `<leader>m` prefix.
 ```lua
vim.keymap.set('n', '<leader>mgx', ':Mdn open<CR>', { buffer = true, desc = "Open URL or file under cursor" })
vim.keymap.set('n', '<leader>mgf', ':Mdn wikilink_follow<CR>', { buffer = true, desc = "Open markdown file from WikiLink" })
vim.keymap.set('n', '<leader>mgrr', ':Mdn wikilink_show_references<CR>', { buffer = true, desc = "Show references of link or buffer" })
vim.keymap.set('n', '<leader>mgrn', ':Mdn wikilink_rename_references<CR>', { buffer = true, desc = "Rename references of link or current buffer" })
vim.keymap.set({"v", "n"}, "<leader>mk", ":Mdn hyperlink_toggle<CR>", { buffer = true, desc = "Toggle hyperlink" })
vim.keymap.set("n", "<leader>mh", ":Mdn history_go_back<CR>", { buffer = true, desc = "Go to back to previously visited Markdown buffer" })
vim.keymap.set("n", "<leader>ml", ":Mdn history_go_forward<CR>", { buffer = true, desc = "Go to next visited Markdown buffer" })
vim.keymap.set({"v", "n"}, "<leader>mb", ":Mdn bold_toggle<CR>", { buffer = true, desc = "Toggle bold formatting" })
vim.keymap.set({"v", "n"}, "<leader>mi", ":Mdn italic_toggle<CR>", { buffer = true, desc = "Toggle italic formatting" })
```
### 👩‍💻 Optional Settings
Place these settings in your `<Neovim config path>/after/ftplugin/markdown.lua` file so that they are Markdown-specific. First one here is to enable wrapping only for the current Markdown buffer. 
```lua
vim.wo[vim.api.nvim_get_current_win()][0].wrap = true -- Enable wrap for current .md buffer
```
Second one is to disable LSP diagnostics in the current Markdown buffer.
```lua
vim.diagnostic.enable(false, { bufnr = 0 }) -- Disable diagnostics for current .md buffer
```
Last one here is for the glorious Neovim Windows users. Setting this keymap will allow you to use the built in `<C-x> <C-f>` file completion for WikiLinks or just for using file paths in Markdown buffers.
```lua
    vim.keymap.set("i", "<C-x><C-f>", "<cmd>set isfname-=[,]<CR><C-x><C-f><cmd>set isfname+=[,]<CR>",
    {
        desc = "Mdnotes i_CTRL-X_CTRL-F smart remap to allow path completion on Windows",
        buffer = true
    })
```

## 🙊  Using LSPs
The main reason I started this project was dissatisfaction with Markdown LSPs at the time, and I really wanted to use Neovim as my notes editor. Therefore, `mdnotes` is designed to work with Markdown LSPs by trying to fill the gaps and to also complement their current functionality. Please see the table below for how `mdnotes` tries to work with LSPs and Neovim itself.

|Feature                         |mdnotes                              |LSP                                                        |Neovim                                                                 |
|--------------------------------|-------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------|
|Showing references              |Y (`:Mdn show_references`)           |Y (`:h vim.lsp.buf.references()` or `grr`)                 |N                                                                      |
|Rename links to current buffer  |Y (`:Mdn rename_references`)         |Y (`:h vim.lsp.buf.rename()` or `grn`, markdown-oxide only)|N                                                                      |
|Rename links to hovered WikiLink|Y (`:Mdn rename_references`)         |? (`:h vim.lsp.buf.rename()`, should work but it does not) |N                                                                      |
|Buffer History                  |Y (Sequential `:Mdn go_back/forward`)|N                                                          |Y (Not Sequential `:h bp`/`:h bn`                                      |
|Path Completion                 |N                                    |Y (`:h lsp-completion`)                                    |Y (`:h i_CTRL-X_CTRL-F`)                                               |
|Opening WikiLinks               |Y (`:Mdn open_wikilink`)             |Y (`:h vim.lsp.buf.definition()` or `CTRL-]`)              |Y (`:h gf`, needs .md extension in link, requires settings for Windows)|
|Markdown Formatting             |Y (`:Mdn <format>_toggle`)           |N                                                          |N                                                                      |
 
 **Note:** Not all of the features of `mdnotes` are listed in this table, just the ones that are relevant to this section. Some LSPs provide more than just LSP features and their documentation should also be referenced along with this table.

## 📢 Supported Markdown Formatting
Here is the supported Markdown formatting for `mdnotes.nvim`. The plugin tries to adhere to the [CommonMark](https://spec.commonmark.org/) and [GitHub Flavoured Markdown (GFM)](https://github.github.com/gfm/) spec as well as providing WikiLink support. If any problems arise please don't hesitate to create an issue for it!
### Links
Opened with `:Mdn open`. Inserted with the `:Mdn insert_file/image` and `:Mdn hyperlink_toggle` commands. If no extension is given to `file` below, it is treated as `.md`.
```
    [link](www.neovim.io)
    [link](path/to/file#section)
    [link](path/to/file#gfm-style-section-wth-spaces)
    [link](<path/to/file with spaces.md#section>)
    [link](#Original Section)
    [link](#original-section)
    [link](path/to/file.extension)
    ![image](path/to/image.extension)
```
### WikiLinks
Opened with `:Mdn open_wikilink`. Can only be filenames, so `link` can also be `link.md`.
```
    [[link]]
    [[link#section]]
```
### Formatting
Toggled with `:Mdn <format>_toggle`. Using `_` for the bold and italic formats needs to be specified in the `bold_format` and `italic_format` config options. 
```
    **bold**
    __bold__
    *italic*
    _italic_
    ~~strikethrough~~
    `inline code`
```
### Lists
All ordered and unordered CommonMark lists along with GFM task lists are supported.
```
    - Item
    + Item
    * Item
    1) Item
    2. Item
    - [x] Task lists with all ordered and unordered lists above
```
### Tables
The GFM table specification is supported.
```
|1r1c|1r2c|1r3c|
|----|----|----|
|2r1c|2r2c|2r3c|
|3r1c|3r2c|3r3c|
```

## 🫂 Motivation
I wanted to make a more Neovim-centric Markdown notes plugin that tries to work the available Markdown LSPs, is command/subcommand focused, concise, adheres to the [CommonMark](https://spec.commonmark.org/) and [GFM](https://github.github.com/gfm/) specs, while also providing the more widespread [WikiLink](https://github.com/Python-Markdown/markdown/blob/master/docs/extensions/wikilinks.md) support other note-taking apps provide. I hope I did in fact accomplish this for you as well as for me and if I have not then please create an issue! Thanks for reading this :).

## 🫰 Other Cool Markdown-related Plugins
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- [markdown-plus](https://github.com/yousefhadder/markdown-plus.nvim)
- [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim)
 
