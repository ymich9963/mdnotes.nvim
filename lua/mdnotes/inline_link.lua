---@module 'mdnotes.inline_link'
local M = {}

local uv = vim.loop or vim.uv

---@type table<string> URIs that indicate websites
M.uri_website_tbl = {"https", "http"}

---Check if inline link is an image
---@param inline_link string
---@return '"!"'|'""' img_text Text to use when checking for an inline link
local function is_img(inline_link)
    if inline_link:sub(1,1) == "!" then
        return "!"
    else
        return ""
    end
end

---Check and validate that the inline link detected is valid
---@param internal_call boolean? Set if called internally to return inline link data
---@param norm boolean? Only set when used internall within the normalize() function 
---@param ignore_fragment boolean? Set to ignore the fragment check
---@return nil
function M.validate(internal_call, norm, ignore_fragment)
    if not internal_call then internal_call = false end
    if not norm then norm = false end
    if not ignore_fragment then ignore_fragment = false end

    local check_md_format = require('mdnotes.formatting').check_md_format

    if not check_md_format(require("mdnotes.patterns").inline_link) then
        vim.notify("Mdn: No valid inline link detected", vim.log.levels.WARN)
        return nil
    end

    local current_lnum = vim.fn.line('.')
    local current_col = vim.fn.col('.')
    local line = vim.api.nvim_get_current_line()
    local col_start = 0
    local col_end = 0
    local img_txt = ""
    local text = ""
    local uri = ""
    local path = ""
    local fragment = ""

    for start_pos, inline_link, end_pos in line:gmatch(require("mdnotes.patterns").inline_link) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos < current_col and end_pos > current_col then
            img_txt = is_img(inline_link)
            text, uri = inline_link:match(require("mdnotes.patterns").text_uri)
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    if not uri or uri == "" then
        vim.notify(("Mdn: No URI detected"), vim.log.levels.ERROR)
        return nil
    end

    if uri:match(" ") and not uri:match("<.+>") then
        if norm == false then
            vim.notify("Mdn: Destinations with spaces must be encircled with < and >. Execute ':Mdn inline_link normalize' for a quick fix.", vim.log.levels.ERROR)
            return nil
        end
    end

    -- Remove any < or > from uri
    uri = uri:gsub("[<>]?", "")

    path = uri:match(require("mdnotes.patterns").uri_no_fragment) or ""
    fragment = uri:match(require("mdnotes.patterns").fragment) or ""

    if path ~= "" then
        if not uv.fs_stat(path) and not uv.fs_stat(path .. ".md") then
            if not vim.tbl_contains(M.uri_website_tbl, path:match("%w+")) then
                vim.notify("Mdn: Linked file not found", vim.log.levels.ERROR)
                return nil
            end
        end

        -- Append .md to guarantee a file name
        if path ~= "" and path:sub(-3) ~= ".md"then
            path = path .. ".md"
        end
    else
        -- Handle #fragment
        path = vim.fs.basename(vim.api.nvim_buf_get_name(0))
    end

    if fragment ~= "" and ignore_fragment == false then
        local buf = vim.fn.bufadd(path)
        local search_ret = 0
        fragment = require('mdnotes.toc').get_fragment(fragment)

        vim.fn.bufload(buf)
        vim.api.nvim_buf_call(buf, function()
            search_ret = vim.fn.search("# " .. fragment)
        end)

        if search_ret == 0 then
            vim.notify("Mdn: Invalid fragment link", vim.log.levels.ERROR)
            return nil
        end
        vim.fn.cursor(current_lnum, current_col)
    end

    if internal_call == true then
        return {img_txt, text, uri, path, fragment, col_start, col_end}
    end

    vim.notify("Mdn: Valid inline link", vim.log.levels.INFO)
end

