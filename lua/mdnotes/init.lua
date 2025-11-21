local mdnotes = {}

local uv = vim.loop or vim.uv

local b = ""
local i = ""

mdnotes.buf_history = {}
mdnotes.buf_sections = {}
mdnotes.current_index = 0

local function resolve_open_behaviour(open_behaviour)
    if open_behaviour == "buffer" then
        return 'edit '
    elseif open_behaviour == "tab" then
        return 'tabnew '
    end
end

function mdnotes.setup(user_config)
    mdnotes.config = require('mdnotes.config').setup(user_config)

    b = mdnotes.config.bold_format:sub(1, 1)
    i = mdnotes.config.italic_format:sub(1, 1)

    mdnotes.format_patterns = {
        wikilink = "()%[%[(.-)%]%]()",
        file_section = "([^#]+)#?(.*)",
        hyperlink = "()(%[[^%]]+%]%([^%)]+%)())",
        text_link = "%[([^%]]+)%]%(([^%)]+)%)",
        bold = "()%" .. b .. "%" .. b .. "([^%" .. b .. "].-)%" .. b .. "%" .. b .. "()",
        italic = "()%" .. i .. "([^%" .. i .. "].-)%" .. i .."()",
        strikethrough = "()~~(.-)~~()",
        inline_code = "()`([^`]+)`()",
        list = "^([%s]-)([-+*])[%s](.+)",
        ordered_list = "^([%s]-)([%d]+)([%.%)])[%s]-(.+)",
        task = "[%s](%[[ xX]%])[%s].-",
        heading = "^([%#]+)[%s]+(.+)",
    }

    mdnotes.open = resolve_open_behaviour(mdnotes.config.wikilink_open_behaviour)
end

local function check_md_lsp()
    if next(vim.lsp.get_clients({bufnr = 0})) ~= nil and vim.bo.filetype == "markdown" and mdnotes.config.prefer_lsp then
        return true
    else
        return false
    end
end

function mdnotes.list_remap(inc_val)
    local line = vim.api.nvim_get_current_line()
    local list_indent, list_marker, list_text = line:match(mdnotes.format_patterns.list)
    local ordered_indent, ordered_marker, separator, ordered_text = line:match(mdnotes.format_patterns.ordered_list)
    local indent = list_indent or ordered_indent

    if list_marker then
        if list_text:match(mdnotes.format_patterns.task) then
            return indent, "\n" .. list_marker .. " " .. "[ ] "
        else
            return indent, "\n" .. list_marker .. " "
        end
    end

    if ordered_marker then
        if ordered_text:match(mdnotes.format_patterns.task) then
            return indent, "\n" .. tostring(tonumber(ordered_marker + inc_val)) .. separator .. " " .. "[ ] "
        else
            return indent, "\n" .. tostring(tonumber(ordered_marker + inc_val)) .. separator .. " "
        end
    end
    return indent, "\n"
end

function mdnotes.check_md_format(pattern)
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    for start_pos, _, end_pos in line:gmatch(pattern) do
        if start_pos < current_col and end_pos > current_col then
            return true
        end
    end

    return false
end

function mdnotes.check_assets_path()
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

local function get_section(section)
    for _, v in ipairs(mdnotes.buf_sections) do
        for index, vv in ipairs(v.parsed.gfm) do
            if vv == section then
                return v.parsed.original[index].text
            end
        end
    end
    return section
end

function mdnotes.open()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local link = ""
    local path = ""
    local section = ""

    for start_pos, hyperlink, end_pos in line:gmatch(mdnotes.format_patterns.hyperlink) do
        if start_pos < current_col and end_pos > current_col then
            _, link = hyperlink:match(mdnotes.format_patterns.text_link)
            link = link:gsub("[<>]?", "")
            path, section = link:match(mdnotes.format_patterns.file_section)
            -- Check for just a section first
            -- Path in this case is a section
            if link:sub(1,1) == "#" then
                path = get_section(path)
                vim.fn.cursor(vim.fn.search("# " .. path), 1)
                vim.api.nvim_input('zz')
            else
                -- Then it is assumed to have a path
                -- Append .md to guarantee a file name
                if path:sub(-3) ~= ".md" then
                    path = path .. ".md"
                end
                -- Check if the current file is the one in the link
                if path == vim.fs.basename(vim.api.nvim_buf_get_name(0)) then
                    section = get_section(section)
                    vim.fn.cursor(vim.fn.search("# " .. section), 1)
                    vim.api.nvim_input('zz')
                    -- Check if the file exists
                elseif uv.fs_stat(path) then
                    vim.cmd(mdnotes.open .. path)
                    if section ~= "" then
                        section = get_section(section)
                        vim.fn.cursor(vim.fn.search(section), 1)
                        vim.api.nvim_input('zz')
                    end
                    -- Last case is when it should be treated as a URI
                elseif vim.fn.has("win32") then
                    vim.system({"cmd.exe", "/c", "start", link})
                    -- Code below should work but doesn't - see Neovim issue below
                    -- https://github.com/neovim/neovim/issues/36293
                    -- This issue limits the :Mdn open functionality to only files and with no spaces
                    -- local cmd = {'cmd.exe', '/c', 'start', '""', ('"%s"'):format(link:gsub("/", "\\"))}
                    -- vim.print(table.concat(cmd, " "))
                    -- local ret = vim.system(cmd):wait()
                    -- vim.print(ret)
                else
                    vim.ui.open(link)
                end
            end
        end
    end
