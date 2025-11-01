local mdnotes = {}

local uv = vim.loop or vim.uv

function mdnotes.setup(user_config)
    mdnotes.config = require('mdnotes.config').setup(user_config)
end

local format_patterns = {
    wikilink_pattern = "()%[%[(.-)%]%]()",
    file_section_pattern = "([^#]+)#?(.*)",
    hyperlink_pattern = "()(%[[^%]]+%]%([^%)]+%)())",
    text_link_pattern = "()%[([^%]]+)%]%(([^%)]+)%)()",
    bold_pattern = "()%*%*([^%*].-)%*%*()",
    italic_pattern = "()%*([^%*].-)%*()",
    strikethrough_pattern = "()~~(.-)~~()",
    inline_code_pattern = "()`([^`]+)`()",
}

local function check_md_format(pattern)
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, _, end_pos in line:gmatch(pattern) do
        if start_pos < current_col and end_pos > current_col then
            return true
        end
    end

    return false
end

local function resolve_open_behaviour(open_behaviour)
    if open_behaviour == "buffer" then
        return 'edit '
    elseif open_behaviour == "tab" then
        return 'tabnew '
    end

    vim.notify(("Mdn: Invalid value in 'open_behaviour'."), vim.log.levels.ERROR)
    return nil
end

local function check_assets_path()
    if mdnotes.config.assets_path == "" or not mdnotes.config.assets_path then
        vim.notify(("Mdn: Please specify assets path to use this feature."), vim.log.levels.ERROR)
        return false
    end

    if vim.fn.isdirectory(mdnotes.config.assets_path) == 0 then
        vim.notify(("Mdn: Assets path %s doesn't exist. Change path or create it."):format(mdnotes.config.assets_path), vim.log.levels.ERROR)
        return false
    end

    return true
end

function mdnotes.open()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local link = ""

    for start_pos, hyperlink, end_pos in line:gmatch(format_patterns.hyperlink_pattern) do
        if start_pos < current_col and end_pos > current_col then
            _, link = hyperlink:match(format_patterns.text_link_pattern)
            if vim.fn.has("win32") then
                vim.system({"cmd.exe", "/c", "start", link})
            else
                vim.ui.open(link)
            end
        end
    end
end

function mdnotes.go_to_index_file()
    if mdnotes.config.index_file == "" then
        vim.notify(("Mdn: Please specify an index file to use this feature."), vim.log.levels.ERROR)
        return
    end

    local open = resolve_open_behaviour(mdnotes.config.wikilink_open_behaviour)
    if not open then return end

    vim.cmd(open .. mdnotes.config.index_file)
end

function mdnotes.go_to_journal_file()
    if mdnotes.config.journal_file == "" then
        vim.notify(("Mdn: Please specify a diary file to use this feature."), vim.log.levels.ERROR)
        return
    end

    local open = resolve_open_behaviour(mdnotes.config.wikilink_open_behaviour)
    if not open then return end

    vim.cmd(open .. mdnotes.config.journal_file)
end

-- Simulate the map gf :e <cfile>.md<CR> so that it works with spaces
function mdnotes.open_md_file_wikilink()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local open = resolve_open_behaviour(mdnotes.config.wikilink_open_behaviour)
    if not open then return end

    local file, section = "", ""
    for start_pos, link ,end_pos in line:gmatch(format_patterns.wikilink_pattern) do
        -- Match link to links with section names
        file, section = link:match(format_patterns.file_section_pattern)

        file = vim.trim(file)
        section = vim.trim(section)

        if start_pos < current_col and end_pos > current_col then
            if file:sub(-3) == ".md" then
                vim.cmd(open .. file)
            else
                vim.cmd(open .. file .. '.md')
            end
            break
        end

    end

    if section ~= "" then
        vim.fn.cursor(vim.fn.search(section), 1)
        vim.api.nvim_input('zz')
    end
end

-- Had to make it a fully Lua function due to issues when selecting
-- with visual mode and executing a command.
local function hyperlink_insert()
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

local function hyperlink_delete()
    vim.api.nvim_input('F[di[F[vf)p')
