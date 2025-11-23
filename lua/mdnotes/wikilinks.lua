local M = {}

local uv = vim.loop or vim.uv

local function check_md_lsp()
    if not vim.tbl_isempty(vim.lsp.get_clients({bufnr = 0})) and vim.bo.filetype == "markdown" and M.config.prefer_lsp then
        return true
    else
        return false
    end
end

function M.open_wikilink()
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
    local wikilink_pattern = require('mdnotes.patterns').patterns.wikilink
    local file_section_pattern = require('mdnotes.patterns').patterns.file_section

    local file, section = "", ""
    for start_pos, link ,end_pos in line:gmatch(wikilink_pattern) do
        if start_pos < current_col and end_pos > current_col then
            file, section = link:match(file_section_pattern)
            file = vim.trim(file)
            section = vim.trim(section)
        end
    end

    if file == "" and section == "" then
        vim.notify(("Mdn: No WikiLink under the cursor was detected."), vim.log.levels.ERROR)
    end

    if file ~= "" then
        if file:sub(-3) == ".md" then
            vim.cmd(require('mdnotes').open_cmd .. file)
        else
            vim.cmd(require('mdnotes').open_cmd .. file .. '.md')
        end
    end


    if section ~= "" then
        vim.fn.cursor(vim.fn.search(section), 1)
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
    local wikilink_pattern = require('mdnotes.patterns').patterns.wikilink

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

function M.rename_references_cur_buf()
    if check_md_lsp() then
        vim.lsp.buf.rename()
        return
    end

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
end

function M.rename_references()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')

    local file, _ = "", ""
    local renamed = ""
    local wikilink_pattern = require('mdnotes.patterns').patterns.wikilink
    local file_section_pattern = require('mdnotes.patterns').patterns.file_section

    for start_pos, link ,end_pos in line:gmatch(wikilink_pattern) do
        if start_pos < current_col and end_pos > current_col then
            -- Match link to links with section names but ignore the section name
            file, _ = link:match(file_section_pattern)
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
end

return M
