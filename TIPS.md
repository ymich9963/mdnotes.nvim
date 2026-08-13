# Neovim Tips for mdnotes.nvim
`mdnotes` tries to integrate with stock Neovim as much as possible, and through trying to create a great note-writing experience in Neovim, I came across some great built-in Neovim features that are defitely useful when taking any kind of notes. I've listed them below, and I'll update this list as I find out more. Contributions are welcome!

The contents here are replicated in `:h mdnotes-tips`.

## Repeating Last Command
Use `@:` to repeat your last used command, see `:h @:`.

This one is especially useful if you are executing a toggle command like `:Mdn formatting task_list_toggle` when you want to quickly execut the command multiple times.

## Find and Replace
An easy way to search your entire notes directory without any external tools is `vimgrep`, see `:h vimgrep`. It uses the Vim patterns and populates the quickfix list (`:h quickfix`) which you can then use to execute commands on the results. For example,
```vim
:vimgrep /balls/ **
```
would look for the word `balls` in all directories, from the current working directory; this is noted by the `**`. Once the quickfix list is populated, you can browse it with `:copen` and pressing `<CR>` on each result would take you to its location. With this list you can use `:cdo` to execute a command over all of the results. For example, to replace all occurences of the word `balls` with `dict`, you would do,
```vim
:vimgrep /balls/ **
:cdo s/balls/dict/g
```
### Tags
An obvious use-case for this is with tags, therefore you can use the above example to search for notes with the corresponding tag,
```vim
:vimgrep /#politics/ **
```

## Finding Files
The `:find` command is great for finding files in a directory with a not-so-large number of files.

A simple enhancement is to use this option, which will make the command automatically look in all subdirectories when called, 
```lua
vim.opt.path:append{"**"} -- Use :find for all subdirectories
```
but you can also call it as `:find **` and when you press `<Tab>`, it will autocomplete with the directories.

Another enhancement is based on `:h fuzzy-file-picker`and I've pasted my Lua implementation below. This overwrites the previously mentioned option,
```lua
-- Advanced :find, see :h fuzzy-file-picker
local filescache = {}
function _G.find(arg, _)
    if vim.tbl_isempty(filescache) then
        filescache = vim.fn.globpath('.', '**', true, true)
        vim.tbl_filter(function(value) return not vim.fn.isdirectory(value) end,filescache)
        vim.tbl_map(function(value) return vim.fn.fnamemodify(value, ':.') end, filescache)
    end

    return arg == '' and filescache or vim.fn.matchfuzzy(filescache, arg)
end
vim.o.findfunc = "v:lua.find"

vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = { "*" },
    group = config_augroup,
    callback = function()
        filescache = {}
    end,
    description = "Advanced :find autocmd"
})
```

## Indenting
To indent in INSERT mode use `:h i_CTRL+T` and `:h i_CTRL+D` and to indent in NORMAL mode use `:h <<` and `:h >>`. The ones in insert mode are commonly mapped to `<TAB>` and `<S-TAB>` since that is a very common mapping in other programs. In `mdnotes` there are the `:h :Mdn-outliner-indent/unindent` commands which provide the same indenting functionality but also execute more outliner-style indenting when using nested lists. This was inspired by applications such as Logseq.
