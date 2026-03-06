---@module 'mdnotes.wikilink'

local M = {}

local uv = vim.loop or vim.uv

---@type string
M.old_filename = ""

---@type string
M.new_filename = ""

---Check for Markdown LSPs
---@return boolean
local function check_markdown_lsp()
    if not vim.tbl_isempty(vim.lsp.get_clients({bufnr = 0})) and vim.bo.filetype == "markdown" and require('mdnotes').config.prefer_lsp then
        return true
    else
        return false
    end
end

---@class MdnWikiLinkData: MdnInLineLocation
---@field wikilink_nofrag string WikiLink without the fragment
---@field fragment string The fragment in the WikiLink

---Get the current WikiLink under the cursor if it exists
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
---@return MdnWikiLinkData|nil
function M.parse(opts)
    opts = opts or {}

    local wikilink = opts.wikilink
    local locopts = opts.location or {}

    -- Overwrite if location is given
    if not vim.tbl_isempty(locopts) then
        wikilink = nil
    end

    vim.validate("wikilink", wikilink, { "string", "nil" })

    local mdn_patterns = require('mdnotes.patterns')
    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local txtdata

    if wikilink == nil then
        if not check_markdown_syntax(mdn_patterns.wikilink, {location = locopts}) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(mdn_patterns.wikilink, { location = locopts })
        wikilink = txtdata.text
    end

    local wikilink_no_fragment = wikilink:match(mdn_patterns.uri_no_fragment)
    local fragment = wikilink:match(mdn_patterns.fragment)

    return vim.tbl_extend("keep", {
        wikilink_nofrag = wikilink_no_fragment,
        fragment = fragment,
    }, txtdata)
end

---Follow the WikiLink under the cursor
---@param opts {location: MdnInLineLocation?}?
function M.follow(opts)
    if check_markdown_lsp() then
        vim.lsp.buf.definition()

        return
    end

    opts = opts or {}
    local locopts = opts.location or {}

    local wldata = M.parse({ location = locopts })

    if wldata == nil then
        vim.notify("Mdn: No WikiLink under the cursor was detected", vim.log.levels.ERROR)
        return
    end

    local cwd = require('mdnotes').cwd

    if wldata.wikilink_nofrag ~= "" then
        local path = vim.fs.joinpath(cwd, wldata.wikilink_nofrag)

        if path:sub(-3) ~= ".md" then
            path = path .. ".md"
        end

        require('mdnotes').open_buf(path)
    end

    if wldata.fragment ~= "" then
        vim.fn.cursor(vim.fn.search(wldata.fragment), 1)
        vim.api.nvim_input('zz')
    end
end

---Show the references to the current WikiLink under the cursor
---@param opts {location: MdnInLineLocation?}?
---@return table|nil qflist Resulting quickfix list
function M.show_references(opts)
    if check_markdown_lsp() then
        vim.lsp.buf.references()

        return
    end

    opts = opts or {}
    local locopts = opts.location or {}

    local wldata = M.parse({ location = locopts })

    if wldata == nil then
        -- If wikilink pattern isn't detected use current file name
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        wldata = {
            buffer = vim.api.nvim_get_current_buf(),
            wikilink_nofrag = cur_file_basename:gsub(".md$",""),
            fragment = "",
        }
    end

    local cur_pos = vim.fn.getpos('.')
    local cwd = require('mdnotes').cwd

    vim.cmd.vimgrep({args = {'/\\[\\[' .. wldata.wikilink_nofrag .. '.*\\]\\]/', vim.fs.joinpath(cwd, "*")}, mods = {emsg_silent = true}})

    local qflist = vim.fn.getqflist()
    if vim.tbl_isempty(qflist) then
        vim.notify("Mdn: No references found for '" .. wldata.wikilink_nofrag .. "'", vim.log.levels.ERROR)
        return qflist
    end

    vim.cmd("buffer " .. wldata.buffer)
    vim.fn.setpos('.', cur_pos)
    vim.cmd.copen()

    return qflist
end

---Get the buffer number from the buffer name
local function get_buf_from_buf_list(bufname)
    local buf_list = vim.api.nvim_list_bufs()
    local ret = nil

    for _, bufnum in ipairs(buf_list) do
        local filename = vim.fs.basename(vim.api.nvim_buf_get_name(bufnum))
        if filename == bufname then
            ret = bufnum
            break
        end
    end

    return ret
end

