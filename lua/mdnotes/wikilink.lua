---@module 'mdnotes.wikilink'

local M = {}

local uv = vim.loop or vim.uv

---@type table<string>
M.old_filenames = {}

---@type table<string>
M.new_filenames = {}

---@class MdnWikiLinkData: MdnText
---@field file string WikiLink file
---@field fragment string The fragment in the WikiLink
---@field alias string WikiLink alias

local check_markdown_lsp_cur_buf = function() return require('mdnotes').check_markdown_lsp_cur_buf() end
local get_buf_from_buf_list = function(...) return require('mdnotes').get_buf_from_buf_list(...) end

---Parse WikiLink
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
---@return MdnWikiLinkData?
function M.parse(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local wikilink = opts.wikilink

    vim.validate("wikilink", wikilink, "string", true)

    local mdn_patterns = require('mdnotes.patterns')
    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local txtdata = {}

    -- Overwrite if location is given
    if opts.location ~= nil or wikilink == nil then
        if not check_markdown_syntax(mdn_patterns.wikilink, {location = opts.location}) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(mdn_patterns.wikilink, { location = opts.location })
        wikilink = txtdata.raw or ""
    end

    local wikilink_contents = wikilink:match(mdn_patterns.wikilink_contents)
    local wikilink_no_fragment = wikilink_contents:match(mdn_patterns.dest_no_fragment)
    local fragment = wikilink_contents:match(mdn_patterns.fragment)
    local alias = wikilink_contents:match(mdn_patterns.wikilink_alias)

    return vim.tbl_extend("force", {
        file = wikilink_no_fragment,
        fragment = fragment,
        alias = alias,
    }, txtdata)
end

---Follow the WikiLink under the cursor
---@param opts {wikilink: string?, location: MdnInLineLocation?, hor: boolean?, vert: boolean?, picker: boolean?}?
function M.follow(opts)
    if check_markdown_lsp_cur_buf() then
        vim.lsp.buf.definition()

        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local wikilink = opts.wikilink
    local hor = opts.hor or false
    local vert = opts.vert or false
    local picker = opts.picker or false

    local wldata
    if wikilink == nil then
        wldata = M.parse({ location = opts.location })
    else
        wldata = M.parse({ wikilink = wikilink })
    end

    if wldata == nil and picker == true then
        wldata = M.picker(function(sel_obj) M.follow({ wikilink = sel_obj.raw }) end, buf)
    end

    if wldata == nil then return end

    local cwd = require('mdnotes').cwd

    if wldata.file ~= "" then
        local path = vim.fs.joinpath(cwd, wldata.file)

        if not vim.endswith(path, ".md") then
            path = path .. ".md"
        end

        require('mdnotes').open_buf(path, {hor = hor, vert = vert})
    end

    if wldata.fragment ~= "" then
        vim.fn.cursor(vim.fn.search(wldata.fragment), 1)
        vim.api.nvim_input('zz')
    end
end

---Follow the WikiLink and split horizontally
---@param opts {wikilink: string?, location: MdnInLineLocation?, picker: boolean?}?
function M.follow_hor(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    M.follow({ wikilink = opts.wikilink, location = opts.location, hor = true, picker = opts.picker})
end

---Follow the WikiLink and split vertically
---@param opts {wikilink: string?, location: MdnInLineLocation?, picker: boolean?}?
function M.follow_vert(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    M.follow({ wikilink = opts.wikilink, location = opts.location, vert = true, picker = opts.picker})
end

---Show the references to the current WikiLink under the cursor
---@param opts {location: MdnInLineLocation?, silent: boolean?}?
---@return table? qflist Resulting quickfix list
function M.show_references(opts)
    if check_markdown_lsp_cur_buf() then
        vim.lsp.buf.references()

        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    local silent = opts.silent or false
    local wldata = M.parse({ location = opts.location })

    if wldata == nil then
        -- If wikilink pattern isn't detected use current file name
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        wldata = {
            buf = vim.api.nvim_get_current_buf(),
            file = cur_file_basename:gsub(".md$",""),
            fragment = "",
            alias = "",
        }
        wldata.raw = "[[" .. wldata.file .. "]]"
    end

    local cur_pos = vim.fn.getpos('.')
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep

    if silent == false then
        vim.notify("Mdn: Searching references for '" .. wldata.raw:sub(3, -3) .. "'...", vim.log.levels.INFO)
    end

    mdn_grep("\\[\\[".. wldata.file .. "(\\.md)?(\\#.*)?\\]\\]", cwd)

    local qflist = vim.fn.getqflist()
    if vim.tbl_isempty(qflist) then
        if silent == false then
            vim.notify("Mdn: No references found for '" .. wldata.raw:sub(3, -3) .. "'", vim.log.levels.ERROR)
        end

        return qflist
    end

    vim.cmd.buffer(wldata.buf)
    vim.fn.setpos('.', cur_pos)
    vim.cmd.copen()

    return qflist
end

---Rename references of the WikiLink under the cursor
---If there is no WikiLink under the cursor, prompt to rename references to
---the current buffer
---@param opts {new_name: string?, location: MdnInLineLocation?, silent: boolean?}?
---@return string? old_name, string|nil new_name 
function M.rename_references(opts)
    if check_markdown_lsp_cur_buf() then
        -- I think this renames the current buffer and
        -- not the symbol under cursor
        vim.lsp.buf.rename()

        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    local silent = opts.silent or false
    local new_name = opts.new_name

    vim.validate("new_name", new_name, "string", true)

    -- Save current position to rever back later
    local cur_buf = vim.api.nvim_get_current_buf()
    local pos = vim.fn.getpos('.')

    local temp_qflist = vim.fn.getqflist()
    local prompt = "Rename WikiLink and file: "
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep
    local wldata = M.parse({ location = opts.location })

    if wldata == nil then
        prompt = "Rename current buffer: "
        wldata = {
            file = vim.fs.basename(vim.api.nvim_buf_get_name(0)):match("(.+)%.[^%.]+$"),
            fragment = "",
            alias = "",
        }
        wldata.raw = "[[" .. wldata.file .. "]]"
    end

    -- Remove the file extension for this function
    if vim.endswith(wldata.file, ".md") then
        wldata.file = wldata.file:sub(1,-4)
    end

    -- Check if it exists
    local filepath = vim.fs.normalize(vim.fs.joinpath(cwd, wldata.file .. ".md"))
    if not uv.fs_stat(filepath) then
        if silent == false then
            vim.notify("Mdn: WikiLink does not seem to link to a valid Markdown file", vim.log.levels.ERROR)
        end

        return wldata.file, "invalid file"
    end

    -- Prompt for new name and check if valid
    if new_name == nil then
        vim.ui.input({ prompt = prompt, default = wldata.file },
        function(input)
            new_name = input
        end)

        if new_name == "" or new_name == nil then
            if silent == false then
                vim.notify("Mdn: Please insert a valid name", vim.log.levels.ERROR)
            end

            return wldata.file, "invalid name"
        end
    end

    if silent == false then
        vim.notify("Mdn: Renaming references of '" .. wldata.raw:sub(3, -3) .. "' to '" .. new_name .. "'", vim.log.levels.INFO)
    end

    -- Change all [[WikiLink]] text to be the new name
    mdn_grep("\\[\\[".. wldata.file .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
    vim.cmd.cdo({args = {('s/%s/%s/'):format("\\[\\[" .. wldata.file, "\\[\\[" .. new_name)}, mods = {emsg_silent = true, noautocmd = true}})

    -- Get the buffer number of the renamed file if it is in the buffer list
    local renamed_bufnum = get_buf_from_buf_list(wldata.file .. ".md")

    -- If the buffer number of the renamed file is in the buffer list
    if renamed_bufnum ~= nil then
        if renamed_bufnum ~= cur_buf then
            vim.api.nvim_buf_delete(renamed_bufnum, {force = true})
        elseif renamed_bufnum == cur_buf then
            vim.api.nvim_buf_set_name(cur_buf, vim.fs.joinpath(cwd, new_name .. ".md"))
        end
    end

    -- Rename and check if succesful
    local ret, err = uv.fs_rename(
        filepath,
        vim.fs.joinpath(cwd, new_name .. ".md")
    )

    if not ret then
        if silent == false then
            vim.notify("Mdn: File rename failed", vim.log.levels.ERROR)
        end

        return wldata.file, err
    end

    table.insert(M.old_filenames, wldata.file)
    table.insert(M.new_filenames, new_name)

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    -- Go back to position where command started
    vim.cmd.buffer(cur_buf)
    vim.fn.setpos('.', pos)

    vim.cmd.write({bang = true, mods = {silent = true}})

    if silent == false then
        vim.notify(("Mdn: Succesfully renamed '%s' links to '%s'"):format(wldata.raw:sub(3, -3), new_name), vim.log.levels.INFO)
    end

    return wldata.file, new_name
end

---Undo the most recent rename
---@param opts {silent: boolean?}?
---@return string? old_name, string|nil new_name 
function M.undo_rename(opts)
    if check_markdown_lsp_cur_buf() then
        vim.notify("Mdn: 'undo_rename' is only available when your config has 'prefer_lsp = false'", vim.log.levels.ERROR)
        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    if vim.tbl_isempty(M.new_filenames) or vim.tbl_isempty(M.old_filenames) then
        if silent == false then
            vim.notify("Mdn: Detected no recent rename", vim.log.levels.ERROR)
        end

        return
    end

    local newest_filename = M.new_filenames[#M.new_filenames]
    local newest_old_filename = M.old_filenames[#M.old_filenames]

    local temp_qflist = vim.fn.getqflist()
    local cur_buf = vim.api.nvim_get_current_buf()
    local cur_pos = vim.fn.getpos('.')
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep

    if silent == false then
        vim.notify("Mdn: Undoing rename...", vim.log.levels.INFO)
    end

    mdn_grep("\\[\\[".. newest_filename .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
    vim.cmd.cdo({args = {('s/%s/%s/'):format(newest_filename, newest_old_filename)}, mods = {emsg_silent = true, noautocmd = true}})

    local ret, err = uv.fs_rename(
        vim.fs.joinpath(cwd, newest_filename .. ".md"),
        vim.fs.joinpath(cwd, newest_old_filename .. ".md")
    )
    if not ret then
        if silent == false then
            vim.notify(("Mdn: Undo file rename failed"), vim.log.levels.ERROR)
        end

        return nil, err
    end

    if silent == false then
        vim.notify(("Mdn: Undo renaming '%s' to '%s'"):format(newest_old_filename, newest_filename), vim.log.levels.INFO)
    end

    -- Get the buffer number of the renamed file if it is in the buffer list
    local renamed_bufnum = get_buf_from_buf_list(newest_old_filename .. ".md")

    -- If the buffer number of the renamed file is in the buffer list
    if renamed_bufnum ~= nil then
        if renamed_bufnum ~= cur_buf then
            vim.api.nvim_buf_delete(renamed_bufnum, {force = true})
        elseif renamed_bufnum == cur_buf then
            vim.api.nvim_buf_set_name(cur_buf, vim.fs.joinpath(cwd, newest_old_filename .. ".md"))
        end
    end

    vim.cmd.buffer(cur_buf)
    vim.fn.setpos('.', cur_pos)

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    table.remove(M.new_filenames)
    table.remove(M.old_filenames)

    return newest_filename, newest_old_filename
end

---Create a WikiLink from the word under the cursor
---@param opts {location: MdnInLineLocation?, move_cursor: boolean?}?
function M.create(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local insert_format = require('mdnotes.formatting').insert_format
    insert_format("[[]]", { split_delimiter = true, location = opts.location, move_cursor = opts.move_cursor })
end

---Delete the current WikiLink and the associated file
---@param opts {location: MdnInLineLocation?, move_cursor: boolean?, skip_input: boolean?}?
---@return boolean deleted, string wikilink Returns whether the file was deleted and the affected WikiLink
function M.delete(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local wldata = M.parse({ location = opts.location })
    if wldata == nil then
        return false, ""
    end

    local skip_input = opts.skip_input or false

    -- Append .md to guarantee a file name
    local found_file = ""
    if not vim.endswith(wldata.file, ".md") then
        found_file = wldata.file .. ".md"
    else
        found_file = wldata.file
    end

    local deleted = false
    local cwd = require('mdnotes').cwd
    local path = vim.fs.normalize(vim.fs.joinpath(cwd, found_file))
    if uv.fs_stat(path) then
        if skip_input == false then
            vim.ui.input( { prompt = ("Mdn: Delete '%s' WikiLink and file? Type y/n (default 'n'): "):format(wldata.file), }, function(input)
                vim.cmd.echo()
                if input == 'y' then
                    vim.fs.rm(path)
                elseif input == 'n' or '' then
                    vim.notify("Mdn: Did not delete WikiLink file", vim.log.levels.WARN)
                else
                    vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue..."):format(input), vim.log.levels.ERROR)
                    vim.fn.getchar()
                end
            end)
        elseif skip_input == true then
            vim.fs.rm(path)
        end
        deleted = true
    else
        vim.notify("Mdn: WikiLink file not found so proceeding to remove text only", vim.log.levels.WARN)
    end

    vim.api.nvim_buf_set_text(wldata.buf, wldata.lnum - 1, wldata.col_start - 1, wldata.lnum - 1, wldata.col_end - 1, {wldata.file})

    return deleted, wldata.file
end

---Normalize the WikiLink under the cursor
---@param opts {location: MdnInLineLocation?, move_cursor: boolean?}?
function M.normalize(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false

    local wldata = M.parse({ location = opts.location })
    if wldata == nil then return end

    local new_wikilink = vim.fs.normalize(wldata.file)

    if wldata.fragment ~= nil then
        new_wikilink = new_wikilink .. '#' .. wldata.fragment
    end

    vim.api.nvim_buf_set_text(wldata.buf, wldata.lnum - 1, wldata.col_start - 1, wldata.lnum - 1, wldata.col_end - 1, {"[[" .. new_wikilink .. "]]"})

    if move_cursor == true then
        vim.cmd.buffer(wldata.buf)
        vim.fn.cursor({wldata.lnum, wldata.cur_col})
    end
end

---Get any orphan pages in the cwd
---@param opts {silent: boolean?}?
---@return table<string> orphans Table of orphan pages
function M.get_orphans(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local orphans = {}
    local tempqf_list = vim.fn.getqflist()
    local count = 0
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep
    local files_cwd = require('mdnotes').get_files_in_cwd({ extension = ".md", hidden = false, fs_type = "file" })
    local buf = vim.api.nvim_get_current_buf()

    local progress = {
      kind = "progress",
      percent = 0,
      source = "mdn",
      status = "running",
    }

    if silent == false then
        progress.id = vim.api.nvim_echo({ { "Mdn: Searching notes for orphans..." } }, false, progress)
    end

    for i, file in ipairs(files_cwd) do
        file = file:gsub(".md", "")
        mdn_grep("\\[\\[".. file .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
        if vim.api.nvim_get_current_buf() ~= buf then
            vim.cmd.buffer(buf) -- to prevent jumps while searching
        end
        if vim.tbl_isempty(vim.fn.getqflist()) then
            count = count + 1
            table.insert(orphans, file .. ".md")
            if silent == false then
                vim.cmd.redraw()
                progress.percent = math.floor(100 * i / #files_cwd)
                vim.api.nvim_echo({ {"Mdn: Found " .. tostring(count) .. " orphan pages so far..."} }, false, progress)
            end
        end
    end

    vim.cmd.buffer(buf)
    vim.fn.setqflist(tempqf_list)

    return orphans
end

---Show orphans in qflist
function M.find_orphans()
    local orphans = M.get_orphans()
    if vim.tbl_isempty(orphans) then
        vim.cmd.redraw()
        vim.notify("Mdn: No orphan pages found", vim.log.levels.WARN)
        return
    end

    local cwd = require('mdnotes').cwd
    local qflist = {}
    for _, v in pairs(orphans) do
        table.insert(qflist, {filename = vim.fs.joinpath(cwd, v)})
    end

    vim.fn.setqflist(qflist)
    vim.cmd.copen()

    return qflist
end

---Get an inline link string from an MdnInlineLinkData object
---@param wldata MdnWikiLinkData? Inline link object
---@return string wikilink
function M.get_wl_from_obj(wldata)
    vim.validate("wldata", wldata, "table", true)
    if wldata == nil then return "" end

    if wldata.alias == nil or wldata.alias == "" then
        if wldata.fragment == nil or wldata.fragment == "" then
            return "[[" .. wldata.file .. "]]"
        else
            return "[[" .. wldata.file .. "#" .. wldata.fragment .. "]]"
        end
    else
        if wldata.fragment == nil or wldata.fragment == "" then
            return "[[" .. wldata.file .. "|" .. wldata.alias .. "]]"
        else
            return "[[" .. wldata.file .. "#" .. wldata.fragment .. "|" .. wldata.alias .. "]]"
        end
    end
end

---Open a picker to get the WikiLink
---@param on_end fun(sel_obj): any Callback function for when the coroutine finishes
---@param buf integer Buffer number
function M.picker(on_end, buf)
    vim.validate("on_end", on_end, "function")
    vim.validate("buf", buf, "number")
    if buf == 0 then buf = vim.api.nvim_get_current_buf() end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No WikiLinks in current file", vim.log.levels.ERROR)
        return
    end

    local ui_opts = {
        prompt = "Select a WikiLink:",
        format_item = function(item)
            return item.raw:sub(3, -3)
        end,
    }

    return require('mdnotes').mdn_picker(parsed_tbl, on_end, ui_opts)
end

---Parse the WikiLinks in the specified lines
---@param opts {location: MdnMultiLineLocation?, str: boolean?, no_duplicates: boolean?}?
---@return table<MdnWikiLinkData>?
function M.parse_lines(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local str = opts.str or false
    local pattern = require('mdnotes.patterns').wikilink
    local parse_lines = require('mdnotes').parse_lines

    local get_func = nil
    if str == true then
        get_func = M.get_wl_from_obj
    end

    return parse_lines(pattern, M.parse, {location = opts.location, no_duplicates = opts.no_duplicates, get_func = get_func})
end

return M
