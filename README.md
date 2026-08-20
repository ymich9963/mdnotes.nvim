# 📓 mdnotes.nvim
![Neovim](https://img.shields.io/badge/Built%20for-Neovim-green?logo=neovim&color=%2357A143&link=https%3A%2F%2Fmit-license.org%2F)
![Lua badge](https://img.shields.io/badge/Made%20with-Lua-purple?logo=lua&color=%23000080&link=https%3A%2F%2Flua.org%2F)
![MIT license](https://img.shields.io/badge/License-MIT-blue?link=https%3A%2F%2Fmit-license.org%2F)

**Simple, improved, and extensible Markdown note taking.**

---

## ☀️ Introduction

Mdnotes aims to be a lightweight plugin that improves the Markdown note-taking experience in Neovim, with minimal configuration required. It also exposes most of the functions used internally, so that the user can create an extensible note-taking experience similar to Neovim's philosophy.

In the [Recommendations](#-recommendations) section I've written some notes on my recommended `mdnotes` setup, and please read [MARKDOWN.md](MARKDOWN.md) to know how `mdnotes` aims to format your notes. Also see [RATIONALE.md](RATIONALE.md) for information on certain design decisions like directory structure, using LSPs, and editing tables.

If you are migrating from another note-taking application, then [MIGRATING.md](MIGRATING.md) might be of interest to you, and I've also written some useful tips in [TIPS.md](TIPS.md) for when writing notes in out-of-the-box Neovim. Lastly, a disclaimer I must unfortunately say, is if you are executing any mass data-altering commands, ensure you have a notes backup!

All documentation is available with `:h mdnotes.txt`. Execute `:checkhealth mdnotes` to ensure there are no problems with your plugin config.

## 🔥 Features
For a complete descriptive feature list with their associated commands, please see [FEATURES.md](FEATURES.md).

- Uses subcommands with opt-in default key mappings and opt-out autocmds
- **Formatting**: Toggling for strong, emphasis, inline code, strikethrough, autolink, fenced code blocks
- **Inline links**: open, toggle, rename, relink, and normalize
- **WikiLinks**: Create, follow, rename, show, delete, and find/rename references
- **Assets**: Insert, manage, view, and delete assets
- **Tables**: Create, best-fit, insert/move/duplicate/align/sort columns, and insert empty rows
- **Reference links**: Open, insert, update, manage, convert from inline links and vice versa
- **Footnotes**: insert, update, renumber, go-to, find references, and cleanup
- Navigate to index file or dynamic journal files
- Sequential Markdown buffer history
- Heading navigation
- Ordered and unordered list continuation and renumbering
- Task list toggling
- Generate, update, and browse Table of Contents
- Outliner mode
- View statistics of current buffer
- Create user commands within the plugin namespace for organisation
- Supports multiple pickers
- Most internal functions are exposed as an API for extensibility (`:h mdnotes-api`)

## 👽 Setup
Supports Neovim 0.12 or later.

Using `vim.pack`,
```lua
vim.pack.add({"https://github.com/ymic9963/mdnotes.nvim" })
require("mdnotes").setup({
    -- Config here
})
```

Using the lazy.nvim package manager,
```lua
{
    "ymic9963/mdnotes.nvim",
}
```

and specify your config using `opts = {}` or with a `setup({})` function,
```lua
{
    "ymic9963/mdnotes.nvim",
    opts = {
        -- Config here
    }
    -- or
    config = {
        require("mdnotes").setup({
            -- Config here
        })
    }
}
```
### 🌐 Default Config
```lua
{
    index_file = "",
    journal_file = "",              -- path or function returning string for dynamic journal file
    assets_path = "",               -- path or function returning string for dynamic asset path
    asset_insert_behaviour = "copy",-- "copy" or "move" files when inserting from clipboard
    overwrite_behaviour = "error",  -- "overwrite" or "error" when finding assset file conflicts
    open_behaviour = "buffer",      -- "buffer", "tab", "split", or "vsplit" to open when following links
    date_format = "%a %d %b %Y"     -- date format based on :h strftime()
    prefer_lsp = false,             -- to prefer LSP functions than the mdnotes functions
    auto_list_continuation = true,  -- automatic list continuation
    default_keymaps = false,
    autocmds = true,                -- enable or disable plugin autocmds, check docs for enabling/disabling individual ones
    table_best_fit_padding = 0,     -- add padding around cell contents when using tables_best_fit
    toc_depth = 4                   -- depth shown in the ToC
    user_commands = {}              -- table with user commands in {command_name = function} scheme
}
```
### 📂 Directory Setup
Sample directory structure for `mdnotes` is shown below. See [RATIONALE.md](RATIONALE.md) for reasons regarding the accepted file structure.
```
notes/
├───assets/
│   ├───fire.png
│   └───water.pdf
├───music.md
├───electronics.md
etc.
```
This plugin was made with this type of directory structure in mind because this is how I use it. If this directory configuration doesn't suit you please make an issue and hopefully I'll be able to accomodate anyone's needs.

## 💋 Recommendations
I've specified below some recommended plugins, keymaps, and optional settings for a great experience with `mdnotes`.

### 🔌 Plugins
For the best Neovim Markdown note-taking experience, I've listed some other projects to optionally install alongside `mdnotes`,
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Tree-sitter for Neovim; with this also install the `markdown`, `markdown_inline`, and `latex` parsers.
- In-Neovim Previewer for Markdown files (both are excellent),
    - [markview.nvim](https://github.com/OXY2DEV/markview.nvim)
    - [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)
- Live Previewer for Markdown files in browser,
    - [markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim) - Older, more widely used, has dependencies
    - [live-preview.nvim](https://github.com/brianhuster/live-preview.nvim) - Newer, no dependencies
- LSP - Please see the [Using LSPs Section](RATIONALE.md#using-lsps) for more information regarding LSPs, but I recommend one of,
    - [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide)
    - [marksman](https://github.com/artempyanykh/marksman)
    - [iwe-org/iwe](https://github.com/iwe-org/iwe) with [iwe-org/iwe.nvim](https://github.com/iwe-org/iwe.nvim) (See their comparison [here](https://iwe.md/docs/concepts/comparison/#detailed-comparisons))

Check out some [Other Cool Markdown-related Plugins](#-other-cool-markdownrelated-plugins) that you may want to use alongside (or instead of) `mdnotes`.

### ⌨️ Keymaps
 The keymappings below can be enabled by setting `default_keymaps = true` as they are not enabled by default, and they will only be available in Markdown buffers. Place any `mdnotes` keymaps in a  `<Neovim config path>/after/ftplugin/markdown.lua` file so that they're also Markdown specific. For organisation they use the `<leader>m` prefix.
 ```lua
vim.keymap.set('n', '<leader>mgx', ':Mdn inline_link open<CR>', { buffer = true, desc = "Open inline link URI under cursor" })
vim.keymap.set('n', '<leader>mgf', ':Mdn wikilink follow<CR>', { buffer = true, desc = "Open markdown file from WikiLink" })
vim.keymap.set('n', '<leader>mgF', ':Mdn wikilink follow_hor<CR>', { buffer = true, desc = "Open markdown file from WikiLink in a horizontal split" })
vim.keymap.set('n', '<leader>mgrr', ':Mdn wikilink show_references<CR>', { buffer = true, desc = "Show references of link or buffer" })
vim.keymap.set('n', '<leader>mgrn', ':Mdn wikilink rename_references<CR>', { buffer = true, desc = "Rename references of link or current buffer" })
vim.keymap.set({"v", "n"}, "<leader>mk", ":Mdn inline_link toggle<CR>", { buffer = true, desc = "Toggle inline link" })
vim.keymap.set("n", "<leader>mh", ":Mdn history go_back<CR>", { buffer = true, desc = "Go to back to previously visited Markdown buffer" })
vim.keymap.set("n", "<leader>ml", ":Mdn history go_forward<CR>", { buffer = true, desc = "Go to next visited Markdown buffer" })
vim.keymap.set({"v", "n"}, "<leader>mb", ":Mdn formatting strong_toggle<CR>", { buffer = true, desc = "Toggle strong formatting" })
vim.keymap.set({"v", "n"}, "<leader>mi", ":Mdn formatting emphasis_toggle<CR>", { buffer = true, desc = "Toggle emphasis formatting" })
vim.keymap.set({"v", "n"}, "<leader>mt", ":Mdn formatting task_list_toggle<CR>", { buffer = true, desc = "Toggle task list status" })
vim.keymap.set("n", "<leader>mp", ":Mdn heading previous<CR>", { buffer = true, desc = "Go to previous Markdown heading" })
vim.keymap.set("n", "<leader>mn", ":Mdn heading next<CR>", { buffer = true, desc = "Go to next Markdown heading" })
```
### 👩‍💻 Optional Settings
Place these settings in your `<Neovim config path>/after/ftplugin/markdown.lua` file so that they are Markdown-specific. 

Enable wrapping only for the current Markdown buffer. 
```lua
vim.wo[vim.api.nvim_get_current_win()][0].wrap = true -- Enable wrap for current .md buffer
```
Disable LSP diagnostics in the current Markdown buffer.
```lua
vim.diagnostic.enable(false, { bufnr = 0 }) -- Disable diagnostics for current .md buffer
```
This is for the glorious Neovim Windows users. Setting this keymap will allow you to use the built in `<C-x> <C-f>` file completion for WikiLinks or just for using file paths in Markdown buffers.
```lua
vim.keymap.set("i", "<C-x><C-f>", "<cmd>set isfname-=[,]<CR><C-x><C-f><cmd>set isfname+=[,]<CR>",
{
    desc = "Mdnotes i_CTRL-X_CTRL-F smart remap to allow path completion on Windows",
    buffer = true
})
```

## 🫂 Motivation
I wanted to make a more Neovim-centric Markdown notes plugin that tries to work the available Markdown LSPs, is command/subcommand focused, concise, adheres to the [CommonMark](https://spec.commonmark.org/) and [GFM](https://github.github.com/gfm/) specs, while also providing the more widespread [WikiLink](https://github.com/Python-Markdown/markdown/blob/master/docs/extensions/wikilinks.md) support other note-taking apps provide. I hope I did in fact accomplish this (and more) for you as well as for me, and if I have not then please create an issue or contribute! Thanks for reading this :).

## 🫰 Other Cool Markdown-related Plugins
- [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- [markdown-plus.nvim](https://github.com/yousefhadder/markdown-plus.nvim)
- [mkdnflow.nvim](https://github.com/jakewvincent/mkdnflow.nvim)
- [markdown.nvim](https://github.com/tadmccorkle/markdown.nvim) 
- [neowiki.nvim](https://github.com/echaya/neowiki.nvim)
- [vim-markdown-toc](https://github.com/mzlogin/vim-markdown-toc)
- [vim-table-mode](https://github.com/dhruvasagar/vim-table-mode)
 
## Tests
Using [mini.test](https://github.com/nvim-mini/mini.test) for testing. For this project, if you want to run the tests then you need to install mini.test as a plugin locally. This was done to minimise dependencies in the repo. If you're not using lazy then you need to specify the `mini.test` location, using the `mini_path` variable in `scripts/minimal_init.lua`. To run the tests execute the following command in the project root,
```bash
nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"
```
or for individual test files,
```bash
nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('tests/test_*.lua')"
```

