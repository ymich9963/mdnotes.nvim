-- TODO: Make this configurable
local index_file = "MAIN.md"
local assets_path = "assets" -- can be absolute or relative 

local go_to_home_file = function()
    vim.cmd('edit ' .. index_file)
end

-- Simulate the map gf :e <cfile>.md<CR> so that it works with spaces
local open_md_file_wikilink = function()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, file ,end_pos in line:gmatch("()%[%[(.-)%]%]()") do
        if start_pos < current_col and end_pos > current_col then
            vim.cmd('edit ' .. file .. '.md')
        end
    end
end

local check_md_hyperlink = function()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, _, end_pos in line:gmatch("()(%[[^%]]+%]%([^%)]+%)())") do
        if start_pos < current_col and end_pos > current_col then
            return true
        end
    end

    return false
end

local insert_hyperlink = function()
    local reg = vim.fn.getreg('+')

    -- Set if empty
    if reg == '' then
        vim.fn.setreg('+','"+ register empty')
    end

    -- Sanitize text to prevent chaos
    vim.fn.setreg('+', reg:gsub("[%c]", ""))

    -- Get the selected text
    local col_start = vim.fn.getpos("'<")[3]
    local col_end = vim.fn.getpos("'>")[3]
    local line = vim.api.nvim_get_current_line()
    local selected_text = line:sub(col_start, col_end)

    -- Create a new modified line
    local new_line = line:sub(1, col_start - 1) .. '[' .. selected_text .. ']()' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})

    -- Insert hyperlink from clipboard
    vim.api.nvim_input('"+p')
end

local delete_hyperlink = function()
    -- TODO: Make this better
    vim.api.nvim_input('di[F[vf)p')
end

local toggle_hyperlink = function()
    if check_md_hyperlink() then
        delete_hyperlink()
    else
        insert_hyperlink()
    end
end

local show_backlinks_no_lsp = function()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, file ,end_pos in line:gmatch("()%[%[(.-)%]%]()") do
        if start_pos < current_col and end_pos > current_col then
            vim.cmd('vimgrep /\\[\\[' .. file .. '\\]\\]/ *')
        end
    end
end

local show_backlinks_lsp = function()
    vim.lsp.buf.references()
end

-- TODO: Make it so that indenting on block indents everything below
-- OR mention the << and >> keymaps that you can do
local outliner_enable = function()
    vim.api.nvim_input("<ESC>0i- ")
    vim.keymap.set('i', '<CR>', '<CR>- ', { buffer = true })
    vim.keymap.set('i', '<TAB>', '<C-t>', { buffer = true })
    vim.keymap.set('i', '<S-Tab>', '<C-d>', { buffer = true })
    vim.notify("Entered MDNotes Outliner Mode", vim.log.levels.INFO)
end

local outliner_disable = function()
    vim.api.nvim_buf_del_keymap(0 ,'i', '<CR>')
    vim.api.nvim_buf_del_keymap(0 ,'i', '<TAB>')
    vim.api.nvim_buf_del_keymap(0 ,'i', '<S-TAB>')
    vim.notify("Exited MDNotes Outliner Mode", vim.log.levels.INFO)
end

local insert_image = function()
    print("dev")
end

local subcommands = {
    home = go_to_home_file,
    open_wikilink = open_md_file_wikilink,
    toggle_hyperlink = toggle_hyperlink,
    delete_hyperlink = delete_hyperlink,
    insert_hyperlink = insert_hyperlink,
    show_backlinks_no_lsp = show_backlinks_no_lsp,
    show_backlinks_lsp = show_backlinks_lsp,
    outliner_enable = outliner_enable,
    outliner_disable = outliner_disable,
    insert_image = insert_image,
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

