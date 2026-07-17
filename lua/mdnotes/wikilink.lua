---@module 'mdnotes.wikilink'

local M = {}

local uv = vim.loop or vim.uv

---@type table<string>
M.old_filenames = {}

---@type table<string>
M.new_filenames = {}

---@class MdnWikiLinkData: MdnInLineLocation
---@field wikilink_nofrag string WikiLink without the fragment
---@field fragment string The fragment in the WikiLink
---@field alias string WikiLink alias

local check_markdown_lsp_cur_buf = function() return require('mdnotes').check_markdown_lsp_cur_buf() end
local get_buf_from_buf_list = function(...) return require('mdnotes').get_buf_from_buf_list(...) end

---Parse WikiLink
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
---@return MdnWikiLinkData?
function M.parse(opts)
    opts = opts or {}

    local wikilink = opts.wikilink

    vim.validate("wikilink", wikilink, { "string", "nil" })

    local mdn_patterns = require('mdnotes.patterns')
    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local txtdata = {}

    -- Overwrite if location is given
    if opts.location ~= nil or wikilink == nil then
        if not check_markdown_syntax(mdn_patterns.wikilink, {location = opts.location}) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(mdn_patterns.wikilink, { location = opts.location })
        wikilink = txtdata.text
    else
        _, wikilink, _ = wikilink:match(mdn_patterns.wikilink)
    end

    local wikilink_no_fragment = wikilink:match(mdn_patterns.dest_no_fragment)
    local fragment = wikilink:match(mdn_patterns.fragment)
    local alias = wikilink:match(mdn_patterns.wikilink_alias)

    return vim.tbl_extend("keep", {
        wikilink_nofrag = wikilink_no_fragment,
        fragment = fragment,
        alias = alias,
    }, txtdata)
end

---Follow the WikiLink under the cursor
---@param opts {wikilink: string?, location: MdnInLineLocation?, hor: boolean?, vert: boolean?}?
function M.follow(opts)
    if check_markdown_lsp_cur_buf() then
        vim.lsp.buf.definition()

        return
    end

    opts = opts or {}
    local wikilink = opts.wikilink
    local hor = opts.hor or false
    local vert = opts.vert or false

    local wldata
    if wikilink == nil then
        wldata = M.parse({ location = opts.location })
    else
        wldata = M.parse({ wikilink = wikilink })
    end

    if wldata == nil then
        wikilink = M.get_wl_from_picker()
        wldata = M.parse({ wikilink = wikilink })
    end

    if wldata == nil then return end

    local cwd = require('mdnotes').cwd

    if wldata.wikilink_nofrag ~= "" then
        local path = vim.fs.joinpath(cwd, wldata.wikilink_nofrag)

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
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
function M.follow_hor(opts)
    opts = opts or {}
    M.follow({ wikilink = opts.wikilink, location = opts.location, hor = true})
end

---Follow the WikiLink and split vertically
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
function M.follow_vert(opts)
    opts = opts or {}
    M.follow({ wikilink = opts.wikilink, location = opts.location, vert = true})
end

