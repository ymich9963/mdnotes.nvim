---@module 'mdnotes.inline_link'

local M = {}

local uv = vim.loop or vim.uv

---@type table<string> URIs that indicate websites
M.uri_website_tbl = {"https", "http"}

---@class MdnInlineLinkData
---@field img_char '"!"'|'""' Inline link image character
---@field text string|nil Inline link text
---@field uri string|nil Inline link URI ir destination
---@field col_start integer|nil Column number where the inline link starts
---@field col_end integer|nil Column number where inline link ends

---Get the inline link data such as the image designator, link text, link URI/destination, and the start and end columns
---@param inline_link string? Inline link to extract data from
---@param keep_pointy_brackets boolean? Keep the < and > around the URI
---@return MdnInlineLinkData
function M.parse(inline_link, keep_pointy_brackets)
    if keep_pointy_brackets == nil then keep_pointy_brackets = true end

    local inline_link_pattern = require("mdnotes.patterns").inline_link
    local check_md_format_under_cursor = require('mdnotes.formatting').check_md_format_under_cursor
    local il, img_char, col_start, col_end = "", "", 0, 0

    if inline_link == nil then
        if not check_md_format_under_cursor(require("mdnotes.patterns").inline_link) then
            return {
                img_char = nil,
                text = nil,
                uri = nil,
                col_start = nil,
                col_end = nil
            }
        end
        il, col_start, col_end = require('mdnotes.formatting').get_text_in_pattern_under_cursor(inline_link_pattern)
    else
        il = inline_link
    end

    local text, uri = il:match(require("mdnotes.patterns").text_uri)

    -- Remove any < or > from uri
    if keep_pointy_brackets == false then
        uri = uri:gsub("[<>]?", "")
    end

    if M.is_image(il) == true then
        img_char = "!"
    end

    return {
        img_char = img_char,
        text = text,
        uri = uri,
        col_start = col_start,
        col_end = col_end
    }
end

---Check and get path from the URI
---@param uri string URI to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@return string|nil path
function M.get_path_from_uri(uri, check_valid)
    if M.is_url(uri) == true then return "" end

    local path = uri:match(require("mdnotes.patterns").uri_no_fragment) or ""

    if check_valid == true then
        if path ~= "" then
            -- Check if absolute path first
            -- If it doesn't exist then create a relative path
            if not uv.fs_stat(path) then
                path = vim.fs.joinpath(require('mdnotes').cwd, path)
            end

            -- If a Markdown file exists then it is a Markdown file
            -- GitHub does not like it when there is no .md in the inline link
            if uv.fs_stat(path .. ".md") then
                path = path .. ".md"
            end

            -- If the path is still not found, check if it's a URL
            if not uv.fs_stat(path) then
                if not vim.tbl_contains(M.uri_website_tbl, path:match("%w+")) then
                    vim.notify("Mdn: Linked file at '" .. path .. "' not found", vim.log.levels.ERROR)
                    return nil
                end
            end
        else
            -- Handle [link](#fragment)
            path = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        end
    end

    return vim.fs.normalize(path)
end

---Check and get fragment from the URI
---@param uri string URI to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param move_cursor boolean Whether to move the cursor to where the fragment was found
---@return string|nil fragment
function M.get_fragment_from_uri(uri, check_valid, move_cursor)
    local fragment = uri:match(require("mdnotes.patterns").fragment) or ""
    local cur_pos = vim.fn.getpos('.')

    if M.is_url(uri) == true then fragment = "" end

    -- Need path to open file to parse sections
    local path = M.get_path_from_uri(uri, true)

    if check_valid == true then
        if fragment ~= "" then
            local buf = nil

            if path ~= "" then
                buf = vim.fn.bufadd(path)
            else
                -- Handle [link](#fragment)
                buf = vim.api.nvim_get_current_buf()
            end
            vim.fn.bufload(buf)

            require('mdnotes.toc').populate_buf_fragments(buf)
            local new_fragment = require('mdnotes.toc').get_fragment_from_gfm(fragment)

            local search_ret = 0
            vim.api.nvim_buf_call(buf, function()
                search_ret = vim.fn.search("# " .. new_fragment)
            end)

            if search_ret == 0 then
                vim.notify("Mdn: Invalid fragment", vim.log.levels.ERROR)
                return nil
            end
        end
    end

    if move_cursor == false then
        vim.fn.setpos('.', cur_pos)
    end

    return fragment
end

---Open inline links
---@param uri string? URI to open
---@return integer|vim.SystemObj|nil
function M.open(uri)
    if uri == nil then
        uri = (M.parse(nil, false)).uri
    end
    if uri == nil then return -1 end

    local path = M.get_path_from_uri(uri, true)
    if path == nil then return -2 end

    local fragment = M.get_fragment_from_uri(uri, true, true)
    if fragment == nil then return -3 end

    -- Check if the file exists and is a Markdown file
    if uv.fs_stat(path) and path:sub(-3) == ".md" then
        require('mdnotes').open_buf(path)
        if fragment ~= "" then
            -- Navigate to fragment
            fragment = require('mdnotes.toc').get_fragment_from_gfm(fragment)
            vim.fn.cursor(vim.fn.search("# " .. fragment), 1)
            vim.api.nvim_input('zz')
        end

        return vim.api.nvim_get_current_buf()
    end

    return vim.ui.open(uri)
end

---Check if inline link is an image
---@param inline_link string?
---@return boolean|string
function M.is_image(inline_link)
    local inline_link_pattern = require("mdnotes.patterns").inline_link
    if inline_link == nil then
        inline_link = require('mdnotes.formatting').get_text_in_pattern_under_cursor(inline_link_pattern)
    end

    if inline_link:sub(1,1) == "!" then
        return true
    else
        return false
    end
end

---Check if inline link is an image
---@param uri string?
---@return boolean is_url Text to use when checking for an inline link
function M.is_url(uri)
    local inline_link_pattern = require("mdnotes.patterns").inline_link
    if uri == nil then
        local inline_link = require('mdnotes.formatting').get_text_in_pattern_under_cursor(inline_link_pattern)
        _, uri = inline_link:match(require("mdnotes.patterns").text_uri)
    end

    if vim.tbl_contains(M.uri_website_tbl, uri:match("%w+")) then
        return true
    else
        return false
    end
end

---Insert Markdown inline link with the text in the clipboard
---@param uri string? Text to use in URI
function M.insert(uri)
    if uri == nil then uri = vim.fn.getreg('+') end

    if uri == '' then
        vim.notify("Mdn: Nothing detected in clipboard, \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    local cur_col = vim.fn.col('.')
    local selected_text, col_start, col_end = require('mdnotes.formatting').get_selected_text()
    local lnum = vim.fn.line('.')

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(0, lnum - 1, col_start - 1, lnum - 1, col_end, {'[' .. selected_text .. '](' .. uri .. ')'})
    vim.fn.cursor({lnum, cur_col + 1})
end

--Delete Markdown inline link and leave the text
function M.delete()
    local ildata = M.parse()
    local lnum = vim.fn.line('.')

    if ildata.text == nil or ildata.uri == nil then return end

    vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.text})
    vim.fn.cursor({vim.fn.line('.'), ildata.col_start - 1})
end

---Toggle inserting and deleting inline links
function M.toggle()
    local check_md_format_under_cursor = require('mdnotes.formatting').check_md_format_under_cursor
    if check_md_format_under_cursor(require("mdnotes.patterns").inline_link) then
        M.delete()
    else
        M.insert()
    end
end

---Rename or relink an inline link
---@param mode '"rename"'|'"relink"'
---@param new_text string?
local function rename_relink(mode, new_text)
    local ildata = M.parse()
    local user_input = ""
    local lnum = vim.fn.line('.')
    local args = {}

    if ildata.text == nil or ildata.uri == nil then return end

    if mode == "rename" then
        args.prompt = "Rename link text: "
        args.default = ildata.text
    elseif mode == "relink" then
        args.prompt = "Relink URI: "
        args.default = ildata.uri
    end

    if new_text == nil then
        vim.ui.input(args, function(input) user_input = input end)
    else
        user_input = new_text
    end

    if user_input == "" or user_input == nil then
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        return
    end

    if mode == "rename" then
        vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. user_input .. '](' .. ildata.uri .. ')'})
    elseif mode == "relink" then
        vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. user_input .. ')'})
    end

    vim.fn.cursor({lnum, ildata.col_start})
