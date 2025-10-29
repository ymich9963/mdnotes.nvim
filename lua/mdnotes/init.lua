local mdnotes = {}

function mdnotes.setup(user_config)
    mdnotes.config = require('mdnotes.config').setup(user_config)
end

function mdnotes.go_to_index_file()
    if mdnotes.config.index_file == "" then
        vim.notify(("Mdn: Please specify an index file to use this feature."), vim.log.levels.ERROR)
        return
    end
    vim.cmd('edit ' .. mdnotes.config.index_file)
end

function mdnotes.go_to_journal_file()
    if mdnotes.config.diary_file == "" then
        vim.notify(("Mdn: Please specify a diary file to use this feature."), vim.log.levels.ERROR)
        return
    end
    vim.cmd('edit ' .. mdnotes.config.diary_file)
end

-- Simulate the map gf :e <cfile>.md<CR> so that it works with spaces
function mdnotes.open_md_file_wikilink()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, file ,end_pos in line:gmatch("()%[%[(.-)%]%]()") do
        if start_pos < current_col and end_pos > current_col then
            if file:sub(-3) == ".md" then
                vim.cmd('edit ' .. file)
            else
                vim.cmd('edit ' .. file .. '.md')
            end
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
    vim.api.nvim_input('F[di[F[vf)p')
end

function mdnotes.toggle_hyperlink()
    if mdnotes.check_md_hyperlink() then
        mdnotes.delete_hyperlink()
    else
        mdnotes.insert_hyperlink()
    end
end

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
function  mdnotes.toggle_outliner()
    if outliner_state then
        vim.api.nvim_buf_del_keymap(0 ,'i', '<CR>')
        vim.api.nvim_buf_del_keymap(0 ,'i', '<TAB>')
        vim.api.nvim_buf_del_keymap(0 ,'i', '<S-TAB>')
        vim.notify("Mdn: Exited Mdnotes Outliner Mode.", vim.log.levels.INFO)
        outliner_state = false
    elseif not outliner_state then
        vim.api.nvim_input("<ESC>0i-  <ESC>")
        vim.keymap.set('i', '<CR>', '<CR>- ', { buffer = true })
        vim.keymap.set('i', '<TAB>', '<C-t>', { buffer = true })
        vim.keymap.set('i', '<S-TAB>', '<C-d>', { buffer = true })
        vim.notify("Mdn: Entered Mdnotes Outliner Mode.", vim.log.levels.INFO)
        outliner_state = true
    end
end

local function insert_file(file_type)
    -- Check for assets folder
    if mdnotes.config.assets_path == "" or not mdnotes.config.assets_path then
        vim.notify(("Mdn: Please specify assets path to use this feature."), vim.log.levels.ERROR)
        return
    end

    if vim.fn.isdirectory(mdnotes.config.assets_path) == 0 then
        vim.notify(("Mdn: Assets path %s doesn't exist. Change path or create it."):format(mdnotes.config.assets_path), vim.log.levels.ERROR)
        return
    end

    -- Get the file paths as a table
    local file_paths = vim.split(
        vim.system({vim.fs.normalize('../../bin/gcfp.exe')}, { text = true }):wait().stdout, '\n'
    )

    -- Remove last entry since it will always be '\n'
    table.remove(file_paths)

    if #file_paths > 1 then
        vim.notify('Mdn: Too many files paths detected. Please select only one file.', vim.log.levels.WARN)
        return
    end

    -- Exit if none found
    if file_paths[1] == 'None' then
        vim.notify('Mdn: No file paths found in clipboard.', vim.log.levels.WARN)
        return
    end

    local file_path = vim.fs.normalize(file_paths[1])
    local file_name = vim.fs.basename(file_path)

    -- Check overwrite behaviour
    if (vim.uv or vim.loop).fs_stat(vim.fs.joinpath(mdnotes.config.assets_path, file_name)) then
        if mdnotes.config.overwrite_behaviour == "error" then
            vim.notify(("Mdn: File you are trying to place into your assets already exists."), vim.log.levels.ERROR)
            return
        elseif mdnotes.config.overwrite_behaviour == "overwrite" then
        end
    end

    if mdnotes.config.insert_file_behaviour == "copy" then
        if not (vim.uv or vim.loop).fs_copyfile(file_path, vim.fs.joinpath(mdnotes.config.assets_path, file_name)) then
            vim.notify(("Mdn: File copy failed."), vim.log.levels.ERROR)
            return
        else
            vim.notify(('Mdn: Copied %s to your assets folder at %s.'):format(file_path, mdnotes.config.assets_path), vim.log.levels.INFO)
        end
    elseif mdnotes.config.insert_file_behaviour == "move" then
        if (vim.uv or vim.loop).fs_rename(file_path, vim.fs.joinpath(mdnotes.config.assets_path, file_name)) then
            vim.notify(("Mdn: File move failed."), vim.log.levels.ERROR)
            return
        else
            vim.notify(('Mdn: Moved %s to your assets folder at %s.'):format(file_path, mdnotes.config.assets_path), vim.log.levels.INFO)
        end
    end

    -- Create file link
    if file_type == "image" then
        vim.fn.setreg('"x', ('![%s](%s)'):format(file_name, vim.fs.joinpath(mdnotes.config.assets_path, file_name)))
    elseif file_type == "file" then
        vim.fn.setreg('"x', ('[%s](%s)'):format(file_name, vim.fs.joinpath(mdnotes.config.assets_path, file_name)))
    end

    -- Put text from register x
    vim.cmd('put')
end

function mdnotes.insert_image()
    insert_file("image")
end

function mdnotes.insert_file()
    insert_file("file")
end

return mdnotes

