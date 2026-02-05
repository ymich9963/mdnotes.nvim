---@module 'mdnotes.assets'
local M = {}

local uv = vim.loop or vim.uv

---Check if assets path is available and if it exists
function M.check_assets_path()
    local mdnotes_config_assets_path = require('mdnotes').config.assets_path
    if mdnotes_config_assets_path == "" or mdnotes_config_assets_path == nil then
        vim.notify(("Mdn: Please specify assets path to use this feature"), vim.log.levels.ERROR)
        return false
    end

    if vim.fn.isdirectory(mdnotes_config_assets_path) == 0 then
        vim.notify(("Mdn: Assets path %s doesn't exist - change path or create it"):format(mdnotes_config_assets_path), vim.log.levels.ERROR)
        return false
    end

    return true
end

---Open assets folder
function M.open_containing_folder()
    if not M.check_assets_path() then return end

    -- There might be issues with code below, see issue
    -- https://github.com/neovim/neovim/issues/36293
    vim.ui.open(require('mdnotes').config.assets_path)
end

---Insert a file or image as an inline link
---@param is_image boolean? File type to insert
local function insert_file(is_image)
    if not M.check_assets_path() then return end

    if is_image == nil then is_image = false end

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
        -- Try to get file path first (when user copies a file from Finder)
        local result = vim.system({"osascript", "-e", "set f to the clipboard as alias", "-e", "POSIX path of f"}, { text = true }):wait()
        cmd_stdout = result.stdout

        -- If getting file path failed (exit code != 0), check what's in the clipboard
        if result.code ~= 0 then
            -- Check if clipboard contains image data (not text or other types)
            local clipboard_check = vim.system({"osascript", "-e", "clipboard info"}, { text = true }):wait()
            local has_image_data = clipboard_check.stdout:match("«class PNGf»") or
                                   clipboard_check.stdout:match("«class TPIC»") or
                                   clipboard_check.stdout:match("TIFF picture")

            -- Only try pngpaste if we're inserting an image AND clipboard has image data
            if file_type == "image" and has_image_data then
                -- Check if pngpaste is available
                local pngpaste_check = vim.system({"which", "pngpaste"}, { text = true }):wait()
                if pngpaste_check.code == 0 then
                    local mdnotes_config = require('mdnotes').config

                    -- Generate a unique filename for the clipboard image with nanosecond precision
                    -- Format: clipboard_image_YYYYMMDD_HHMMSS_NNNNNNNNN.png (nanoseconds for uniqueness)
                    local temp_filename = nil
                    local dest_path = nil
                    local attempt = 0
                    local max_attempts = 100

                    -- Keep trying until we find a unique filename or reach max attempts
                    repeat
                        if attempt == 0 then
                            -- First attempt: use timestamp with nanoseconds
                            local timestamp = os.date("%Y%m%d_%H%M%S")
                            local nanoseconds = string.format("%d", uv.hrtime()):sub(-9)  -- Get nanosecond precision
                            temp_filename = ("clipboard_image_%s_%s.png"):format(timestamp, nanoseconds)
                        else
                            -- Subsequent attempts: add counter
                            local timestamp = os.date("%Y%m%d_%H%M%S")
                            local nanoseconds = string.format("%d", uv.hrtime()):sub(-9)
                            temp_filename = ("clipboard_image_%s_%s_%d.png"):format(timestamp, nanoseconds, attempt)
                        end

                        dest_path = vim.fs.joinpath(mdnotes_config.assets_path, temp_filename)
                        attempt = attempt + 1
                    until not uv.fs_stat(dest_path) or attempt >= max_attempts

                    -- Check if file exists after attempting to find unique filename
                    -- This only happens if we hit max_attempts without finding a unique name
                    if uv.fs_stat(dest_path) then
                        if mdnotes_config.asset_overwrite_behaviour == "error" then
                            vim.notify(("Mdn: Could not generate unique filename after %d attempts."):format(max_attempts), vim.log.levels.ERROR)
                            return
                        -- else: asset_overwrite_behaviour == "overwrite"
                        -- Allow pngpaste to overwrite the existing file (continue execution)
                        end
                    end

                    -- Use pngpaste to save clipboard image directly to assets folder
                    local paste_result = vim.system({"pngpaste", dest_path}, { text = true }):wait()
                    if paste_result.code == 0 then
                        -- Successfully saved image from clipboard
                        -- Create and insert the markdown image link (handle spaces like existing code)
                        local text = ""
                        if contains_spaces(dest_path) then
                            text = ("![%s](<%s>)"):format(temp_filename, dest_path)
                        else
                            text = ("![%s](%s)"):format(temp_filename, dest_path)
                        end
                        vim.api.nvim_put({text}, "c", false, false)
                        vim.notify(('Mdn: Saved clipboard image to "%s".'):format(dest_path), vim.log.levels.INFO)
                        return
                    else
                        vim.notify("Mdn: Failed to paste image from clipboard. Error: " .. (paste_result.stderr or "unknown"), vim.log.levels.ERROR)
                        return
                    end
                else
                    vim.notify("Mdn: Clipboard contains image data, but 'pngpaste' is not installed. Install it with: brew install pngpaste", vim.log.levels.ERROR)
                    return
                end
            else
                -- Clipboard doesn't contain file path or image data
                -- It might contain text (like a copied file path string)
                if file_type == "image" then
                    vim.notify("Mdn: Clipboard doesn't contain a file reference or image data. Try:\n  - Copy a file from Finder (⌘C on a file)\n  - Take a screenshot (⌘⇧⌃4)\n  - Copy an image from an app", vim.log.levels.ERROR)
                else
                    vim.notify("Mdn: Clipboard doesn't contain a file reference. Try copying a file from Finder.", vim.log.levels.ERROR)
                end
                return
            end
        end
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
        vim.notify('Mdn: Too many files paths detected - please select only one file', vim.log.levels.WARN)
        return
    end

    -- Exit if none found
    if file_paths[1] == 'None' or nil then
        vim.notify('Mdn: No file paths found in clipboard', vim.log.levels.WARN)
        return
    end

    local file_path = vim.fs.normalize(file_paths[1])
    local file_name = vim.fs.basename(file_path)
    local mdnotes_config = require('mdnotes').config

    -- Check overwrite behaviour
    if uv.fs_stat(vim.fs.joinpath(mdnotes_config.assets_path, file_name)) then
        if mdnotes_config.asset_overwrite_behaviour == "error" then
            vim.notify(("Mdn: File you are trying to place into your assets already exists"), vim.log.levels.ERROR)
            return
        elseif mdnotes_config.asset_overwrite_behaviour == "overwrite" then
        end
    end

    if mdnotes_config.asset_insert_behaviour == "copy" then
        if not uv.fs_copyfile(file_path, vim.fs.joinpath(mdnotes_config.assets_path, file_name)) then
            vim.notify(("Mdn: File copy failed"), vim.log.levels.ERROR)
            return
        else
            vim.notify(('Mdn: Copied "%s" to your assets folder at "%s"'):format(file_path, mdnotes_config.assets_path), vim.log.levels.INFO)
        end
    elseif mdnotes_config.asset_insert_behaviour == "move" then
        if not uv.fs_rename(file_path, vim.fs.joinpath(mdnotes_config.assets_path, file_name)) then
            vim.notify(("Mdn: File move failed."), vim.log.levels.ERROR)
            return
        else
            vim.notify(('Mdn: Moved "%s" to your assets folder at "%s"'):format(file_path, mdnotes_config.assets_path), vim.log.levels.INFO)
        end
    end

    -- Create file link
    local asset_path = vim.fs.joinpath(mdnotes_config.assets_path, file_name)
    local text = ""

    if asset_path:match("%s") then
        text = ("[%s](<%s>)"):format(file_name, asset_path)
    else
        text = ("[%s](%s)"):format(file_name, asset_path)
    end

    if is_image == true then
        text = "!" .. text
    end

    vim.api.nvim_put({text}, "c", false, false)