---Rename references of the WikiLink under the cursor
---If there is no WikiLink under the cursor, prompt to rename references to
---the current buffer
---@param opts {new_name: string?, location: MdnInLineLocation?}?
---@return string|nil old_name, string|nil new_name 
function M.rename_references(opts)
    if check_markdown_lsp() then
        -- I think this renames the current buffer and
        -- not the symbol under cursor
        vim.lsp.buf.rename()

        return
    end

    opts = opts or {}
    local new_name = opts.new_name
    local locopts = opts.location or {}

    vim.validate("new_name", new_name, { "string", "nil" })

    -- Save current position to rever back later
    local cur_buf = vim.api.nvim_get_current_buf()
    local pos = vim.fn.getpos('.')

    local temp_qflist = vim.fn.getqflist()
    local prompt = "Rename WikiLink and file: "
    local cwd = require('mdnotes').cwd
    local wldata = M.parse({ location = locopts })

    if wldata == nil then
        prompt = "Rename current buffer: "
        wldata = {
            wikilink_nofrag = vim.fs.basename(vim.api.nvim_buf_get_name(0)):match("(.+)%.[^%.]+$"),
            fragment = ""
        }
    end

    -- Remove the file extension for this function
    if wldata.wikilink_nofrag:sub(-3) == ".md" then
        wldata.wikilink_nofrag = wldata.wikilink_nofrag:sub(1,-4)
    end

    -- Check if it exists
    local filepath = vim.fs.normalize(vim.fs.joinpath(cwd, wldata.wikilink_nofrag .. ".md"))
    if not uv.fs_stat(filepath) then
        vim.notify("Mdn: WikiLink does not seem to link to a valid Markdown file", vim.log.levels.ERROR)

        return wldata.wikilink_nofrag, "invalid file"
    end

    -- Prompt for new name and check if valid
    if new_name == nil then
        vim.ui.input({ prompt = prompt, default = wldata.wikilink_nofrag },
        function(input)
            new_name = input
        end)

        if new_name == "" or new_name == nil then
            vim.notify("Mdn: Please insert a valid name", vim.log.levels.ERROR)

            return wldata.wikilink_nofrag, "invalid name"
        end
    end

    -- Change all [[WikiLink]] text to be the new name
    vim.cmd.wall({bang = true, mods = {silent = true}})
    vim.cmd.vimgrep({args = {'/\\[\\[' .. wldata.wikilink_nofrag .. '.*\\]\\]/', vim.fs.joinpath(cwd, "*")}, mods = {emsg_silent = true}})
    vim.cmd.cdo({args = {('s/%s/%s/'):format("\\[\\[" .. wldata.wikilink_nofrag, "\\[\\[" .. new_name)}, mods = {emsg_silent = true}})
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
        vim.notify("Mdn: File rename failed", vim.log.levels.ERROR)

        return wldata.wikilink_nofrag, err
    end

    M.old_filename = wldata.wikilink_nofrag
    M.new_filename = new_name

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    -- Go back to position where command started
    vim.cmd.buffer(cur_buf)
    vim.fn.setpos('.', pos)

    vim.notify(("Mdn: Succesfully renamed '%s' links to '%s'"):format(wldata.wikilink_nofrag, new_name), vim.log.levels.INFO)

    return wldata.wikilink_nofrag, new_name
end

---Undo the most recent rename
---@return string|nil old_name, string|nil new_name 
function M.undo_rename()
    if check_markdown_lsp() then
        vim.notify("Mdn: 'undo_rename' is only available when your config has 'prefer_lsp = false'", vim.log.levels.ERROR)
        return
    end

    if M.new_filename == "" or M.old_filename == "" then
        vim.notify("Mdn: Detected no recent rename", vim.log.levels.ERROR)
        return
    end

    local temp_qflist = vim.fn.getqflist()
    local cur_buf = vim.api.nvim_get_current_buf()
    local cur_pos = vim.fn.getpos('.')
    local cwd = require('mdnotes').cwd

    vim.cmd.wall({bang = true, mods = {silent = true}})
    vim.cmd.vimgrep({args = {'/\\[\\[' .. M.new_filename .. '.*\\]\\]/', vim.fs.joinpath(cwd, "*")}, mods = {emsg_silent = true}})
    vim.cmd.cdo({args = {('s/%s/%s/'):format(M.new_filename, M.old_filename)}, mods = {emsg_silent = true}})
    vim.cmd.wall({bang = true, mods = {silent = true}})

    local ret, err = uv.fs_rename(
        vim.fs.joinpath(cwd, M.new_filename .. ".md"),
        vim.fs.joinpath(cwd, M.old_filename .. ".md")
    )
    if not ret then
        vim.notify(("Mdn: Undo file rename failed"), vim.log.levels.ERROR)
        return nil, err
    end

    vim.notify(("Mdn: Undo renaming '%s' to '%s'"):format(M.old_filename, M.new_filename), vim.log.levels.INFO)

    -- Get the buffer number of the renamed file if it is in the buffer list
    local renamed_bufnum = get_buf_from_buf_list(M.old_filename .. ".md")

    -- If the buffer number of the renamed file is in the buffer list
    if renamed_bufnum ~= nil then
        if renamed_bufnum ~= cur_buf then
            vim.api.nvim_buf_delete(renamed_bufnum, {force = true})
        elseif renamed_bufnum == cur_buf then
            vim.api.nvim_buf_set_name(cur_buf, vim.fs.joinpath(cwd, M.old_filename .. ".md"))
        end
    end

    vim.cmd.buffer(cur_buf)
    vim.fn.setpos('.', cur_pos)

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    return M.new_filename, M.old_filename
end

