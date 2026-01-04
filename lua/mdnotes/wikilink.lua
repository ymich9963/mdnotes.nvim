local M = {}

local uv = vim.loop or vim.uv

local old_name = ""
local new_name = ""

local function check_md_lsp()
    if not vim.tbl_isempty(vim.lsp.get_clients({bufnr = 0})) and vim.bo.filetype == "markdown" and require('mdnotes').config.prefer_lsp then
        return true
    else
        return false
    end
end

function M.follow()
    if check_md_lsp() then
        -- Doing some weird shit with the qf list for this
        vim.fn.setqflist({}, ' ')

        local function on_list(options)
            vim.fn.setqflist({}, ' ', options)
            vim.cmd.cfirst()
        end
        vim.lsp.buf.definition({ on_list = on_list })

        vim.wait(10, function () return not vim.tbl_isempty(vim.fn.getqflist()) end)

        if vim.tbl_isempty(vim.fn.getqflist()) then
            vim.cmd.redraw()
            vim.notify("Mdn: No locations found from LSP server. Continuing with Mdnotes implementation.", vim.log.levels.WARN)
        else
            vim.fn.setqflist({}, ' ')
            vim.notify("", vim.log.levels.INFO)
            vim.cmd.redraw()
            return
        end
    end

    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local wikilink_pattern = require('mdnotes.patterns').wikilink
    local uri_no_fragment_pattern = require('mdnotes.patterns').uri_no_fragment
    local fragment_pattern = require('mdnotes.patterns').fragment

    local wikilink, fragment = "", ""
    for start_pos, link ,end_pos in line:gmatch(wikilink_pattern) do
        if start_pos < current_col and end_pos > current_col then
            wikilink = link:match(uri_no_fragment_pattern) or ""
            fragment = link:match(fragment_pattern) or ""

            wikilink = vim.fs.normalize(vim.trim(wikilink))
            fragment = vim.trim(fragment)
        end
    end

    if wikilink == "" and fragment == "" then
        vim.notify(("Mdn: No WikiLink under the cursor was detected."), vim.log.levels.ERROR)
    end

    if wikilink ~= "" then
        if wikilink:sub(-3) == ".md" then
            vim.cmd(require('mdnotes').open_cmd .. wikilink)
        else
            vim.cmd(require('mdnotes').open_cmd .. wikilink .. '.md')
        end
    end


    if fragment ~= "" then
        vim.fn.cursor(vim.fn.search(fragment), 1)
        vim.api.nvim_input('zz')
    end
end

function M.show_references()
    if check_md_lsp() then
        vim.lsp.buf.references()
        return
    end

    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local found_file = ""
    local wikilink_pattern = require('mdnotes.patterns').wikilink

    for start_pos, file ,end_pos in line:gmatch(wikilink_pattern) do
        if start_pos < current_col and end_pos > current_col then
            found_file = file
        end
    end

    if found_file == "" then
        -- If wikilink pattern isn't detected use current file name
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        found_file = cur_file_basename:match("(.+)%.[^%.]+$")
    end

    vim.cmd.vimgrep({args = {'/\\[\\[' .. found_file .. '\\]\\]/', '*'}, mods = {emsg_silent = true}})
    if #vim.fn.getqflist() == 1 then
        vim.notify(("Mdn: No references found for '" .. found_file .. "' ."), vim.log.levels.ERROR)
        return
    end
    vim.cmd.copen()
end

function M.undo_rename()
    if check_md_lsp() then
        vim.notify("Mdn: undo_rename is only available when your config has prefer_lsp = false.", vim.log.levels.ERROR)
        return
    end

    if new_name == "" or old_name == "" then
        vim.notify(("Mdn: Detected no recent rename."):format(old_name, new_name), vim.log.levels.ERROR)
        return
    end

    local cur_buf_num = vim.api.nvim_win_get_buf(0)

    vim.cmd.vimgrep({args = {'/\\[\\[' .. new_name .. '\\]\\]/', '*'}, mods = {emsg_silent = true}})
    vim.cmd.cdo({args = {('s/%s/%s/'):format(new_name, old_name)}, mods = {emsg_silent = true}})

    if not uv.fs_rename(new_name .. ".md", old_name .. ".md") then
        vim.notify(("Mdn: File rename failed."), vim.log.levels.ERROR)
        return
    end

    vim.notify(("Mdn: Undo renaming '%s' to '%s'."):format(old_name, new_name), vim.log.levels.INFO)
    vim.api.nvim_win_set_buf(0, cur_buf_num)
