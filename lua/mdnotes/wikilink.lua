---@module 'mdnotes.wikilink'
local M = {}

local uv = vim.loop or vim.uv

---@type string
M.old_filename = ""

---@type string
M.new_filename = ""

---Check for Markdown LSPs
---@return boolean
local function check_md_lsp()
    if not vim.tbl_isempty(vim.lsp.get_clients({bufnr = 0})) and vim.bo.filetype == "markdown" and require('mdnotes').config.prefer_lsp then
        return true
    else
        return false
    end
end

---Get the current WikiLink under the cursor if it exists
---@param wikilink string? Input WikiLink
---@return string wikilink Whole of the WikiLink
---@return string wikilink_no_fragment WikiLink without the fragment
---@return string fragment The fragment in the WikiLink
---@return integer col_start The start position of the WikiLink in the current line
---@return integer col_end The end position of the WikiLink in the current line
function M.get_wikilink_data(wikilink)
    local wikilink_pattern = require('mdnotes.patterns').wikilink
    local uri_no_fragment_pattern = require('mdnotes.patterns').uri_no_fragment
    local fragment_pattern = require('mdnotes.patterns').fragment
    local col_start, col_end = 0, 0

    if wikilink == nil then
        wikilink, col_start, col_end = require('mdnotes.formatting').get_text_in_pattern_under_cursor(wikilink_pattern)
    else
        _, wikilink, _ = wikilink:match(wikilink_pattern)
    end

    local wikilink_no_fragment = wikilink:match(uri_no_fragment_pattern) or ""
    local fragment = wikilink:match(fragment_pattern) or ""

    return wikilink, wikilink_no_fragment, fragment, col_start, col_end
end

---Follow the WikiLink under the cursor
function M.follow()
    if check_md_lsp() then
        vim.lsp.buf.definition()
        return
    end

    local _, wikilink, fragment, _, _ = M.get_wikilink_data()

    if wikilink == "" and fragment == "" then
        vim.notify("Mdn: No WikiLink under the cursor was detected", vim.log.levels.ERROR)
    end

    local mdnotes = require('mdnotes')

    if wikilink ~= "" then
        local path = vim.fs.joinpath(mdnotes.cwd, wikilink)

        if path:sub(-3) ~= ".md" then
            path = path .. ".md"
        end

        mdnotes.open_buf(path)
    end

    if fragment ~= "" then
        vim.fn.cursor(vim.fn.search(fragment), 1)
        vim.api.nvim_input('zz')
    end
end

---Show the references to the current WikiLink under the cursor
---@return table|nil qflist Resulting quickfix list
function M.show_references()
    if check_md_lsp() then
        vim.lsp.buf.references()
        return
    end

    local wikilink, _, _, _, _ = M.get_wikilink_data()

    if wikilink == "" then
        -- If wikilink pattern isn't detected use current file name
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        wikilink = cur_file_basename:gsub(".md$","")
    end

    local cur_pos = vim.fn.getpos('.')
    local cur_buf = vim.api.nvim_get_current_buf()
    local cwd = require('mdnotes').cwd

    vim.cmd.vimgrep({args = {'/\\[\\[' .. wikilink .. '.*\\]\\]/', vim.fs.joinpath(cwd, "*")}, mods = {emsg_silent = true}})
    local qflist = vim.fn.getqflist()
    if vim.tbl_isempty(qflist) then
        vim.notify("Mdn: No references found for '" .. wikilink .. "'", vim.log.levels.ERROR)
        return qflist
    end
    vim.cmd("buffer " .. cur_buf)
    vim.fn.setpos('.', cur_pos)
    vim.cmd.copen()

    return qflist
end

---Get the buffer number from the buffer name
---Returns 0 if it's the current buffer
local function get_bufnum_from_name(bufname)
    local buf_list = vim.api.nvim_list_bufs()
    local ret = 0

    for _, bufnum in ipairs(buf_list) do
        local filename = vim.fs.basename(vim.api.nvim_buf_get_name(bufnum))
        if filename == bufname and bufnum ~= vim.api.nvim_get_current_buf() then
            ret = bufnum
            break
        end
    end

    return ret
end

