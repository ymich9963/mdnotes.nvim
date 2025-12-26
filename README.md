# 📓 mdnotes.nvim
![Neovim](https://img.shields.io/badge/Built%20for-Neovim-green?logo=neovim&color=%2357A143&link=https%3A%2F%2Fmit-license.org%2F)
![Lua badge](https://img.shields.io/badge/Made%20with-Lua-purple?logo=lua&color=%23000080&link=https%3A%2F%2Flua.org%2F)
![MIT license](https://img.shields.io/badge/License-MIT-blue?link=https%3A%2F%2Fmit-license.org%2F)

**Simple and improved Markdown note taking.**

---

## ☀️ Introduction

Mdnotes aims to be a lightweight plugin that improves the Neovim Markdown note-taking experience with minimal configuration required. It does so by providing features like better WikiLink support, adding/removing inline links to images/files/URLs, sequential Markdown buffer history, asset management, referencing, ordered/unordered/task lists, generating ToC, table helpers, and formatting.

Please see the [Features](#-features) below for a descriptive list of features and their commands. Also see the [Recommendations](#-recommendations) section for the recommended `mdnotes` setup, and the [Supported Markdown Format](#-supported-markdown-formatting) section to see how `mdnotes` aims to format your notes. If you are migrating from another note-taking application, then [MIGRATING.md](MIGRATING.md) might be of interest to you. I've also written some useful tips for when writing notes in Neovim using built-in features, see [TIPS.md](TIPS.md).

All documentation is available with `:h mdnotes.txt`.

## 🔥 Features
All the features of `mdnotes` and their associated commands are listed and categorised below.

### 🧭 General Navigation
- Open inline links to files and URLs with `:Mdn open`.
- Set your index and journal files and go there with `:Mdn home` and `:Mdn journal`.
- Can go backwards and forwards in notes history by using `:Mdn history go_back` and  `:Mdn history go_forward`.
- Use `:Mdn heading next/previous` to easily navigate headings. 

### 💁 Formatting
- Toggle the appropriate formatting with `:Mdn formatting bold/italic/inline_code/strikethrough_toggle`.
- Automatically continue your ordered/unordered/task lists. Works with `<CR>`, `o`, and `O` and can be disabled.
- Automatically renumber your ordered lists (`auto_list_renumber = true` by default, can also be done manually).
- Toggle through checked, unchecked, and no checkbox in a list item with `:Mdn formatting task_list_toggle`. Also works with linewise visual mode to toggle multiple tasks at a time.
 
### 🔗 Inline Links
- Toggle inline links with `:Mdn inline_link toggle` which pastes your copied text over the selected text or word under cursor. This command also removes the inline link and saves it to be used later with the same command.
- Rename the link text with `:Mdn inline_link rename`. 
- Re-link the inline link with `:Mdn inline_link relink`. 
- Normalize an inline link with `:Mdn inline_link normalize` to have consistent paths. 

### 🫦 Tables
- See the [Editing Tables](#editing-tables) section for how `mdnotes` integrates with Neovim to edit tables.
- Create a `ROW` by `COLS` table with `:Mdn table create ROW COLS`.
- Automatting setting of the best fit of your columns so that all your cells line up (opt-out). Can also be done manually with `:Mdn table best_fit` and can also add padding around your cells (`table_best_fit_padding` in config).
- Insert columns to the left or right of your current column with `:Mdn table column_insert_left/right`.
- Move columns to the left or right of your current column with `:Mdn table column_move_left/right`.
- Delete current column with `:Mdn table column_delete`.
- Duplicate current column with `:Mdn table column_duplicate`.
- Toggle column alignment with `:Mdn table column_alignment_toggle`.
- Insert rows to the above or below of your current line with `:Mdn table row_insert_above/below`.

### 🖇️ WikiLinks
- Create a WikiLink by highlighting or hovering over a word and executing `:Mdn wikilink create`.
- Open WikiLinks with `:Mdn wikilink follow`.
- Rename link references and the file itself using `:Mdn wikilink rename_references`. Also rename references of the current buffer when not hovering over a Wikilink.
- Show the references of a Wikilink by hovering over the link and executing `:Mdn wikilink show_references`. Also show references of the current buffer when not hovering over a Wikilink.
- Undo the most recent reference rename with `:Mdn wikilink undo_rename`. **Only** available when `prefer_lsp = false`.

### 👩‍💼 Asset Management
- Use `:Mdn assets cleanup_unused` to easily cleanup assets that you no longer use.
- Use `:Mdn assets move_unused` to move unused assets to a separate folder.
- Insert an image or file from clipboard using `:Mdn assets insert_image` or `:Mdn assets insert_file` which creates the appropriate link and copies or moves the image to your assets folder. Requires `xclip` or `wl-clipboard` for Linux.
- Open your assets folder using `:Mdn assets open_containing_folder`. 

### 🧍‍♂️ Uncategorised
- Generate and insert at the cursor a Table Of Contents (ToC) for the current Markdown buffer with `:Mdn toc generate`. Can also customise the depth of the ToC.
- Implements an outliner mode by doing `:Mdn outliner_toggle`. Make sure to exit afterwards by re-toggling.
- Insert a journal entry automatically by doing `:Mdn journal insert_entry`. 
- Tips for repeating last command, find/replace words, finding tags, and finding files, can be found in [TIPS.md](TIPS.md).
- Opt-out use of existing Markdown LSP functions.
- Supports Windows eccentricities.

## 👽 Setup
Using the lazy.nvim package manager,
```lua
{
    "ymich9963/mdnotes.nvim",
}
```

and specify your config using `opts = {}` or with a `setup({})` function,
```lua
{
    "ymich9963/mdnotes.nvim",
    opts = {
        -- Config here
    }
    -- or
    config = {
        require("mdnotes.config").setup({
            -- Config here
        })
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
    open_behaviour = "buffer",      -- "buffer", "tab", "split", or "vsplit" to open when following links
    date_format = "%a %d %b %Y"     -- date format based on :h strftime()
    prefer_lsp = false,             -- to prefer LSP functions than the mdnotes functions
    auto_list = true,               -- automatic list continuation
    auto_list_renumber = true,      -- automatic renumbering of ordered lists
	auto_table_best_fit = true,     -- automatic table best fit
    default_keymaps = false,
	table_best_fit_padding = 0,     -- add padding around cell contents when using tables_best_fit
    toc_depth = 4                   -- depth shown in the ToC
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
vim.keymap.set('n', '<leader>mgf', ':Mdn wikilink follow<CR>', { buffer = true, desc = "Open markdown file from WikiLink" })
vim.keymap.set('n', '<leader>mgrr', ':Mdn wikilink show_references<CR>', { buffer = true, desc = "Show references of link or buffer" })
vim.keymap.set('n', '<leader>mgrn', ':Mdn wikilink rename_references<CR>', { buffer = true, desc = "Rename references of link or current buffer" })
vim.keymap.set({"v", "n"}, "<leader>mk", ":Mdn inline_link toggle<CR>", { buffer = true, desc = "Toggle inline link" })
vim.keymap.set("n", "<leader>mh", ":Mdn history go_back<CR>", { buffer = true, desc = "Go to back to previously visited Markdown buffer" })
vim.keymap.set("n", "<leader>ml", ":Mdn history go_forward<CR>", { buffer = true, desc = "Go to next visited Markdown buffer" })
vim.keymap.set({"v", "n"}, "<leader>mb", ":Mdn formatting bold_toggle<CR>", { buffer = true, desc = "Toggle bold formatting" })
vim.keymap.set({"v", "n"}, "<leader>mi", ":Mdn formatting italic_toggle<CR>", { buffer = true, desc = "Toggle italic formatting" })
vim.keymap.set("n", "<leader>mp", ":Mdn heading previous<CR>", { buffer = true, desc = "Go to previous Markdown heading" })
vim.keymap.set("n", "<leader>mn", ":Mdn heading next<CR>", { buffer = true, desc = "Go to next Markdown heading" })
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
The main reason I started this project was dissatisfaction with Markdown LSPs at the time, and I really wanted to use Neovim as my notes editor. Therefore, `mdnotes` is designed to work with Markdown LSPs by trying to fill the gaps and to also complement their current functionality. Unfortunately, I don't think the Markdown LSPs are there yet, so the default behaviour of the plugin is to have `prefer_lsp = false`. Please see the table below for how `mdnotes` tries to work with LSPs and Neovim itself.

|Feature                         |mdnotes                              |LSP                                                        |Neovim                                                                 |
|--------------------------------|-------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------|
|Showing references              |Y (`:Mdn wikilink show_references`)           |Y (`:h vim.lsp.buf.references()` or `grr`)                 |N                                                                      |
|Rename links to current buffer  |Y (`:Mdn wikilink rename_references`)         |Y (`:h vim.lsp.buf.rename()` or `grn`, markdown-oxide only)|N                                                                      |
|Rename links to hovered WikiLink|Y (`:Mdn wikilink rename_references`)         |? (`:h vim.lsp.buf.rename()`, should work but it does not) |N                                                                      |
|Buffer History                  |Y (Sequential `:Mdn history go_back/forward`)|N                                                          |Y (Not Sequential `:h bp`/`:h bn`                                      |
|Path Completion                 |N                                    |Y (`:h lsp-completion`)                                    |Y (`:h i_CTRL-X_CTRL-F`)                                               |
|Opening WikiLinks               |Y (`:Mdn wikilink follow`)             |Y (`:h vim.lsp.buf.definition()` or `CTRL-]`)              |Y (`:h gf`, needs .md extension in link, requires settings for Windows)|
 
 **Note:** Not all of the features of `mdnotes` are listed in this table, just the ones that are relevant to this section. Some LSPs provide more than just LSP features and their documentation should also be referenced along with this table.

## Editing Tables
`mdnotes` tries to complement Neovim functionality to make editing tables as easy as possible. See the table below for what functions Neovim does and what functions are done by `mdnotes`.

|Feature                         |mdnotes                                   |Neovim                                                                 |
|--------------------------------|------------------------------------------|-----------------------------------------------------------------------|
|Insert empty rows               |Y (`:Mdn table row_insert_above/below`)   |N                                                                      |
|Duplicate row                   |N                                         |Y (`:h yy`)                                                            |
|Delete row                      |N                                         |Y (`:h dd`)                                                            |
|Move row                        |N                                         |Y (`:h dd` and `:h p`)                                                 |
|Insert empty columns            |Y (`:Mdn table column_insert_left/right`) |N                                                                      |
|Duplicate column                |Y (`:Mdn table column_duplicate`)         |N                                                                      |
|Delete column                   |Y (`:Mdn table column_delete`)            |Y (`:h visual-block`)                                                  |
|Move column                     |Y (`:Mdn table column_move_left/right`)   |N                                                                      |


 **Note:** Not all of the features of `mdnotes` are listed in this table, just the ones that are relevant to this section.

## 📢 Supported Markdown Formatting
Here is the supported Markdown formatting for `mdnotes.nvim`. The plugin tries to adhere to the [CommonMark](https://spec.commonmark.org/) and [GitHub Flavoured Markdown (GFM)](https://github.github.com/gfm/) spec as well as providing WikiLink support. If any problems arise please don't hesitate to create an issue for it!
### Links
Opened with `:Mdn open`. Inserted with the `:Mdn assets insert_file/image` and `:Mdn inline_link toggle` commands. If no extension is given to `file` below, it is treated as `.md`.
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
Opened with `:Mdn wikilink follow`. Can only be filenames, so `link` can also be `link.md`.
```
    [[link]]
    [[link#section]]
```
### Formatting
Toggled with `:Mdn formatting <format>_toggle`. Using `_` for the bold and italic formats needs to be specified in the `bold_format` and `italic_format` config options. 
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
- [markdown.nvim](https://github.com/tadmccorkle/markdown.nvim) 
 