end

function M.rename_references_cur_buf()
    if check_md_lsp() then
        vim.lsp.buf.rename()
        return
    end

    local cur_buf_num = vim.api.nvim_win_get_buf(0)
    local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
    local cur_file_name = cur_file_basename:match("(.+)%.[^%.]+$")
    local renamed = ""

    vim.ui.input({ prompt = "Rename current buffer '".. cur_file_name .."' to: " },
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

    vim.api.nvim_win_set_buf(0, cur_buf_num)
    old_name = cur_file_name
    new_name = renamed
end

function M.rename_references()
    local cur_buf_num = vim.api.nvim_win_get_buf(0)
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    local file, _ = "", ""
    local renamed = ""
    local wikilink_pattern = require('mdnotes.patterns').wikilink
    local file_fragment_pattern = require('mdnotes.patterns').uri_no_fragment

    for start_pos, link ,end_pos in line:gmatch(wikilink_pattern) do
        if start_pos < current_col and end_pos > current_col then
            -- Match link to links with fragment names but ignore the fragment name
            file, _ = link:match(file_fragment_pattern)
            file = vim.trim(file)
        end
    end

    if file == "" then
        M.rename_references_cur_buf()
        return
    end

    if not uv.fs_stat(file .. ".md") then
        vim.notify(("Mdn: This link does not seem to link to a valid file."), vim.log.levels.ERROR)
        return
    end

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

    vim.notify((("Mdn: Succesfully renamed '%s' links to '%s'."):format(file, renamed)), vim.log.levels.INFO)

    vim.api.nvim_win_set_buf(0, cur_buf_num)

    old_name = file
    new_name = renamed
end

function M.create()
    local line = vim.api.nvim_get_current_line()
    local selected_text, col_start, col_end = require('mdnotes.formatting').get_selected_text()

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. '[[' .. selected_text .. ']]' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

function M.delete()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local found_file = ""
    local wikilink = ""
    local wikilink_pattern = require('mdnotes.patterns').wikilink
    local new_line = ""
    local col_start = 0
    local col_end = 0

    for start_pos, file ,end_pos in line:gmatch(wikilink_pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            wikilink = file
            col_start = start_pos
            col_end = end_pos
        end
    end

    -- Append .md to guarantee a file name
    if wikilink:sub(-3) ~= ".md" then
        found_file = wikilink .. ".md"
    else
        found_file = wikilink
    end

    if uv.fs_stat(found_file)  then
        vim.ui.input( { prompt = ("Mdn: Delete '%s' WikiLink and file? Type y/n (default 'n'): "):format(found_file), }, function(input)
            vim.cmd.redraw()
            if input == 'y' then
                vim.fs.rm(found_file)
            elseif input == 'n' or '' then
            else
                vim.notify(("Mdn: Skipping unknown input '%s'. Press any key to continue..."):format(input), vim.log.levels.ERROR)
                vim.fn.getchar()
            end
        end)
    else
        vim.notify("Mdn: WikiLink file not found so proceeding to remove text only", vim.log.levels.WARN)
    end


    new_line = line:sub(1, col_start - 1) .. wikilink .. line:sub(col_end)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end})
end

function M.normalize()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local wikilink = ""
    local wikilink_pattern = require('mdnotes.patterns').wikilink
    local new_line = ""
    local col_start = 0
    local col_end = 0
    local new_wikilink = ""

    for start_pos, file ,end_pos in line:gmatch(wikilink_pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            wikilink = file
            col_start = start_pos
            col_end = end_pos
        end
    end

    new_wikilink = vim.fs.normalize(wikilink)
    if new_wikilink:match("%s") then
        new_wikilink = "<" .. new_wikilink .. ">"
    end

    new_line = line:sub(1, col_start - 1) .. '[[' .. new_wikilink .. ']]' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

return M