---Rename references of the WikiLink under the cursor
---If there is no WikiLink under the cursor, prompt to rename the current buffer
---@param rename string? New name of WikiLink and file
---@param cur_buf boolean? Rename current buffer and not the WikiLink under cursor
---@return string|nil old_name, string|nil new_name 
function M.rename_references(rename, cur_buf)
    if check_md_lsp() then
        -- I think this renames the current buffer and
        -- not the symbol under cursor
        vim.lsp.buf.rename()
        return
    end

    if cur_buf == nil then cur_buf = false end

    local _, wikilink, _, _, _ = M.get_wikilink_data()
    local prompt = "Rename WikiLink and file: "
    local temp_qflist = vim.fn.getqflist()
    local cwd = require('mdnotes').cwd

    if wikilink == "" or cur_buf == true then
        cur_buf = true
        wikilink = vim.fs.basename(vim.api.nvim_buf_get_name(0)):match("(.+)%.[^%.]+$")
        prompt = "Rename current buffer: "
    end

    -- Remove the file extension for this function
    if wikilink:sub(-3) == ".md" then
        wikilink = wikilink:sub(1,-4)
    end

    if not uv.fs_stat(vim.fs.joinpath(cwd, wikilink .. ".md")) then
        vim.notify("Mdn: WikiLink does not seem to link to a valid Markdown file", vim.log.levels.ERROR)
        return wikilink, "invalid file"
    end

    if rename == nil then
        vim.ui.input({ prompt = prompt, default = wikilink },
        function(input)
            rename = input
        end)
    end

    if rename == "" or rename == nil then
        vim.notify("Mdn: Please insert a valid name", vim.log.levels.ERROR)
        return wikilink, "invalid name"
    end

    local ret, err = uv.fs_rename(
        vim.fs.joinpath(cwd, wikilink .. ".md"),
        vim.fs.joinpath(cwd, rename .. ".md")
    )
    if not ret then
        vim.notify("Mdn: File rename failed", vim.log.levels.ERROR)
        return wikilink, err
    end

    vim.cmd.wall({bang = true, mods = {silent = true}})
    vim.cmd.vimgrep({args = {'/\\[\\[' .. wikilink .. '.*\\]\\]/', vim.fs.joinpath(cwd, "*")}, mods = {emsg_silent = true}})
    vim.cmd.cdo({args = {('s/%s/%s/'):format(wikilink, rename)}, mods = {emsg_silent = true}})
    vim.cmd.wall({bang = true, mods = {silent = true}})

    local bufnum = get_bufnum_from_name(wikilink .. ".md")

    if cur_buf == false and bufnum ~= 0 then
        vim.api.nvim_buf_delete(bufnum, {force = false})
    elseif cur_buf == true then
        vim.api.nvim_buf_set_name(0, rename .. ".md")
    end

    M.old_filename = wikilink
    M.new_filename = rename

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    vim.notify(("Mdn: Succesfully renamed '%s' links to '%s'"):format(wikilink, rename), vim.log.levels.INFO)

    return wikilink, rename
end

---Undo the most recent rename
---@return string|nil old_name, string|nil new_name 
function M.undo_rename()
    if check_md_lsp() then
        vim.notify("Mdn: 'undo_rename' is only available when your config has 'prefer_lsp = false'", vim.log.levels.ERROR)
        return
    end

    if M.new_filename == "" or M.old_filename == "" then
        vim.notify("Mdn: Detected no recent rename", vim.log.levels.ERROR)
        return
    end

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

    local bufnum = get_bufnum_from_name(M.old_filename .. ".md")

    if bufnum ~= 0 then
        vim.api.nvim_buf_delete(bufnum, {force = false})
    elseif bufnum == 0 then
        vim.api.nvim_buf_set_name(0, M.old_filename .. ".md")
    end

    vim.fn.setpos('.', cur_pos)

    return M.new_filename, M.old_filename
end

---Create a WikiLink from the word under the cursor
function M.create()
    local selected_text, col_start, col_end = require('mdnotes.formatting').get_selected_text()
    local lnum = vim.fn.line('.')
    local cur_col = vim.fn.col('.')

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(0, lnum - 1, col_start - 1, lnum - 1, col_end, {'[[' .. selected_text .. ']]'})
    vim.fn.cursor({lnum, cur_col + 2})
end

---Delete the current WikiLink and the associated file
---@param skip_input boolean? Skip user input
---@return boolean deleted, string wikilink Returns whether the file was deleted and the affected WikiLink
function M.delete(skip_input)
    if skip_input == nil then skip_input = false end
    local found_file = ""
    local _, wikilink, _, col_start, col_end = M.get_wikilink_data()
    local lnum = vim.fn.line('.')
    local cur_col = vim.fn.col('.')
    local deleted = false

    -- Append .md to guarantee a file name
    if wikilink:sub(-3) ~= ".md" then
        found_file = wikilink .. ".md"
    else
        found_file = wikilink
    end

    local cwd = require('mdnotes').cwd
    local path = vim.fs.joinpath(cwd, found_file)

    if uv.fs_stat(path) then
        if skip_input == false then
            vim.ui.input( { prompt = ("Mdn: Delete '%s' WikiLink and file? Type y/n (default 'n'): "):format(wikilink), }, function(input)
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

    local new_col = cur_col - 2
    if new_col < 1 then new_col = 1 end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(0, lnum - 1, col_start - 1, lnum - 1, col_end - 1, {wikilink})
    vim.fn.cursor({lnum, new_col})

    return deleted, wikilink
end

---Normalize the WikiLink under the cursor
function M.normalize()
    local lnum = vim.fn.line('.')
    local new_wikilink = ""
    local wikilink, _, _, col_start, col_end = M.get_wikilink_data()

    new_wikilink = vim.fs.normalize(wikilink)

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(0, lnum - 1, col_start - 1, lnum - 1, col_end - 1, {'[[' .. new_wikilink .. ']]'})
    vim.fn.cursor({lnum, vim.fn.col('.')})
end

---Find any orphan pages in the cwd
---@param print boolean? Whether to print to cmdline or not
---@return table<string> orphans Table of orphan pages
function M.find_orphans(print)
    if print == nil then print = true end
    local orphans = {}
    local tempqf_list = vim.fn.getqflist()
    local count = 0
    local cwd = require('mdnotes').cwd
    local files_cwd = require('mdnotes').get_files_in_cwd(".md", false, "file")

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
    if print == true then
        if vim.tbl_isempty(orphans) then
            vim.notify("Mdn: No orphan pages detected", vim.log.levels.INFO)
        else
            vim.print(orphans)
        end
    end

    return orphans
end

return M