---Show the references to the current WikiLink under the cursor
---@param opts {location: MdnInLineLocation?, silent: boolean?}?
---@return table? qflist Resulting quickfix list
function M.show_references(opts)
    if check_markdown_lsp_cur_buf() then
        vim.lsp.buf.references()

        return
    end

    opts = opts or {}
    local silent = opts.silent or false
    local wldata = M.parse({ location = opts.location })

    if wldata == nil then
        -- If wikilink pattern isn't detected use current file name
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        wldata = {
            buf = vim.api.nvim_get_current_buf(),
            wikilink_nofrag = cur_file_basename:gsub(".md$",""),
            fragment = "",
            alias = "",
        }
    end

    local cur_pos = vim.fn.getpos('.')
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep

    mdn_grep("\\[\\[".. wldata.wikilink_nofrag .. "(\\.md)?(\\#.*)?\\]\\]", cwd)

    local qflist = vim.fn.getqflist()
    if vim.tbl_isempty(qflist) then
        if silent == false then
            vim.notify("Mdn: No references found for '" .. wldata.wikilink_nofrag .. "'", vim.log.levels.ERROR)
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

    opts = opts or {}
    local silent = opts.silent or false
    local new_name = opts.new_name

    vim.validate("new_name", new_name, { "string", "nil" })

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
            wikilink_nofrag = vim.fs.basename(vim.api.nvim_buf_get_name(0)):match("(.+)%.[^%.]+$"),
            fragment = "",
            alias = "",
        }
    end

    -- Remove the file extension for this function
    if vim.endswith(wldata.wikilink_nofrag, ".md") then
        wldata.wikilink_nofrag = wldata.wikilink_nofrag:sub(1,-4)
    end

    -- Check if it exists
    local filepath = vim.fs.normalize(vim.fs.joinpath(cwd, wldata.wikilink_nofrag .. ".md"))
    if not uv.fs_stat(filepath) then
        if silent == false then
            vim.notify("Mdn: WikiLink does not seem to link to a valid Markdown file", vim.log.levels.ERROR)
        end

        return wldata.wikilink_nofrag, "invalid file"
    end

    -- Prompt for new name and check if valid
    if new_name == nil then
        vim.ui.input({ prompt = prompt, default = wldata.wikilink_nofrag },
        function(input)
            new_name = input
        end)

        if new_name == "" or new_name == nil then
            if silent == false then
                vim.notify("Mdn: Please insert a valid name", vim.log.levels.ERROR)
            end

            return wldata.wikilink_nofrag, "invalid name"
        end
    end

    -- Change all [[WikiLink]] text to be the new name
    vim.cmd.wall({bang = true, mods = {silent = true}})
    mdn_grep("\\[\\[".. wldata.wikilink_nofrag .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
    vim.cmd.cdo({args = {('s/%s/%s/'):format("\\[\\[" .. wldata.wikilink_nofrag, "\\[\\[" .. new_name)}, mods = {emsg_silent = true, noautocmd = true}})
    vim.cmd.wall({bang = true, mods = {silent = true}})

    -- Get the buffer number of the renamed file if it is in the buffer list
    local renamed_bufnum = get_buf_from_buf_list(wldata.wikilink_nofrag .. ".md")

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

        return wldata.wikilink_nofrag, err
    end

    table.insert(M.old_filenames, wldata.wikilink_nofrag)
    table.insert(M.new_filenames, new_name)

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    -- Go back to position where command started
    vim.cmd.buffer(cur_buf)
    vim.fn.setpos('.', pos)

    vim.cmd.write({bang = true, mods = {silent = true}})

    if silent == false then
        vim.notify(("Mdn: Succesfully renamed '%s' links to '%s'"):format(wldata.wikilink_nofrag, new_name), vim.log.levels.INFO)
    end

    return wldata.wikilink_nofrag, new_name
end

---Undo the most recent rename
---@param opts {silent: boolean?}?
---@return string? old_name, string|nil new_name 
function M.undo_rename(opts)
    if check_markdown_lsp_cur_buf() then
        vim.notify("Mdn: 'undo_rename' is only available when your config has 'prefer_lsp = false'", vim.log.levels.ERROR)
        return
    end

    opts = opts or {}
    local silent = opts.silent or false

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

    vim.cmd.wall({bang = true, mods = {silent = true}})
    mdn_grep("\\[\\[".. newest_filename .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
    vim.cmd.cdo({args = {('s/%s/%s/'):format(newest_filename, newest_old_filename)}, mods = {emsg_silent = true, noautocmd = true}})
    vim.cmd.wall({bang = true, mods = {silent = true}})

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
    opts = opts or {}

    local insert_format = require('mdnotes.formatting').insert_format
    insert_format("[[]]", { split_delimiter = true, location = opts.location, move_cursor = opts.move_cursor })
end

---Delete the current WikiLink and the associated file
---@param opts {location: MdnInLineLocation?, move_cursor: boolean?, skip_input: boolean?}?
---@return boolean deleted, string wikilink Returns whether the file was deleted and the affected WikiLink
function M.delete(opts)
    opts = opts or {}

    local skip_input = opts.skip_input or false

    local found_file = ""
    local deleted = false
    local cwd = require('mdnotes').cwd
    local mdn_wikilink_pattern = require('mdnotes.patterns').wikilink
    local delete_format = require('mdnotes.formatting').delete_format

    local wldata = M.parse({ location = opts.location })
    if wldata == nil then return false, "" end

    -- Append .md to guarantee a file name
    if not vim.endswith(wldata.wikilink_nofrag, ".md") then
        found_file = wldata.wikilink_nofrag .. ".md"
    else
        found_file = wldata.wikilink_nofrag
    end

    local path = vim.fs.normalize(vim.fs.joinpath(cwd, found_file))
    if uv.fs_stat(path) then
        if skip_input == false then
            vim.ui.input( { prompt = ("Mdn: Delete '%s' WikiLink and file? Type y/n (default 'n'): "):format(wldata.wikilink_nofrag), }, function(input)
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

    delete_format(mdn_wikilink_pattern, { location = opts.location, move_cursor = opts.move_cursor })

    return deleted, wldata.wikilink_nofrag
end

---Normalize the WikiLink under the cursor
---@param opts {location: MdnInLineLocation?, move_cursor: boolean?}?
function M.normalize(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false

    local wldata = M.parse({ location = opts.location })
    if wldata == nil then return end

    local new_wikilink = vim.fs.normalize(wldata.wikilink_nofrag)

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
    opts = opts or {}

    local silent = opts.silent or false

    local orphans = {}
    local tempqf_list = vim.fn.getqflist()
    local count = 0
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep
    local files_cwd = require('mdnotes').get_files_in_cwd({ extension = ".md", hidden = false, fs_type = "file" })

    if silent == false then
        vim.notify("Mdn: Searching notes for orphans...", vim.log.levels.INFO)
    end

    for _, file in pairs(files_cwd) do
        file = file:gsub(".md", "")
        mdn_grep("\\[\\[".. file .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
        if vim.tbl_isempty(vim.fn.getqflist()) then
            count = count + 1
            table.insert(orphans, file .. ".md")
            if silent == false then
                vim.notify("Mdn: Found " .. tostring(count) .. " orphan pages so far..." , vim.log.levels.INFO)
            end
        end
    end

    vim.fn.setqflist(tempqf_list)

    return orphans
end

---Show orphans on cmdline
function M.find_orphans()
    local orphans = M.get_orphans()
    if vim.tbl_isempty(orphans) then
        vim.notify("Mdn: No orphan pages found", vim.log.levels.WARN)
    else
        local orphans_txt = ""
        for _, v in pairs(orphans) do
            orphans_txt = orphans_txt .. v .. ", "
        end
        orphans_txt = orphans_txt:sub(1,#orphans_txt - 2)
        vim.notify("Mdn: Found the following orphan pages: " .. orphans_txt, vim.log.levels.WARN)
    end
end

---Get an inline link string from an MdnInlineLinkData object
---@param wldata MdnWikiLinkData? Inline link object
---@return string wikilink
function M.get_wl_from_obj(wldata)
    if wldata == nil then return "" end

    if wldata.alias == nil or wldata.alias == "" then
        if wldata.fragment == nil or wldata.fragment == "" then
            return "[[" .. wldata.wikilink_nofrag .. "]]"
        else
            return "[[" .. wldata.wikilink_nofrag .. "#" .. wldata.fragment .. "]]"
        end
    else
        if wldata.fragment == nil or wldata.fragment == "" then
            return "[[" .. wldata.wikilink_nofrag .. "|" .. wldata.alias .. "]]"
        else
            return "[[" .. wldata.wikilink_nofrag .. "#" .. wldata.fragment .. "|" .. wldata.alias .. "]]"
        end
    end
end

---Go to WikiLink
---@param buf integer?
function M.get_wl_from_picker(buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No WikiLinks in current file to go to", vim.log.levels.ERROR)
        return
    end

    local sel_list = {}
    for _, v in ipairs(parsed_tbl) do
        table.insert(sel_list, M.get_wl_from_obj(v):sub(3, -3))
    end

    local wl_index = nil
    vim.ui.select(sel_list, {
        prompt = "Select a WikiLink to go to",
    }, function (_, idx)
        wl_index = idx
    end)

    if wl_index == nil then
        return
    end

    return M.get_wl_from_obj(parsed_tbl[wl_index])
end

---Parse the WikiLinks in the specified lines
---@param opts {location: MdnMultiLineLocation?, str: boolean?, silent: boolean?}?
---@return table<MdnWikiLinkData>?
function M.parse_lines(opts)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')
    local str = opts.str or false

    local pattern = require('mdnotes.patterns').wikilink
    local scan_lines = require('mdnotes').scan_lines

    local scanned_lines = scan_lines(pattern, { location = {startl = startl, endl = endl, buf = buf }, silent = true})
    if scanned_lines == nil then return nil end

    local parsed_tbl = {}
    for _, item in ipairs(scanned_lines) do
        for _, cols in ipairs(item.cols) do
            local data = M.parse({ location = {buf = buf, lnum = item.lnum, col_start = cols[1], col_end = cols[2] }})
            if str == true then
                table.insert(parsed_tbl, M.get_wl_from_obj(data))
            else
                table.insert(parsed_tbl, data)
            end
        end
    end

    return parsed_tbl
end

return M