end

function mdnotes.hyperlink_toggle()
    if check_md_format(format_patterns.hyperlink_pattern) then
        hyperlink_delete()
    else
        hyperlink_insert()
    end
end

function mdnotes.show_backlinks()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local wikilink_found = false

    for start_pos, file ,end_pos in line:gmatch(format_patterns.wikilink_pattern) do
        if start_pos < current_col and end_pos > current_col then
            vim.cmd('vimgrep /\\[\\[' .. file .. '\\]\\]/ *')
            vim.cmd('copen')
            wikilink_found = true
            break
        end
    end

    -- If wikilink pattern isn't detecte used current file name
    if not wikilink_found then
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        local cur_file_name = cur_file_basename:match("(.+)%.[^%.]+$")
        vim.cmd('vimgrep /\\[\\[' .. cur_file_name .. '\\]\\]/ *')
        vim.cmd('copen')
    end
end

local outliner_state = false
function  mdnotes.outliner_toggle()
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
    if not check_assets_path() then return end

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
    if uv.fs_stat(vim.fs.joinpath(mdnotes.config.assets_path, file_name)) then
        if mdnotes.config.asset_overwrite_behaviour == "error" then
            vim.notify(("Mdn: File you are trying to place into your assets already exists."), vim.log.levels.ERROR)
            return
        elseif mdnotes.config.asset_overwrite_behaviour == "overwrite" then
        end
    end

    if mdnotes.config.insert_file_behaviour == "copy" then
        if not uv.fs_copyfile(file_path, vim.fs.joinpath(mdnotes.config.assets_path, file_name)) then
            vim.notify(("Mdn: File copy failed."), vim.log.levels.ERROR)
            return
        else
            vim.notify(('Mdn: Copied %s to your assets folder at %s.'):format(file_path, mdnotes.config.assets_path), vim.log.levels.INFO)
        end
    elseif mdnotes.config.insert_file_behaviour == "move" then
        if not uv.fs_rename(file_path, vim.fs.joinpath(mdnotes.config.assets_path, file_name)) then
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

mdnotes.buf_history = {}
mdnotes.current_index = 0

function mdnotes.go_back()
    if mdnotes.current_index > 1 then
        mdnotes.current_index = mdnotes.current_index - 1
        local prev_buf = mdnotes.buf_history[mdnotes.current_index]
        if vim.api.nvim_buf_is_valid(prev_buf) then
            vim.cmd("buffer " .. prev_buf)
        else
            vim.notify("Mdn: Attempting to access an invalid buffer.", vim.log.levels.ERROR)
        end
    else
        vim.notify("Mdn: No more buffers to go back to.", vim.log.levels.WARN)
    end
end

function mdnotes.go_forward()
    if mdnotes.current_index < #mdnotes.buf_history then
        mdnotes.current_index = mdnotes.current_index + 1
        local next_buf = mdnotes.buf_history[mdnotes.current_index]
        if vim.api.nvim_buf_is_valid(next_buf) then
            vim.cmd("buffer " .. next_buf)
        else
            vim.notify("Mdn: Attempting to access an invalid buffer.", vim.log.levels.ERROR)
        end
    else
        vim.notify("Mdn: No more buffers to go forward to.", vim.log.levels.WARN)
    end
end

function mdnotes.clear_history()
    mdnotes.buf_history = {}
    mdnotes.current_index = 0
end

function mdnotes.insert_image()
    insert_file("image")
end

function mdnotes.insert_file()
    insert_file("file")
end

