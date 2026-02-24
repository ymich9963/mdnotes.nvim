---@module 'mdnotes.assets'

local M = {}

local uv = vim.loop or vim.uv

---Resolve the assets path from the config
---@return string path Assets path
function M.get_assets_folder_name()
    local config_assets_path = require('mdnotes').config.assets_path
    local ret = ""

    if type(config_assets_path) == "function" then
        ret = config_assets_path()
    elseif type(config_assets_path) == "string" then
        ret = config_assets_path
    end

    return vim.fs.normalize(ret)
end

---Check if assets path is available and if it exists
function M.check_assets_path()
    local mdnotes = require('mdnotes')
    local mdnotes_assets_path = M.get_assets_folder_name()
    local mdnotes_cwd = mdnotes.cwd
    if mdnotes_assets_path == "" then
        vim.notify("Mdn: Please specify assets path to use this feature", vim.log.levels.ERROR)
        return false
    end

    if vim.fn.isdirectory(vim.fs.joinpath(mdnotes_cwd, mdnotes_assets_path)) == 0 then
        vim.notify("Mdn: Assets path '".. mdnotes_assets_path .. "' in '" .. mdnotes_cwd .. "' doesn't exist - change path or create it", vim.log.levels.ERROR)
        return false
    end

    return true
end

---Open assets folder
function M.open_containing_folder()
    if M.check_assets_path() == false then return end
    local mdnotes = require('mdnotes')
    vim.ui.open(vim.fs.joinpath(mdnotes.cwd, M.get_assets_folder_name()))
end

local function get_file_paths_from_cmd()
    local scripts_path = vim.fs.joinpath(require('mdnotes').plugin_install_dir, "scripts")
    local linux_script = vim.fs.joinpath(scripts_path, "get_file_path_from_clipboard.sh")
    local windows_script = vim.fs.joinpath(scripts_path, "get_file_path_from_clipboard.ps1")
    local macos_script = vim.fs.joinpath(scripts_path, "get_file_path_from_clipboard.scpt")
    local cmd_stdout = ""
    local file_paths = {}

    if vim.fn.has("win32") == 1 then
        cmd_stdout = vim.system({'cmd.exe', '/c', 'powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', windows_script}, { text = true }):wait().stdout
    elseif vim.fn.has("linux") == 1 then
        cmd_stdout = vim.system({'bash', linux_script}, { text = true }):wait().stdout
    elseif vim.fn.has("mac") == 1 then
        cmd_stdout = vim.system({"osascript", macos_script}, { text = true }):wait().stdout
    end

    if cmd_stdout ~= "" then
        file_paths = vim.split( cmd_stdout, '\n')
    end

    return file_paths, cmd_stdout
end

---Process the asset file in clipboard based on config options
---@param file_path string File path of asset file
---@return string|nil file_name Return file name on success
function M.process_inserted_asset_file(file_path)
    vim.validate("file_path", file_path, "string")

    local mdnotes_assets_path = M.get_assets_folder_name()
    local mdnotes_config = require('mdnotes').config
    local file_name = vim.fs.basename(file_path)

    -- Check overwrite behaviour
    if uv.fs_stat(vim.fs.joinpath(mdnotes_assets_path, file_name)) then
        if mdnotes_config.asset_overwrite_behaviour == "error" then
            vim.notify(("Mdn: File you are trying to place into your assets already exists"), vim.log.levels.ERROR)
            return nil
        elseif mdnotes_config.asset_overwrite_behaviour == "overwrite" then
            -- Do nothing on overwrite
        end
    end

    -- Check insert behaviour
    if mdnotes_config.asset_insert_behaviour == "copy" then
        if not uv.fs_copyfile(file_path, vim.fs.joinpath(mdnotes_assets_path, file_name)) then
            vim.notify(("Mdn: File copy failed"), vim.log.levels.ERROR)
            return nil
        end

        vim.notify(('Mdn: Copied "%s" to your assets folder at "%s"'):format(file_path, mdnotes_assets_path), vim.log.levels.INFO)
    elseif mdnotes_config.asset_insert_behaviour == "move" then
        if not uv.fs_rename(file_path, vim.fs.joinpath(mdnotes_assets_path, file_name)) then
            vim.notify(("Mdn: File move failed."), vim.log.levels.ERROR)
            return nil
        end

        vim.notify(('Mdn: Moved "%s" to your assets folder at "%s"'):format(file_path, mdnotes_assets_path), vim.log.levels.INFO)
    end

    return file_name