end

function mdnotes.go_to_index_file()
    if mdnotes.config.index_file == "" then
        vim.notify(("Mdn: Please specify an index file to use this feature."), vim.log.levels.ERROR)
        return
    end

    vim.cmd(mdnotes.open .. mdnotes.config.index_file)
end

function mdnotes.go_to_journal_file()
    if mdnotes.config.journal_file == "" then
        vim.notify(("Mdn: Please specify a diary file to use this feature."), vim.log.levels.ERROR)
        return
    end

    vim.cmd(mdnotes.open .. mdnotes.config.journal_file)
end

function mdnotes.open_wikilink()
    if check_md_lsp() then
        vim.lsp.buf.definition()
        if vim.tbl_isempty(vim.fn.getqflist()) then
            vim.fn.wait(1, function () end)
            vim.cmd.redraw()
            vim.notify(("Mdn: No locations found from LSP. Continuing with Mdnotes implementation."), vim.log.levels.WARN)
        else
            return
        end
    end

    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    local file, section = "", ""
    for start_pos, link ,end_pos in line:gmatch(mdnotes.format_patterns.wikilink) do
        -- Match link to links with section names
        file, section = link:match(mdnotes.format_patterns.file_section)

        file = vim.trim(file)
        section = vim.trim(section)

        if start_pos < current_col and end_pos > current_col then
            if file:sub(-3) == ".md" then
                vim.cmd(mdnotes.open .. file)
            else
                vim.cmd(mdnotes.open .. file .. '.md')
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
function mdnotes.hyperlink_insert()
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

function mdnotes.hyperlink_delete()
    vim.api.nvim_input('F[di[F[vf)p')
end

function mdnotes.hyperlink_toggle()
    if mdnotes.check_md_format(mdnotes.format_patterns.hyperlink) then
        mdnotes.hyperlink_delete()
    else
        mdnotes.hyperlink_insert()
    end
end

function mdnotes.show_references()
    if check_md_lsp() then
        vim.lsp.buf.references()
        return
    end

    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local wikilink_found = false

    for start_pos, file ,end_pos in line:gmatch(mdnotes.format_patterns.wikilink) do
        if start_pos < current_col and end_pos > current_col then
            vim.cmd.vimgrep({args = {'/\\[\\[' .. file .. '\\]\\]/', '*'}, mods = {emsg_silent = true}})
            if next(vim.fn.getqflist()) == nil then
                vim.notify(("Mdn: No references found for '" .. file .. "' ."), vim.log.levels.ERROR)
            else
                vim.cmd('copen')
                wikilink_found = true
            end
            break
        end
    end

    -- If wikilink pattern isn't detected used current file name
    if not wikilink_found then
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        local cur_file_name = cur_file_basename:match("(.+)%.[^%.]+$")
        vim.cmd.vimgrep({args = {'/\\[\\[' .. cur_file_name .. '\\]\\]/', '*'}, mods = {emsg_silent = true}})
        if next(vim.fn.getqflist()) == nil then
            vim.notify(("Mdn: No references found for current buffer."), vim.log.levels.ERROR)
        else
            vim.cmd('copen')
        end
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

local function contains_spaces(text)
    if string.find(text, "%s") ~= nil then
        return false
    else
        return true
    end
end