end

---Insert an image as an inline link
function M.insert_image()
    insert_file(true)
end

---Insert a file as an inline link
function M.insert_file()
    insert_file()
end

---Get the assets that are already used in the notes
---@param silent boolean? Silent output to cmdline
---@return table<string>
local function get_used_assets(silent)
    if silent == nil then silent = false end
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

---Move or delete assets
---@param move_or_delete '"move"'|'"delete"' Select to move or delete the assets
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
        if cancel == true then break end
        if vim.tbl_contains(used_assets, name) == false then
            if all == false then
                vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to %s file(s) or 'c' to cancel (default 'n'): "):format(name, text1), }, function(input)
                    vim.cmd.redraw()
                    if input == 'y' then
                        if mv then uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name)) end
                        if del then vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name)) end
                        vim.notify(("Mdn: %s '%s'. Press any key to continue..."):format(text2, name), vim.log.levels.WARN)
                    elseif input == 'a' then
                        if mv then uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name)) end
                        if del then vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name)) end
                        all = true
                        vim.notify(("Mdn: Process will be done for all corresponding files. Press any key to continue..."):format(name), vim.log.levels.WARN)
                    elseif input == 'c' then
                        cancel = true
                        vim.notify(("Mdn: Cancelled command. Press any key to continue..."):format(name), vim.log.levels.WARN)
                    elseif input == 'n' or '' then
                        vim.notify(("Mdn: Skipped '%s'. Press any key to continue..."):format(name), vim.log.levels.WARN)
                    else
                        vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue..."):format(input), vim.log.levels.ERROR)
                    end
                    vim.fn.getchar()
                end)
            else
                if mv then uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name)) end
                if del then vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name)) end
            end
        end
    end

    vim.cmd.redraw()
    vim.notify(("Mdn: Finished %s process"):format(text1), vim.log.levels.INFO)
end

---Delete unused assets
function M.delete_unused()
    move_delete("delete")
end

---Move unused assets to a new folder
function M.move_unused()
    move_delete("move")
end

---Download the the HTML of the inline link URL and place it in assets folder
function M.download_website_html()
    local uri_website_tbl = require('mdnotes.inline_link').uri_website_tbl or {}
    local mdnotes_config = require('mdnotes').config
    local _, _, uri, _, _, _, _ = require('mdnotes.inline_link').get_inline_link_data(nil, true)
    local filename = ""
    local filepath = ""
    local res = nil

    if uri == nil then return end

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