end

---@class MdnAssetsGetAssetInlineLink
---@field is_image boolean? If inserted file is an image
---@field file_path string? Path of file to insert
---@field process_file boolean? If file should be processed or not

---Create the asset inline link
---@param opts MdnAssetsGetAssetInlineLink?
---@return string|nil text
function M.get_asset_inline_link(opts)
    opts = opts or {}

    local is_image = opts.is_image or false
    local process_file = opts.process_file or false
    local file_path = opts.file_path or ""

    vim.validate("is_image", is_image, "boolean")
    vim.validate("process_file", process_file, "boolean")
    vim.validate("file_path", file_path, "string")

    local asset_path = ""
    local file_name = nil

    if file_path == "" then
        -- Get the file paths as a table
        local file_paths, cmd_stdout = get_file_paths_from_cmd()

        -- Remove blank entries
        for i, v in ipairs(file_paths) do
            if not v:match("%S") then
                table.remove(file_paths, i)
            end
        end

        if vim.tbl_isempty(file_paths) then
            vim.notify("Mdn: Error when trying to read clipboard. Output of command: '" .. cmd_stdout .. '"', vim.log.levels.WARN)
            return
        end

        if #file_paths > 1 then
            vim.notify('Mdn: Too many files paths detected - please copy only one file', vim.log.levels.WARN)
            return
        end

        if file_paths[1] == nil then
            vim.notify('Mdn: No file paths found in clipboard', vim.log.levels.WARN)
            return
        end

        file_path = vim.fs.normalize(file_paths[1])
    end

    -- Copy/move the asset file to the assets directory
    if process_file == true then
        file_name = M.process_inserted_asset_file(file_path)
        if file_name == nil then return end
    elseif process_file == false then
        file_name = vim.fs.basename(file_path)
    end
    asset_path = vim.fs.joinpath(M.get_assets_folder_name(), file_name)

    -- Create the new assets path
    if asset_path:match("%s") then
        asset_path = "<" .. asset_path .. ">"
    end

    local inline_link = ("[%s](%s)"):format(file_name, asset_path)

    if is_image == true then
        inline_link = "!" .. inline_link
    end

    return inline_link
end

---Insert a file as an inline link
function M.insert_file()
    if M.check_assets_path() == false then return end
    local inline_link = M.get_asset_inline_link({
        is_image = false,
        process_file = true
    })
    vim.api.nvim_put({inline_link}, "c", false, false)
end

---Insert an image as an inline link
function M.insert_image()
    if M.check_assets_path() == false then return end
    local inline_link = M.get_asset_inline_link({
        is_image = true,
        process_file = true
    })
    vim.api.nvim_put({inline_link}, "c", false, false)
end