---Insert Markdown inline link with the text in the clipboard
function M.insert()
    local reg = vim.fn.getreg('+')

    -- Set if empty
    if reg == '' then
        vim.notify("Mdn: Nothing detected in clipboard; \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    -- Sanitize text to prevent chaos
    vim.fn.setreg('+', reg:gsub("[%c]", ""))

    local line = vim.api.nvim_get_current_line()
    local selected_text, col_start, col_end = require('mdnotes.formatting').get_selected_text()

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. '[' .. selected_text .. '](' .. reg .. ')' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

--Delete Markdown inline link and leave the text
function M.delete()
    local validate_tbl = require('mdnotes.inline_link').validate(true) or {}
    local _, text, uri, _, _, col_start, col_end = unpack(validate_tbl)
    local line = vim.api.nvim_get_current_line()

    if not text or not uri then return end

    -- Create a new modified line with link
    local new_line = line:sub(1, col_start - 1) .. text .. line:sub(col_end)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_start - 1})
end

---Toggle inserting and deleting inline links
function M.toggle()
    local check_md_format = require('mdnotes.formatting').check_md_format
    if check_md_format(require("mdnotes.patterns").inline_link) then
        M.delete()
    else
        M.insert()
    end
end

---Rename or relink an inline link
---@param rename_or_relink '"rename"'|'"relink"'
local function rename_relink(rename_or_relink)
    local validate_tbl = require('mdnotes.inline_link').validate(true) or {}
    local img_txt, text, uri, _, _, col_start, col_end = unpack(validate_tbl)
    local user_input = ""
    local new_line = ""
    local line = vim.api.nvim_get_current_line()
    local args = {}

    if not text or not uri then return end

    if rename_or_relink == "rename" then
        args.prompt = "Rename link text: "
        args.default = text
    elseif rename_or_relink == "relink" then
        args.prompt = "Relink URI: "
        args.default = uri
    end

    vim.ui.input(args, function(input) user_input = input end)

    if user_input == "" or user_input == nil then
        vim.notify(("Mdn: Please enter valid text"), vim.log.levels.ERROR)
        return
    end

    if rename_or_relink == "rename" then
        new_line = line:sub(1, col_start - 1) .. img_txt .. '[' .. user_input .. '](' .. uri .. ')' .. line:sub(col_end)
    elseif rename_or_relink == "relink" then
        new_line = line:sub(1, col_start - 1) .. img_txt .. '[' .. text .. '](' .. user_input .. ')' .. line:sub(col_end)
    end

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_start})
end

---Relink inline link
function M.relink()
    rename_relink("relink")
end

---Rename inline link
function M.rename()
    rename_relink("rename")
end

---Normalize inline link
function M.normalize()
    local validate_tbl = require('mdnotes.inline_link').validate(true, true) or {}
    local img_txt, text, uri, _, _, col_start, col_end = unpack(validate_tbl)
    local new_uri = ""
    local new_line = ""
    local line = vim.api.nvim_get_current_line()

    if not text or not uri then return end

    new_uri = vim.fs.normalize(uri)
    if new_uri:match("%s") then
        new_uri = "<" .. new_uri .. ">"
    end

    new_line = line:sub(1, col_start - 1) .. img_txt .. '[' .. text .. '](' .. new_uri .. ')' .. line:sub(col_end + 1)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_end + 2})
end

---Convert the fragment to GFM-style fragment
function M.convert_fragment_to_gfm()
    local validate_tbl = require('mdnotes.inline_link').validate(true) or {}
    local img_txt, text, uri, _, _, col_start, col_end = unpack(validate_tbl)
    local new_line = ""
    local new_fragment = ""
    local line = vim.api.nvim_get_current_line()
    local convert_text_to_gfm = require('mdnotes.toc').convert_text_to_gfm

    if not text or not uri then return end

    -- Remove any < or > from uri
    uri = uri:gsub("[<>]?", "")

    local fragment = uri:match(require("mdnotes.patterns").fragment) or ""
    new_fragment = convert_text_to_gfm(fragment)

    local hash_location = uri:find("#") or 1
    local new_uri = uri:sub(1, hash_location) .. new_fragment

    new_line = line:sub(1, col_start - 1) .. img_txt .. '[' .. text .. '](' .. new_uri .. ')' .. line:sub(col_end)

    -- Set the line and cursor position
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, {vim.fn.line('.'), col_start})
end

return M