local function insert_file(file_type)
    if not mdnotes.check_assets_path() then return end

    -- Get the file paths as a table
    local cmd_stdout = ""
    local file_paths = {}
    if vim.fn.has("win32") then
        cmd_stdout = vim.system({'cmd.exe', '/c', 'powershell', '-command' ,'& {Get-Clipboard -Format FileDropList -Raw}'}, { text = true }):wait().stdout
    elseif vim.fn.has("linux") then
        local display_server = os.getenv "XDG_SESSION_TYPE"
        if display_server == "x11" or display_server == "tty" then
            cmd_stdout = vim.system({"xclip", "-selection", "clipboard", "-t", "text/uri-list", "-o", "|", "sed", "'s|file://||'"}, { text = true }):wait().stdout
        elseif display_server == "wayland" then
            cmd_stdout = vim.system({"wl-paste", "--type", "text/uri-list", "|", "sed", "'s|file://||'"}, { text = true }):wait().stdout
        end
    elseif vim.fn.has("mac") then
        cmd_stdout = vim.system({"osascript", "-e", '"tell application "Finder" to get the POSIX path of every item of (the clipboard as alias list)"'}, { text = true }):wait().stdout
    end

    if cmd_stdout ~= "" then
        file_paths = vim.split( cmd_stdout, '\n')
    else
        vim.notify('Mdn: Error when trying to read clipboard. Output of command: ' .. cmd_stdout .. '.', vim.log.levels.WARN)
        return
    end

    -- Remove last entry since it will always be '\n'
    table.remove(file_paths)

    if #file_paths > 1 then
        vim.notify('Mdn: Too many files paths detected. Please select only one file.', vim.log.levels.WARN)
        return
    end

    -- Exit if none found
    if file_paths[1] == 'None' or nil then
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
            vim.print(file_path, file_name)
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
    local asset_path = vim.fs.joinpath(mdnotes.config.assets_path, file_name)
    if file_type == "image" then
        if contains_spaces(asset_path) then
            vim.fn.setreg('"x', ('![%s](<%s>)'):format(file_name, asset_path))
        else
            vim.fn.setreg('"x', ('![%s](%s)'):format(file_name, asset_path))
        end
    elseif file_type == "file" then
        if contains_spaces(asset_path) then
            vim.fn.setreg('"x', ('[%s](<%s>)'):format(file_name, asset_path))
        else
            vim.fn.setreg('"x', ('[%s](%s)'):format(file_name, asset_path))
        end
    end

    -- Put text from register x
    vim.cmd('put')
end

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

function mdnotes.insert_journal_entry()
    local strftime = vim.fn.strftime(mdnotes.config.date_format):match("([^\n\r\t]+)")
    local journal_entry_template = {
        "## " .. strftime,
        "",
        "",
        "",
        "---",
        "",
    }

    vim.api.nvim_win_set_cursor(0, {1 ,0})
    vim.api.nvim_put(journal_entry_template, "V", false, false)
    vim.api.nvim_win_set_cursor(0, {3 ,0})
end