---Get the assets that are already used in the notes
---@param opts {silent: boolean?}? opts.silent: Silence notifications
---@return table<string>
function M.get_used_assets(opts)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local mdnotes = require('mdnotes')
    local cwd = mdnotes.cwd
    local uri = ""
    local used_assets = {}
    local temp_qflist = vim.fn.getqflist()

    -- Vimgrep inline links with asset paths with no spaces
    vim.cmd.vimgrep({args = {"/](<\\?" .. M.get_assets_folder_name() .. "\\//", vim.fs.joinpath(cwd, "*")}, mods = {emsg_silent = true}})
    local assets_list = vim.fn.getqflist()

    for _, v in ipairs(assets_list) do
        for _, inline_link, _ in v.text:gmatch(require("mdnotes.patterns").inline_link) do
            _, uri = inline_link:match(require("mdnotes.patterns").text_uri)

            -- Remove any < or > from uri
            uri = uri:gsub("[<>]?", "")

            table.insert(used_assets, vim.fs.basename(uri))
        end
    end

    if silent == false then
        vim.notify("Mdn: Found " .. #used_assets .. " used assets", vim.log.levels.INFO)
    end

    vim.fn.setqflist(temp_qflist)
    return used_assets
end

---@param opts {silent: boolean?}? opts.silent: Silence notifications
---@return table<string>
function M.get_unused_assets(opts)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local mdnotes = require('mdnotes')
    local assets_path = vim.fs.joinpath(mdnotes.cwd, M.get_assets_folder_name())
    local unused_assets = {}
    for name, _ in vim.fs.dir(assets_path) do
        if vim.tbl_contains(M.get_used_assets({silent = true}), name) == false then
            table.insert(unused_assets, name)
        end
    end

    if silent == false then
        vim.notify("Mdn: Found " .. #unused_assets .. " unused assets", vim.log.levels.INFO)
    end

    return unused_assets
end

---Move or delete assets
---@param action '"move"'|'"delete"' Select to move or delete the assets
---@param skip_input boolean? Skip the user input prompt
local function process_unused_assets(action, skip_input)
    if M.check_assets_path() == false then return end
    if skip_input == nil then skip_input = false end

    local mdnotes = require('mdnotes')
    local mdnotes_cwd = mdnotes.cwd
    local unused_assets_path = vim.fs.normalize(vim.fs.joinpath(mdnotes_cwd, M.get_assets_folder_name(), "../unused_assets"))
    local all, cancel = false, false
    local user_input = ""
    local text1, text2 = "", ""

    if action == "move" then
        -- Create directory if it does not exist
        if vim.fn.isdirectory(unused_assets_path) == 0 then
            uv.fs_mkdir(unused_assets_path, tonumber('777', 8))
        end
        text1, text2 = "move", "Moved"
    elseif action == "delete" then
        text1, text2 = "delete", "Deleted"
    else
        return
    end

    -- Function to make for-loop easier to read
    local function action_func(file_assets_path, file_unused_assets_path)
        if action == "move" then
            return uv.fs_rename(file_assets_path, file_unused_assets_path)
        elseif action == "delete" then
            return vim.fs.rm(file_assets_path)
        end
    end

    vim.notify(("Mdn: Starting the %s assets process..."):format(text1), vim.log.levels.INFO)

    for _, name in ipairs(M.get_unused_assets()) do
        local file_assets_path = vim.fs.joinpath(mdnotes.cwd, M.get_assets_folder_name(), name)
        local file_unused_assets_path = vim.fs.joinpath(unused_assets_path, name)
        if cancel == true then break end
        if all == false and skip_input == false then
            vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to %s file(s) or 'c' to cancel (default 'n'): "):format(name, text1), }, function(input)
                user_input = input
            end)
            vim.cmd.redraw()
            if user_input == 'y' then
                action_func(file_assets_path, file_unused_assets_path)
                vim.notify(("Mdn: %s '%s'. Press any key to continue..."):format(text2, name), vim.log.levels.WARN)
            elseif user_input == 'a' then
                all = true
                action_func(file_assets_path, file_unused_assets_path)
                vim.notify(("Mdn: Process will be done for all corresponding files. Press any key to continue..."):format(name), vim.log.levels.WARN)
            elseif user_input == 'c' then
                cancel = true
                vim.notify(("Mdn: Cancelled command. Press any key to continue..."):format(name), vim.log.levels.WARN)
            elseif user_input == 'n' or '' then
                vim.notify(("Mdn: Skipped '%s'. Press any key to continue..."):format(name), vim.log.levels.WARN)
            else
                vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue..."):format(user_input), vim.log.levels.ERROR)
            end
            vim.fn.getchar()
        else
            action_func(file_assets_path, file_unused_assets_path)
        end
    end

    vim.cmd.redraw()
    vim.notify(("Mdn: Finished %s process"):format(text1), vim.log.levels.INFO)
end

---Delete unused assets
---@param opts {skip_input: boolean?}? opts.skip_input: Skip the user input prompt
function M.unused_delete(opts)
    opts = opts or {}
    local skip_input = opts.skip_input or false
    vim.validate("skip_input", skip_input, "boolean")

    process_unused_assets("delete", skip_input)
end

---Move unused assets to a new folder
---@param opts {skip_input: boolean?}? opts.skip_input: Skip the user input prompt
function M.unused_move(opts)
    opts = opts or {}
    local skip_input = opts.skip_input or false
    vim.validate("skip_input", skip_input, "boolean")

    process_unused_assets("move", skip_input)
end

---Download the the HTML of the inline link URL and place it in assets folder
---@param opts {uri: string?}? opts.uri: URI with a valid URL to download the HTML from
function M.download_website_html(opts)
    opts = opts or {}
    local uri = opts.uri

    if uri == nil then
        uri = (require('mdnotes.inline_link').parse()).uri
    end

    vim.validate("uri", uri, "string")

    local uri_website_tbl = require('mdnotes.inline_link').uri_website_tbl or {}
    local mdnotes = require('mdnotes')
    local filename, filepath = "", ""
    local res = nil

    -- Notifications should alredy be outputted
    if uri == nil then return end

    if not vim.tbl_contains(uri_website_tbl, uri:match("%w+")) then
        vim.notify("Mdn: Detected inline link does not contain website link", vim.log.levels.ERROR)
        return nil
    end

    vim.notify(("Mdn: Downloading '%s' website html..."):format(uri), vim.log.levels.INFO)

    -- Create a filename of max 72 characters
    filename = uri:gsub("[:/#?.()%[%]]+", "_") .. ".html"
    filepath = vim.fs.joinpath(mdnotes.cwd, M.get_assets_folder_name(), filename)

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

---Delete the asset under the cursor
---@param opts {uri: string?, skip_input: boolean?}?
function M.delete(opts)
    opts = opts or {}
    local uri = opts.uri
    local skip_input = opts.skip_input or false
    vim.validate("skip_input", skip_input, "boolean")

    local _, text, uri_il, col_start, col_end
    if uri == nil then
        local ildata = require('mdnotes.inline_link').parse()
        text, uri, col_start, col_end = ildata.text, ildata.uri, ildata.col_start, ildata.col_end
        if uri == nil then return end
    end

    vim.validate("uri", uri, "string")

    local asset_path = require('mdnotes.inline_link').get_path_from_uri(uri, true)
    if asset_path == nil then return -2 end

    local mdnotes = require('mdnotes')
    local behaviour = mdnotes.config.asset_delete_behaviour
    local garbage_path = vim.fs.normalize(vim.fs.joinpath(mdnotes.cwd, M.get_assets_folder_name(), "../garbage"))
    local asset_name = vim.fs.basename(asset_path)
    local prompt = "Type y/n/a(ll) to %s file(s) or 'c' to cancel (default 'n'): "
    local user_input = ""
    local text1 = ""
    local lnum = vim.fn.line('.')
    local cur_col = vim.fn.col('.')
    local deleted = false

    if behaviour == "delete" then
        prompt = "Delete file at '" .. asset_path .. "'. " .. prompt
        text1 = "Deleted"
    elseif behaviour == "garbage" then
        prompt = "Move file at '" .. asset_path .. "' to garbage folder. " .. prompt
        text1 = "Moved"

        -- Create directory if it does not exist
        if vim.fn.isdirectory(garbage_path) == 0 then
            uv.fs_mkdir(garbage_path, tonumber('777', 8))
        end
    else
        return
    end

    if skip_input == false then
        vim.ui.input( { prompt = prompt, }, function(input)
            user_input = input
        end)
        vim.cmd.redraw()
    elseif skip_input == true then
        user_input = 'y'
    end

    if user_input == 'y' then
        if behaviour == "remove" then
            vim.fs.rm(asset_path)
        elseif behaviour == "garbage" then
            uv.fs_rename(asset_path, vim.fs.joinpath(garbage_path, asset_name))
        end
        vim.notify(("Mdn: %s '%s'"):format(text1, asset_path), vim.log.levels.WARN)
        deleted = true
    elseif user_input == 'n' or '' then
        vim.notify(("Mdn: Skipped '%s'"):format(asset_path), vim.log.levels.WARN)
    else
        vim.notify(("Mdn: Unknown input '%s'"):format(user_input), vim.log.levels.ERROR)
    end

    if uri_il ~= nil and deleted == true then
        local new_col = cur_col - 2
        if new_col < 1 then new_col = 1 end

        -- Set the line and cursor position
        vim.api.nvim_buf_set_text(0, lnum - 1, col_start - 1, lnum - 1, col_end - 1, {text})
        vim.fn.cursor({lnum, new_col})
    end

    return deleted, asset_path
end

return M
