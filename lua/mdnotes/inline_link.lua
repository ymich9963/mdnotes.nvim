local M = {}

local uv = vim.loop or vim.uv

function M.insert()
    local reg = vim.fn.getreg('+')

    -- Set if empty
    if reg == '' then
        vim.notify("Mdn: Nothing detected in clipboard; \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    -- Sanitize text to prevent chaos
    vim.fn.setreg('+', reg:gsub("[%c]", ""))

    -- Get the selected text
    local col_start = vim.fn.getpos("'<")[3]
    local col_end = vim.fn.getpos("'>")[3]
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local selected_text = line:sub(col_start, col_end)

    -- This would happen when there is no selection
    if current_col ~= col_start then
        -- Get the word under cursor and cursor position
        selected_text = vim.fn.expand("<cword>")

        -- Search for the word in the line and check if it's under the cursor
        for start_pos, end_pos in line:gmatch("()" .. selected_text .. "()") do
            start_pos = vim.fn.str2nr(start_pos)
            end_pos = vim.fn.str2nr(end_pos)
            if start_pos < current_col and end_pos > current_col then
                col_start = start_pos
                col_end = end_pos - 1
            end
        end
    end

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. '[' .. selected_text .. '](' .. reg .. ')' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

function M.delete()
    vim.api.nvim_input('F["0di[f("+di(F[vf)"0p')
end

function M.toggle()
    local check_md_format = require('mdnotes.formatting').check_md_format
    if check_md_format(require("mdnotes.patterns").inline_link) then
        M.delete()
    else
        M.insert()
    end
end

local function rename_relink(rename_or_relink)
    local check_md_format = require('mdnotes.formatting').check_md_format
    if not check_md_format(require("mdnotes.patterns").inline_link) then
        vim.notify(("Mdn: Could not detect a valid inline link"), vim.log.levels.ERROR)
        return
    end

    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local text, dest = "", ""
    local col_start = 0
    local col_end = 0
    local new_text = ""
    local new_dest = ""
    local new_line = ""

    for start_pos, inline_link, end_pos in line:gmatch(require("mdnotes.patterns").inline_link) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            text, dest = inline_link:match(require("mdnotes.patterns").text_dest)
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    if rename_or_relink == "rename" then
        vim.ui.input({ prompt = "Rename link text '".. text .."' to: " },
        function(input)
            new_text = input
        end)

        if new_text == "" or new_text == nil then
            vim.notify(("Mdn: Please enter valid text"), vim.log.levels.ERROR)
            return
        end

        new_line = line:sub(1, col_start - 1) .. '[' .. new_text .. '](' .. dest .. ')' .. line:sub(col_end)
    elseif rename_or_relink == "relink" then

        vim.ui.input({ prompt = "Relink '".. dest .."' to: " },
        function(input)
            new_dest = input
        end)

        if new_dest == "" or new_dest == nil then
            vim.notify(("Mdn: Please enter valid text"), vim.log.levels.ERROR)
            return
        end

        new_line = line:sub(1, col_start - 1) .. '[' .. text .. '](' .. new_dest .. ')' .. line:sub(col_end)
    end

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_start})
end

function M.relink()
    rename_relink("relink")
end

function M.rename()
    rename_relink("rename")
end

function M.normalize()
    local check_md_format = require('mdnotes.formatting').check_md_format
    if not check_md_format(require("mdnotes.patterns").inline_link) then
        vim.notify(("Mdn: Could not detect a valid inline link"), vim.log.levels.ERROR)
        return
    end

    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local text, dest = "", ""
    local col_start = 0
    local col_end = 0
    local new_dest = ""
    local new_line = ""

    for start_pos, hyperlink, end_pos in line:gmatch(require("mdnotes.patterns").inline_link) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            text, dest = hyperlink:match(require("mdnotes.patterns").text_dest)
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    new_dest = vim.fs.normalize(dest)

    if new_dest:match("%s") then
        new_dest = "<" .. new_dest .. ">"
    end

    new_line = line:sub(1, col_start - 1) .. '[' .. text .. '](' .. new_dest .. ')' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

function M.validate(internal_call)
    if not internal_call then internal_call = false end

    local check_md_format = require('mdnotes.formatting').check_md_format

    if not check_md_format(require("mdnotes.patterns").inline_link) then
        vim.notify("Mdn: No valid inline link detected", vim.log.levels.WARN)
        return nil
    end

    local current_lnum = vim.fn.line('.')
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local text = ""
    local dest = ""
    local path = ""
    local section = ""

    for start_pos, inline_link, end_pos in line:gmatch(require("mdnotes.patterns").inline_link) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            text, dest = inline_link:match(require("mdnotes.patterns").text_dest)
            break
        end
    end

    if not dest or dest == "" then
        vim.notify(("Mdn: Nothing to open"), vim.log.levels.ERROR)
        return nil
    end

    if dest:match(" ") and not dest:match("<.+>") then
        vim.notify("Mdn: Destinations with spaces must be encircled with < and >. Execute ':Mdn inline_link normalize' for a quick fix.", vim.log.levels.ERROR)
        return nil
    end

    -- Remove any < or > from dest
    dest = dest:gsub("[<>]?", "")

    path = dest:match(require("mdnotes.patterns").uri_no_section) or ""
    section = dest:match(require("mdnotes.patterns").section) or ""

    -- Append .md to guarantee a file name
    if path ~= "" and path:sub(-3) ~= ".md" then
        path = path .. ".md"
    end

    -- Handle CURRENT_FILE.md#section and #section
    if path == "" then
        path = vim.fs.basename(vim.api.nvim_buf_get_name(0))
    end

    if not uv.fs_stat(path) and dest:match("%w+://") ~= "https://" then
        vim.notify("Mdn: Linked file not found", vim.log.levels.ERROR)
        return nil
    end

    if section ~= "" then
        local buf = vim.fn.bufadd(path)
        local search_ret = 0
        section = require('mdnotes.toc').get_section(section)

        vim.fn.bufload(buf)
        vim.api.nvim_buf_call(buf, function()
            search_ret = vim.fn.search("# " .. section)
        end)

        if search_ret == 0 then
            vim.notify("Mdn: Invalid section link", vim.log.levels.ERROR)
            return nil
        end
        vim.fn.cursor(current_lnum, current_col)
    end

    if internal_call == true then
        return text, dest, path, section
    end

    vim.notify("Mdn: Valid inline link", vim.log.levels.INFO)
end

function M.convert_section_to_gfm()
    local check_md_format = require('mdnotes.formatting').check_md_format
    if not check_md_format(require("mdnotes.patterns").inline_link) then
        vim.notify(("Mdn: Could not detect a valid inline link"), vim.log.levels.ERROR)
        return
    end

    local convert_text_to_gfm = require('mdnotes.toc').convert_text_to_gfm
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local text, dest = "", ""
    local col_start = 0
    local col_end = 0
    local new_section = ""
    local new_line = ""

    for start_pos, inline_link, end_pos in line:gmatch(require("mdnotes.patterns").inline_link) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            text, dest = inline_link:match(require("mdnotes.patterns").text_dest)
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    -- Remove any < or > from dest
    dest = dest:gsub("[<>]?", "")

    local section = dest:match(require("mdnotes.patterns").section) or ""
    new_section = convert_text_to_gfm(section)

    local hash_location = dest:find("#") or 1
    local new_dest = dest:sub(1, hash_location) .. new_section

    new_line = line:sub(1, col_start - 1) .. '[' .. text .. '](' .. new_dest .. ')' .. line:sub(col_end)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_start})
end

return M
