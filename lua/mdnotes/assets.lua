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
    vim.ui.open(require('mdnotes.config').config.assets_path)
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

function M.cleanup_unused()
    if not M.check_assets_path() then return end

    vim.notify(("Mdn: Starting cleanup process..."), vim.log.levels.INFO)

    local temp_qflist = vim.fn.getqflist()
    local mdnotes_config = require('mdnotes').config
    local cleanup_all = false
    local cancel = false
    for name, _ in vim.fs.dir(mdnotes_config.assets_path) do
        if cancel then break end

        vim.cmd.vimgrep({args = {'/\\](' .. mdnotes_config.assets_path .. '\\/' .. name .. ')/', '*'}, mods = {emsg_silent = true}})

        if vim.tbl_isempty(vim.fn.getqflist()) then
            if not cleanup_all then
                vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to delete file(s) or 'c' to cancel (default 'n'): "):format(name), }, function(input)
                    vim.cmd.redraw()
                    if input == 'y' then
                        vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name))
                        vim.notify(("Mdn: Removed '%s'. Press any key to continue..."):format(name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    elseif input == 'a' then
                        vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name))
                        cleanup_all = true
                    elseif input == 'c' then
                        cancel = true
                        vim.notify(("Mdn: Cancelled cleanup. Press any key to continue..."):format(name), vim.log.levels.WARN)
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
                vim.fs.rm(vim.fs.joinpath(mdnotes_config.assets_path, name))
            end
        end
    end

    vim.fn.setqflist(temp_qflist)
    vim.cmd.redraw()
    vim.notify(("Mdn: Finished cleanup."), vim.log.levels.INFO)
end

function M.move_unused()
    if not M.check_assets_path() then return end

    vim.notify(("Mdn: Starting move process..."), vim.log.levels.INFO)

    local mdnotes_config = require('mdnotes').config
    local unused_assets_path = vim.fs.normalize(vim.fs.joinpath(mdnotes_config.assets_path, "../unused_assets"))

    if vim.fn.isdirectory(unused_assets_path) == 0 then
        uv.fs_mkdir(unused_assets_path, tonumber('777', 8))
    end

    local temp_qflist = vim.fn.getqflist()
    local move_all = false
    local cancel = false
    for name, _ in vim.fs.dir(mdnotes_config.assets_path) do
        if cancel then break end

        vim.cmd.vimgrep({args = {'/\\](' .. mdnotes_config.assets_path .. '\\/' .. name .. ')/', '*'}, mods = {emsg_silent = true}})

        if not vim.tbl_isempty(vim.fn.getqflist()) then
            if not move_all then
                vim.ui.input( { prompt = ("Mdn: File '%s' not linked anywhere. Type y/n/a(ll) to move file(s) or 'c' to cancel (default 'n'): "):format(name), }, function(input)
                    vim.cmd.redraw()
                    if input == 'y' then
                        uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name))
                        vim.notify(("Mdn: Moved '%s'. Press any key to continue..."):format(name), vim.log.levels.WARN)
                        vim.fn.getchar()
                    elseif input == 'a' then
                        uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name))
                        move_all = true
                    elseif input == 'c' then
                        cancel = true
                        vim.notify(("Mdn: Cancelled move. Press any key to continue..."):format(name), vim.log.levels.WARN)
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
                uv.fs_rename(vim.fs.joinpath(mdnotes_config.assets_path, name), vim.fs.joinpath(unused_assets_path, name))
            end
        end
    end

    vim.fn.setqflist(temp_qflist)
    vim.cmd.redraw()
    vim.notify(("Mdn: Finished cleanup."), vim.log.levels.INFO)
end

return M
