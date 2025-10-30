local mdnotes = {}

function mdnotes.setup(user_config)
    mdnotes.config = require('mdnotes.config').setup(user_config)
end

function mdnotes.go_to_index_file()
    if not mdnotes.config.index_file then
        vim.notify(("Mdn: Please specify assets path to use this feature"), vim.log.levels.ERROR)
        return
    end
    vim.cmd('edit ' .. mdnotes.config.index_file)
end

-- Simulate the map gf :e <cfile>.md<CR> so that it works with spaces
function mdnotes.open_md_file_wikilink()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, file ,end_pos in line:gmatch("()%[%[(.-)%]%]()") do
        if start_pos < current_col and end_pos > current_col then
            vim.cmd('edit ' .. file .. '.md')
        end
    end
end

function mdnotes.check_md_hyperlink()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, _, end_pos in line:gmatch("()(%[[^%]]+%]%([^%)]+%)())") do
        if start_pos < current_col and end_pos > current_col then
            return true
        end
    end

    return false
end

-- Had to make it a fully Lua function due to issues when selecting
-- with visual mode and executing a command.
function mdnotes.insert_hyperlink()
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

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. '[' .. selected_text .. '](' .. reg .. ')' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

function mdnotes.delete_hyperlink()
    -- TODO: Make this better?
    vim.api.nvim_input('F[di[F[vf)p')
end

function mdnotes.toggle_hyperlink()
    if check_md_hyperlink() then
        delete_hyperlink()
    else
        insert_hyperlink()
    end
end

-- TODO: Mention in the docs that this can be done with LSP
-- vim.lsp.buf.references()
function mdnotes.show_backlinks()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, file ,end_pos in line:gmatch("()%[%[(.-)%]%]()") do
        if start_pos < current_col and end_pos > current_col then
            vim.cmd('vimgrep /\\[\\[' .. file .. '\\]\\]/ *')
            vim.cmd('copen')
        end
    end
end

local outliner_state = false
-- TODO: Make it so that indenting on block indents everything below
-- OR mention the << and >> keymaps that you can do
function  mdnotes.toggle_outliner()
    if outliner_state then
        vim.api.nvim_buf_del_keymap(0 ,'i', '<CR>')
        vim.api.nvim_buf_del_keymap(0 ,'i', '<TAB>')
        vim.api.nvim_buf_del_keymap(0 ,'i', '<S-TAB>')
        vim.notify("Mdn: Exited Mdnotes Outliner Mode", vim.log.levels.INFO)
        outliner_state = false
    elseif not outliner_state then
        vim.api.nvim_input("<ESC>0i-  <ESC>")
        vim.keymap.set('i', '<CR>', '<CR>- ', { buffer = true })
        vim.keymap.set('i', '<TAB>', '<C-t>', { buffer = true })
        vim.keymap.set('i', '<S-TAB>', '<C-d>', { buffer = true })
        vim.notify("Mdn: Entered Mdnotes Outliner Mode", vim.log.levels.INFO)
        outliner_state = true
    end
end

local function get_current_dir()
    local info = debug.getinfo(1, "S")
    local source = info.source:sub(2)
    return vim.fn.fnamemodify(source, ":p:h"):gsub("\\", "/") .. "/"
end


function mdnotes.insert_image()
    -- Check for assets folder
    if not mdnotes.config.assets_path then
        vim.notify(("Mdn: Please specify assets path to use this feature"), vim.log.levels.ERROR)
        return
    end

    if not vim.fn.isdirectory(mdnotes.config.assets_path) then
        vim.notify(("Mdn: Assets path %s doesn't exist"):format(mdnotes.config.assets_path), vim.log.levels.ERROR)
        return
    end

    -- Get the file paths as a table
    local file_paths = vim.split(
        vim.system({get_current_dir() .. '../../bin/gcfp.exe'}, { text = true }):wait().stdout, '\n'
    )

    -- Remove last entry since it will always be '\n'
    table.remove(file_paths)

    if #file_paths > 1 then
        vim.notify('Mdn: Too many files paths detected. Please select only one file', vim.log.levels.WARN)
        return
    end

    -- Exit if none found
    if file_paths[1] == 'None' then
        vim.notify('Mdn: No file paths found in clipboard', vim.log.levels.WARN)
        return
    end

    -- Make sure '/' is the path separator
    local file = file_paths[1]
    local cmd = {}
    if vim.fn.has("win32") == 1 then
        mdnotes.config.assets_path = mdnotes.config.assets_path:gsub('/', '\\')
        cmd = { "cmd", "/C", "copy", file, mdnotes.config.assets_path}
    else
        cmd = { "cp", file, mdnotes.config.assets_path }
    end

    local cmd_res = vim.system(cmd, { text = true }):wait()

    if cmd_res.code ~= 0 then
        vim.notify(("Mdn: File copy failed: %s"):format(cmd_res.stdout or cmd_res.stderr), vim.log.levels.ERROR)
    end

    vim.notify('Mdn: Copied ' .. file .. ' to your assets folder', vim.log.levels.INFO)
end

return mdnotes