---Create a WikiLink from the word under the cursor
function M.create()
    local txtdata = require('mdnotes').get_text()

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buffer, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {'[[' .. txtdata.text .. ']]'})
    vim.fn.cursor({txtdata.lnum, txtdata.cur_col + 2})
end

---Delete the current WikiLink and the associated file
---@param opts {skip_input: boolean?, location: MdnInLineLocation?}?
---@return boolean deleted, string wikilink Returns whether the file was deleted and the affected WikiLink
function M.delete(opts)
    opts = opts or {}

    local skip_input = opts.skip_input or false
    local locopts = opts.location or {}

    local wldata = M.parse({ location = locopts })
    if wldata == nil then return false, "" end

    local found_file = ""
    local deleted = false

    -- Append .md to guarantee a file name
    if wldata.wikilink_nofrag:sub(-3) ~= ".md" then
        found_file = wldata.wikilink_nofrag .. ".md"
    else
        found_file = wldata.wikilink_nofrag
    end

    local cwd = require('mdnotes').cwd
    local path = vim.fs.joinpath(cwd, found_file)

    if uv.fs_stat(path) then
        if skip_input == false then
            vim.ui.input( { prompt = ("Mdn: Delete '%s' WikiLink and file? Type y/n (default 'n'): "):format(wldata.wikilink_nofrag), }, function(input)
                vim.cmd.redraw()
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

    local new_col = wldata.cur_col - 2
    if new_col < 1 then new_col = 1 end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(wldata.buffer, wldata.lnum - 1, wldata.col_start - 1, wldata.lnum - 1, wldata.col_end - 1, {wldata.wikilink_nofrag})
    vim.fn.cursor({wldata.lnum, new_col})

    return deleted, wldata.wikilink_nofrag
end

---Normalize the WikiLink under the cursor
---@param opts {location: MdnInLineLocation?}?
function M.normalize(opts)
    opts = opts or {}

    local locopts = opts.location or {}

    local wldata = M.parse({ location = locopts })
    if wldata == nil then return end

    local new_wikilink = vim.fs.normalize(wldata.wikilink_nofrag)

    if wldata.fragment ~= nil then
        new_wikilink = new_wikilink .. '#' .. wldata.fragment
    end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(wldata.buffer, wldata.lnum - 1, wldata.col_start - 1, wldata.lnum - 1, wldata.col_end - 1, {'[[' .. new_wikilink .. ']]'})
    vim.fn.cursor({wldata.lnum, wldata.cur_col})
end

---Get any orphan pages in the cwd
---@return table<string> orphans Table of orphan pages
function M.get_orphans()
    if print == nil then print = true end
    local orphans = {}
    local tempqf_list = vim.fn.getqflist()
    local count = 0
    local cwd = require('mdnotes').cwd
    local files_cwd = require('mdnotes').get_files_in_cwd({ extension = ".md", hidden = false, fs_type = "file" })

    vim.notify("Mdn: Searching notes for orphans...", vim.log.levels.INFO)
    for _, file in pairs(files_cwd) do
        file = file:gsub(".md", "")
        vim.cmd.vimgrep({args = {'/\\[\\[' .. file .. '.*\\]\\]/', vim.fs.joinpath(cwd, "*")}, mods = {emsg_silent = true}})
        if vim.tbl_isempty(vim.fn.getqflist()) then
            count = count + 1
            vim.notify("Mdn: Found " .. tostring(count) .. " orphan pages so far..." , vim.log.levels.INFO)
            table.insert(orphans, file .. ".md")
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
        orphans_txt = orphans_txt(1,#orphans_txt - 2)
        vim.notify("Mdn: Found the following orphan pages: " .. orphans_txt, vim.log.levels.WARN)
    end
end

return M