end

---Relink inline link
---@param new_text string?
function M.relink(new_text)
    rename_relink("relink", new_text)
end

---Rename inline link
---@param new_text string?
function M.rename(new_text)
    rename_relink("rename", new_text)
end

---Normalize inline link
function M.normalize()
    local ildata = M.parse()
    local new_uri = ""
    local lnum = vim.fn.line('.')

    if ildata.text == nil or ildata.uri == nil then return end

    new_uri = vim.fs.normalize(ildata.uri)
    if new_uri:match("%s") then
        new_uri = "<" .. new_uri .. ">"
    end

    vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. new_uri .. ')'})
    vim.fn.cursor({lnum, ildata.col_start})
end

---Convert the fragment of the inline link under the cursor to GFM-style fragment
function M.convert_fragment_to_gfm()
    local ildata = M.parse()
    local uri = ildata.uri
    local new_fragment = ""
    local lnum = vim.fn.line('.')
    local convert_text_to_gfm = require('mdnotes.toc').convert_text_to_gfm

    if ildata.text == nil or uri == nil then return end

    -- Remove any < or > from uri
    uri = uri:gsub("[<>]?", "")

    local fragment = uri:match(require("mdnotes.patterns").fragment) or ""
    new_fragment = convert_text_to_gfm(fragment)

    local hash_location = uri:find("#") or 1
    local new_uri = uri:sub(1, hash_location) .. new_fragment

    vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. new_uri .. ')'})
    vim.fn.cursor({lnum, ildata.col_start})
end

function M.validate()
    local ildata = M.parse(nil, true)
    if ildata.text == nil or ildata.uri == nil then
        vim.notify("Mdn: No valid inline link detected", vim.log.level.WARN)
        return nil
    end

    if ildata.uri:match(" ") and not ildata.uri:match("<.+>") then
        vim.notify("Mdn: Destinations with spaces must be enclosed with < and >. Execute ':Mdn inline_link normalize' for a quick fix", vim.log.levels.ERROR)
        return nil
    end

    ildata.uri = ildata.uri:gsub("[<>]?", "")

    local path = M.get_path_from_uri(ildata.uri, true)
    if path == nil then
        vim.notify("Mdn: Inline link does not seem to point to a valid path", vim.log.level.WARN)
        return nil
    end

    local fragment = M.get_fragment_from_uri(ildata.uri, true, false)
    if fragment == nil then
        vim.notify("Mdn: Inline link does not seem to point to a valid fragment", vim.log.level.WARN)
        return nil
    end

    vim.notify("Mdn: Valid inline link", vim.log.levels.INFO)
end

return M
