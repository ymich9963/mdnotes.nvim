local M = {}

local uv = vim.loop or vim.uv

function M.check_assets_path()
    local mdnotes_config_assets_path = require('mdnotes').config.assets_path
    if mdnotes_config_assets_path == "" or not mdnotes_config_assets_path then
        vim.notify(("Mdn: Please specify assets path to use this feature."), vim.log.levels.ERROR)
        return false
    end

    if vim.fn.isdirectory(mdnotes_config_assets_path) == 0 then
        vim.notify(("Mdn: Assets path %s doesn't exist. Change path or create it."):format(mdnotes_config_assets_path), vim.log.levels.ERROR)
        return false
    end

    return true
end

function M.open_containing_folder()
    if not M.check_assets_path() then return end

    -- There might be issues with code below, see issue
    -- https://github.com/neovim/neovim/issues/36293
    vim.ui.open(require('mdnotes').config.assets_path)
end

local function contains_spaces(text)
    return string.find(text, "%s") ~= nil
end

local function insert_file(file_type)
    if not M.check_assets_path() then return end

    -- Get the file paths as a table
    local cmd_stdout = ""
    local file_paths = {}
    if vim.fn.has("win32") == 1 then
        cmd_stdout = vim.system({'cmd.exe', '/c', 'powershell', '-command' ,'& {Get-Clipboard -Format FileDropList -Raw}'}, { text = true }):wait().stdout
    elseif vim.fn.has("linux") == 1 then
        local display_server = os.getenv "XDG_SESSION_TYPE"
        if display_server == "x11" or display_server == "tty" then
            cmd_stdout = vim.system({"xclip", "-selection", "clipboard", "-t", "text/uri-list", "-o", "|", "sed", "'s|file://||'"}, { text = true }):wait().stdout
        elseif display_server == "wayland" then
            cmd_stdout = vim.system({"wl-paste", "--type", "text/uri-list", "|", "sed", "'s|file://||'"}, { text = true }):wait().stdout
        end
    elseif vim.fn.has("mac") == 1 then
        cmd_stdout = vim.system({"osascript", "-e", "set f to the clipboard as alias", "-e", "POSIX path of f"}, { text = true }):wait().stdout
    end

    if cmd_stdout ~= "" then
        file_paths = vim.split( cmd_stdout, '\n')
    else
        vim.notify("Mdn: Error when trying to read clipboard. Output of command: '" .. cmd_stdout .. '"', vim.log.levels.WARN)
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
    local mdnotes_config = require('mdnotes').config

    -- Check overwrite behaviour
    if uv.fs_stat(vim.fs.joinpath(mdnotes_config.assets_path, file_name)) then
        if mdnotes_config.asset_overwrite_behaviour == "error" then
            vim.notify(("Mdn: File you are trying to place into your assets already exists."), vim.log.levels.ERROR)
            return
        elseif mdnotes_config.asset_overwrite_behaviour == "overwrite" then
        end
    end

    if mdnotes_config.insert_file_behaviour == "copy" then
        if not uv.fs_copyfile(file_path, vim.fs.joinpath(mdnotes_config.assets_path, file_name)) then
            vim.notify(("Mdn: File copy failed."), vim.log.levels.ERROR)
            vim.print(file_path, file_name)
            return
        else
            vim.notify(('Mdn: Copied "%s" to your assets folder at "%s".'):format(file_path, mdnotes_config.assets_path), vim.log.levels.INFO)
        end
    elseif mdnotes_config.insert_file_behaviour == "move" then
        if not uv.fs_rename(file_path, vim.fs.joinpath(mdnotes_config.assets_path, file_name)) then
            vim.notify(("Mdn: File move failed."), vim.log.levels.ERROR)
            return
        else
            vim.notify(('Mdn: Moved "%s" to your assets folder at "%s".'):format(file_path, mdnotes_config.assets_path), vim.log.levels.INFO)
        end
    end

    -- Create file link
    local asset_path = vim.fs.joinpath(mdnotes_config.assets_path, file_name)
    local text = ""

    if contains_spaces(asset_path) then
        text = ("[%s](<%s>)"):format(file_name, asset_path)
    else
        text = ("[%s](%s)"):format(file_name, asset_path)
    end

    if file_type == "image" then
        text = "!" .. text
    end

    vim.api.nvim_put({text}, "c", false, false)
end

function M.insert_image()
    insert_file("image")
end

function M.insert_file()
    insert_file()
end