function mdnotes.cleanup_unused_assets()
    if not check_assets_path() then return end

    local temp_qflist = vim.fn.getqflist()
    local cleanup_all = false
    for name, _ in vim.fs.dir(mdnotes.config.assets_path) do
        local vimgrep_ret = vim.cmd.vimgrep({args = {'/\\[\\[' .. name .. '\\]\\]/', '*'}, mods = {emsg_file = true}})
        if vimgrep_ret == "" then
            if not cleanup_all then
                vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to delete file(s) (default 'n'): "):format(name), }, function(input)
                    if input == 'y' then
                        vim.fs.rm(vim.fs.joinpath(mdnotes.config.assets_path, name))
                        vim.cmd('redraw')
                        vim.notify(("Mdn: Removed '%s'. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.cmd('call getchar()')
                    elseif input == 'a' then
                        cleanup_all = true
                        vim.fs.rm(vim.fs.joinpath(mdnotes.config.assets_path, name))
                    elseif input == 'n' or '' then
                        vim.cmd('redraw')
                        vim.notify(("Mdn: Skipped '%s'. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.cmd('call getchar()')
                    else
                        vim.cmd('redraw')
                        vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue:"):format(input), vim.log.levels.ERROR)
                        vim.cmd('call getchar()')
                    end
                end)
            else
                vim.fs.rm(vim.fs.joinpath(mdnotes.config.assets_path, name))
            end
        end
    end

    vim.fn.setqflist(temp_qflist)
    vim.cmd('redraw')
    vim.notify(("Mdn: Finished cleanup."), vim.log.levels.INFO)
end

function mdnotes.rename_link_references()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local open = resolve_open_behaviour(mdnotes.config.wikilink_open_behaviour)
    if not open then return end

    local file, _ = "", ""
    local renamed = ""

    for start_pos, link ,end_pos in line:gmatch(format_patterns.wikilink_pattern) do
        -- Match link to links with section names but ignore the section name
        file, _ = link:match("([^#]+)#?(.*)")

        file = vim.trim(file)

        if start_pos < current_col and end_pos > current_col then
            if not uv.fs_stat(file .. ".md") then
                vim.notify(("Mdn: This link does not seem to link to a valid file."), vim.log.levels.ERROR)
            end
            vim.ui.input({ prompt = "Rename '".. file .."' to: " }, function(input)
                renamed = input
            end)
            if renamed == "" or nil then
                vim.notify(("Mdn: Please insert a valid name."), vim.log.levels.ERROR)
                return
            else
                vim.cmd.vimgrep({args = {'/\\[\\[' .. file .. '\\]\\]/', '*'}, mods = {emsg_silent = true}})
                vim.cmd.cdo({args = {('cdo s/%s/%s/'):format(file, renamed)}, mods = {emsg_silent = true}})
                if not uv.fs_rename(file .. ".md", renamed .. ".md") then
                    vim.notify(("Mdn: File rename failed."), vim.log.levels.ERROR)
                    return
                end
            end
            break
        end

    end
    vim.notify((("Mdn: Succesfully renamed '%s' links to '%s'."):format(file, renamed)), vim.log.levels.INFO)
end

local function insert_format(format_char)
    -- Get the selected text
    local col_start = vim.fn.getpos("'<")[3]
    local col_end = vim.fn.getpos("'>")[3]
    local line = vim.api.nvim_get_current_line()
    local selected_text = line:sub(col_start, col_end)

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. format_char .. selected_text .. format_char .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

local function delete_format_bold()
    vim.api.nvim_input('F*;dwvf*hdvlp')
end

local function delete_format_italic()
    vim.api.nvim_input('F*dwvf*hdvp')
end

local function delete_format_strikethrough()
    vim.api.nvim_input('F~;dwvf~hdvlp')
end

local function delete_format_inline_code()
    vim.api.nvim_input('F`dwvf`hdvp')
end

function mdnotes.bold_toggle()
    if check_md_format(format_patterns.bold_pattern) then
        delete_format_bold()
    else
        insert_format('**')
    end
end

function mdnotes.italic_toggle()
    if check_md_format(format_patterns.italic_pattern) then
        delete_format_italic()
    else
        insert_format('*')
    end
end

function mdnotes.strikethrough_toggle()
    if check_md_format(format_patterns.strikethrough_pattern) then
        delete_format_strikethrough()
    else
        insert_format('~~')
    end
end

function mdnotes.inline_code_toggle()
    if check_md_format(format_patterns.inline_code_pattern) then
        delete_format_inline_code()
    else
        insert_format('`')
    end
end

return mdnotes