function mdnotes.cleanup_unused_assets()
    if not mdnotes.check_assets_path() then return end

    local temp_qflist = vim.fn.getqflist()
    local cleanup_all = false
    local cancel = false
    for name, _ in vim.fs.dir(mdnotes.config.assets_path) do
        vim.cmd.vimgrep({args = {'/\\](' .. mdnotes.config.assets_path .. '\\/' .. name .. ')/', '*'}, mods = {emsg_silent = true}})
        if next(vim.fn.getqflist()) == nil then
            if cancel then
                break
            end
            if not cleanup_all then
                vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to delete file(s) or 'cancel' to cancel (default 'n'): "):format(name), }, function(input)
                    vim.cmd.redraw()
                    if input == 'y' then
                        vim.fs.rm(vim.fs.joinpath(mdnotes.config.assets_path, name))
                        vim.notify(("Mdn: Removed '%s'. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    elseif input == 'a' then
                        vim.fs.rm(vim.fs.joinpath(mdnotes.config.assets_path, name))
                        cleanup_all = true
                    elseif input == 'cancel' then
                        cancel = true
                        vim.notify(("Mdn: Cancelled cleanup. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    elseif input == 'n' or '' then
                        vim.notify(("Mdn: Skipped '%s'. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    else
                        vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue:"):format(input), vim.log.levels.ERROR)
                        vim.fn.getchar()
                    end
                end)
            else
                vim.fs.rm(vim.fs.joinpath(mdnotes.config.assets_path, name))
            end
        end
    end

    vim.fn.setqflist(temp_qflist)
    vim.cmd.redraw()
    vim.notify(("Mdn: Finished cleanup."), vim.log.levels.INFO)
end

function mdnotes.move_unused_assets()
    if not mdnotes.check_assets_path() then return end
    local unused_assets_path = vim.fs.normalize(vim.fs.joinpath(mdnotes.config.assets_path, "../unused_assets"))

    if vim.fn.isdirectory(unused_assets_path) == 0 then
        uv.fs_mkdir(unused_assets_path, tonumber('777', 8))
    end

    local temp_qflist = vim.fn.getqflist()
    local move_all = false
    local cancel = false
    for name, _ in vim.fs.dir(mdnotes.config.assets_path) do
        vim.cmd.vimgrep({args = {'/\\](' .. mdnotes.config.assets_path .. '\\/' .. name .. ')/', '*'}, mods = {emsg_silent = true}})
        if next(vim.fn.getqflist()) == nil then
            if cancel then
                break
            end
            if not move_all then
                vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to move file(s) or 'cancel' to cancel (default 'n'): "):format(name), }, function(input)
                    vim.cmd('redraw')
                    if input == 'y' then
                        uv.fs_rename(vim.fs.joinpath(mdnotes.config.assets_path, name), vim.fs.joinpath(unused_assets_path, name))
                        vim.notify(("Mdn: Moved '%s'. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.cmd('call getchar()')
                    elseif input == 'a' then
                        uv.fs_rename(vim.fs.joinpath(mdnotes.config.assets_path, name), vim.fs.joinpath(unused_assets_path, name))
                        move_all = true
                    elseif input == 'cancel' then
                        cancel = true
                        vim.notify(("Mdn: Cancelled move. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.cmd('call getchar()')
                    elseif input == 'n' or '' then
                        vim.notify(("Mdn: Skipped '%s'. Press any key to continue:"):format(name), vim.log.levels.WARN)
                        vim.cmd('call getchar()')
                    else
                        vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue:"):format(input), vim.log.levels.ERROR)
                        vim.cmd('call getchar()')
                    end
                end)
            else
                uv.fs_rename(vim.fs.joinpath(mdnotes.config.assets_path, name), vim.fs.joinpath(unused_assets_path, name))
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

    local file, _ = "", ""
    local renamed = ""

    for start_pos, link ,end_pos in line:gmatch(mdnotes.format_patterns.wikilink) do
        -- Match link to links with section names but ignore the section name
        file, _ = link:match(mdnotes.format_patterns.file_section)
        file = vim.trim(file)

        if not uv.fs_stat(file .. ".md") then
            vim.notify(("Mdn: This link does not seem to link to a valid file."), vim.log.levels.ERROR)
            return
        end

        if start_pos < current_col and end_pos > current_col then
            vim.ui.input({ prompt = "Rename '".. file .."' to: " },
            function(input)
                renamed = input
            end)
            if renamed == "" or renamed == nil then
                vim.notify(("Mdn: Please insert a valid name."), vim.log.levels.ERROR)
                return
            else
                vim.cmd.vimgrep({args = {'/\\[\\[' .. file .. '\\]\\]/', '*'}, mods = {emsg_silent = true}})
                vim.cmd.cdo({args = {('s/%s/%s/'):format(file, renamed)}, mods = {emsg_silent = true}})
                if not uv.fs_rename(file .. ".md", renamed .. ".md") then
                    vim.notify(("Mdn: File rename failed."), vim.log.levels.ERROR)
                    return
                end
            end
            break
        end

    end

    if file == "" then
        vim.notify(("Mdn: No valid link under cursor."), vim.log.levels.ERROR)
        return
    end

    vim.notify((("Mdn: Succesfully renamed '%s' links to '%s'."):format(file, renamed)), vim.log.levels.INFO)
end

function mdnotes.rename_references_cur_buf()
    if check_md_lsp() then
        vim.lsp.buf.rename()
        return
    end

    local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
    local cur_file_name = cur_file_basename:match("(.+)%.[^%.]+$")
    local renamed = ""

    vim.ui.input({ prompt = "Rename '".. cur_file_name .."' to: " },
    function(input)
        renamed = input
    end)

    if renamed == "" or renamed == nil then
        vim.notify(("Mdn: Please insert a valid name."), vim.log.levels.ERROR)
        return
    end

    vim.cmd.vimgrep({args = {'/\\[\\[' .. cur_file_name .. '\\]\\]/', '*'}, mods = {emsg_silent = true}})
    vim.cmd.cdo({args = {('s/%s/%s/'):format(cur_file_name, renamed)}, mods = {emsg_silent = true}})
    if not uv.fs_rename(cur_file_name .. ".md", renamed .. ".md") then
        vim.notify(("Mdn: File rename failed."), vim.log.levels.ERROR)
        return
    end

    vim.notify((("Mdn: Succesfully renamed '%s' links to '%s'."):format(cur_file_name, renamed)), vim.log.levels.INFO)
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
    vim.api.nvim_input('F' .. b .. ';dwvf' .. b .. 'hdvlp')
end

local function delete_format_italic()
    vim.api.nvim_input('F' .. i .. 'dwvf' .. i ..'hdvp')
end

local function delete_format_strikethrough()
    vim.api.nvim_input('F~;dwvf~hdvlp')
end

local function delete_format_inline_code()
    vim.api.nvim_input('F`dwvf`hdvp')
end

function mdnotes.bold_toggle()
    if mdnotes.check_md_format(mdnotes.format_patterns.bold) then
        delete_format_bold()
    else
        insert_format(b .. b)
    end
end

function mdnotes.italic_toggle()
    if mdnotes.check_md_format(mdnotes.format_patterns.italic) then
        delete_format_italic()
    else
        insert_format(i)
    end
end

function mdnotes.strikethrough_toggle()
    if mdnotes.check_md_format(mdnotes.format_patterns.strikethrough) then
        delete_format_strikethrough()
    else
        insert_format('~~')
    end
end

function mdnotes.inline_code_toggle()
    if mdnotes.check_md_format(mdnotes.format_patterns.inline_code) then
        delete_format_inline_code()
    else
        insert_format('`')
    end
end

function mdnotes.task_list_toggle(line1, line2)
    local lines = {}
    local new_lines = {}
    if line1 == line2 then
        lines = {vim.api.nvim_get_current_line()}
    else
        lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    end
    for index, line in ipairs(lines) do
        local _, list_marker, list_text = line:match(mdnotes.format_patterns.list)
        local _, ordered_marker, separator, ordered_text = line:match(mdnotes.format_patterns.ordered_list)
        local text = list_text or ordered_text
        local marker = list_marker or ordered_marker .. separator
        local new_text = ""

        if marker then
            local task_marker = text:match(mdnotes.format_patterns.task)
            if task_marker == "[x]" then
                new_text, _ = line:gsub(mdnotes.format_patterns.task, "", 1)
            elseif task_marker == "[ ]" then
                new_text, _ = line:gsub(mdnotes.format_patterns.task, "[x] ", 1)
            elseif not task_marker then
                new_text = line:gsub(marker, marker .. " [ ]", 1)
            end
            table.insert(new_lines, new_text)
        else
            vim.notify(("Mdn: Unable to detect a task list marker at line ".. tostring(line1 - 1 + index) .. "."), vim.log.levels.ERROR)
            break
        end
    end
    vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, new_lines)
end

function mdnotes.get_sections_original()
    local sections = {}
    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, vim.fn.line("$"), false)
    for _, line in ipairs(buf_lines) do
        local heading, text = line:match(mdnotes.format_patterns.heading)
        if text and heading then
            table.insert(sections, {heading = heading, text = text})
        end
    end

    return sections
end

function mdnotes.get_sections_gfm_from_original(original_sections)
    local gfm_sections = {}
    for _, section in ipairs(original_sections) do
        local gfm_text = section.text:lower():gsub("[^%d%a%p ]+", ""):gsub(" ", "-")
        table.insert(gfm_sections, gfm_text)
    end

    return gfm_sections
end

function mdnotes.generate_toc()
    if vim.bo.filetype ~= "markdown" then
        vim.notify(("Mdn: Cannot generate a ToC for a non-Markdown file."), vim.log.levels.ERROR)
        return
    end

    local toc = {}
    local original_sections = {}
    local gfm_sections = {}
    local found = false

    local cur_buf_num = vim.api.nvim_get_current_buf()
    for _, v in ipairs(mdnotes.buf_sections) do
        if v.buf_num == cur_buf_num then
            original_sections = v.parsed.original
            gfm_sections = v.parsed.gfm
            found = true
        end
    end

    if not found then
        vim.notify(("Mdn: Parsed sections for current buffer not found."), vim.log.levels.ERROR)
        return
    end

    for index = 1, #original_sections do
        local _, hash_count = original_sections[index].heading:gsub("#", "")
        local spaces = string.rep(" ", vim.o.shiftwidth * (hash_count - 1), "")
        table.insert(toc, ("%s- [%s](#%s)"):format(spaces, original_sections[index].text, gfm_sections[index]))
    end
    vim.api.nvim_put(toc, "V", false, false)
end

return mdnotes