local function get_used_assets(silent)
    if not silent then silent = false end
    local mdnotes_config = require('mdnotes').config
    local uri = ""
    local used_assets = {}
    local temp_qflist = vim.fn.getqflist()
    local assets_list = {}

    -- Vimgrep inline links with asset paths with no spaces
    vim.cmd.vimgrep({args = {"/](" .. mdnotes_config.assets_path .. "\\//", '*'}, mods = {emsg_silent = true}})
    local assets_qf_list_no_spaces = vim.fn.getqflist()

    -- Vimgrep inline links with asset paths with spaces
    vim.cmd.vimgrep({args = {"/](<" .. mdnotes_config.assets_path .. "\\//", '*'}, mods = {emsg_silent = true}})
    local assets_qf_list_spaces = vim.fn.getqflist()

    -- Join the two tables
    assets_list = assets_qf_list_spaces
    for _, v in ipairs(assets_qf_list_no_spaces) do
        table.insert(assets_list, v)
    end

    for _, v in ipairs(assets_list) do
        for _, inline_link, _ in v.text:gmatch(require("mdnotes.patterns").inline_link) do
            _, uri = inline_link:match(require("mdnotes.patterns").text_uri)

            -- Remove any < or > from uri
            uri = uri:gsub("[<>]?", "")

            table.insert(used_assets, vim.fs.basename(uri))
            break
        end
    end

    if silent == false then
        vim.notify("Mdn: Found " .. #used_assets .. " used assets", vim.log.levels.INFO)
    end

    vim.fn.setqflist(temp_qflist)
    return used_assets
end

local function move_delete(move_or_delete)
    if not M.check_assets_path() then return end

    local used_assets = get_used_assets(true)
    local mdnotes_config = require('mdnotes').config
    local unused_assets_path = vim.fs.normalize(vim.fs.joinpath(mdnotes_config.assets_path, "../unused_assets"))
    local path_used = ""
    local text1 = ""
    local text2 = ""
    local all = false
    local cancel = false
    local mv = nil
    local del = nil

    if move_or_delete == "move" then
        path_used = unused_assets_path
        text1 = "move"
        text2 = "Moved"
        mv = true
        if vim.fn.isdirectory(path_used) == 0 then
            uv.fs_mkdir(path_used, tonumber('777', 8))
        end
    elseif move_or_delete == "delete" then
        path_used = mdnotes_config.assets_path
        text1 = "delete"
        text2 = "Deleted"
        del = true
    end

    vim.notify(("Mdn: Starting %s assets process..."):format(text1), vim.log.levels.INFO)

    for name, _ in vim.fs.dir(mdnotes_config.assets_path) do
        if cancel then break end
        if not vim.tbl_contains(used_assets, name) then
            if not all then
                vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to %s file(s) or 'c' to cancel (default 'n'): "):format(name, text1), }, function(input)
                    vim.cmd.redraw()
                    if input == 'y' then
                        if mv then uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name)) end
                        if del then vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name)) end
                        vim.notify(("Mdn: %s '%s'. Press any key to continue..."):format(text2, name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    elseif input == 'a' then
                        if mv then uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name)) end
                        if del then vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name)) end
                        all = true
                    elseif input == 'c' then
                        cancel = true
                        vim.notify(("Mdn: Cancelled command. Press any key to continue..."):format(name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    elseif input == 'n' or '' then
                        vim.notify(("Mdn: Skipped '%s'. Press any key to continue..."):format(name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    else
                        vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue..."):format(input), vim.log.levels.ERROR)
                        vim.fn.getchar()
                    end
                end)
            else
                if mv then uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name)) end
                if del then vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name)) end
            end
        end
    end

    vim.cmd.redraw()
    vim.notify(("Mdn: Finished %s process."):format(text1), vim.log.levels.INFO)
end

function M.delete_unused()
    move_delete("delete")
end

function M.move_unused()
    move_delete("move")
end

function M.download_website_html()
    local validate_tbl = require('mdnotes.inline_link').validate(true, nil, true) or {}
    local uri_website_tbl = require('mdnotes.inline_link').uri_website_tbl or {}
    local mdnotes_config = require('mdnotes').config
    local _, uri, _, _, _, _ = unpack(validate_tbl)
    local filename = ""
    local filepath = ""
    local res = nil

    if not uri then return end

    if not vim.tbl_contains(uri_website_tbl, uri:match("%w+")) then
        vim.notify("Mdn: Detected inline link does not contain website link", vim.log.levels.ERROR)
        return nil
    end

    vim.notify(("Mdn: Downloading '%s' website html..."):format(uri), vim.log.levels.INFO)

    -- Create a filename of max 72 characters
    filename = uri:gsub("[:/#?.()%[%]]+", "_") .. ".html"
    filepath = vim.fs.joinpath(mdnotes_config.assets_path, filename)

    if vim.fn.executable('curl') ~= 1 then
        vim.notify("Mdn: The 'curl' utility was not detected", vim.log.levels.ERROR)
        return nil
    end

    vim.system(
        {"curl", "-Ls", uri},
        {text = true},
        function(obj)
            if obj.code == 0 then
                res = obj.stdout
            end
        end
    ):wait()

    if res then
        vim.fn.writefile(vim.split(res, "\n"), filepath)
        vim.notify(("Mdn: Saved '%s' to '%s'"):format(uri, filepath), vim.log.levels.INFO)
    else
        vim.notify("Mdn: Error with request response", vim.log.levels.ERROR)
    end
end

return M
