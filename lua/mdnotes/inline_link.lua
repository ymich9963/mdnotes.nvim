---@module 'mdnotes.inline_link'

local M = {}

local uv = vim.loop or vim.uv

---@type table<string> URIs that indicate websites
M.uri_website_tbl = {"https", "http"}

---@class MdnInlineLinkData: MdnLocation
---@field img_char '"!"'|'""' Inline link image character
---@field text string Inline link text
---@field uri string Inline link URI ir destination

---Get the inline link data such as the image designator, link text, link URI/destination,
---and the start and end columns
---@param opts {inline_link: string?, keep_pointy_brackets: boolean?, location: MdnLocation}?
---@return MdnInlineLinkData|nil
function M.parse(opts)
    opts = opts or {}

    -- If location is provided ignore the inline_link string
    local inline_link
    if opts.location then
        inline_link = nil
    else
        inline_link = opts.inline_link
    end

    local locopts = opts.location or {}
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false

    vim.validate("inline_link", inline_link, { "string", "nil" })
    vim.validate("keep_pointy_brackets", keep_pointy_brackets, "boolean")

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local il_pattern = require("mdnotes.patterns").inline_link
    local txtdata

    if inline_link == nil then
        if not check_markdown_syntax(il_pattern, {location = locopts}) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(il_pattern, {location = locopts })
        inline_link = txtdata.text or ""
    end

    local text, uri = inline_link:match(require("mdnotes.patterns").text_uri)

    -- Remove any < or > from uri
    if keep_pointy_brackets == false then
        uri = uri:gsub("[<>]?", "")
    end

    local img_char = ""
    if M.is_image(inline_link) == true then
        img_char = "!"
    end

    -- Table key 'text' also exists in txtdata but does not get ovewritten with "keep" behaviour
    return vim.tbl_extend("keep", {
        img_char = img_char,
        text = text,
        uri = uri,
    }, txtdata)
end

---Check and get path from the URI
---Error codes:
--- -1 : is URL
--- -2 : file not found
---@param uri string URI to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string path, integer|nil error
function M.get_path_from_uri(uri, check_valid, opts)
    local path = ""
    if M.is_url(uri) == true then return path, -1 end

    opts = opts or {} -- unused

    vim.validate("uri", uri, "string")
    vim.validate("check_valid", check_valid, "boolean")

    local cwd =require('mdnotes').cwd
    path = uri:match(require("mdnotes.patterns").uri_no_fragment) or ""

    if check_valid == true then
        if path ~= "" then

            -- Check if absolute path first
            if uv.fs_stat(path) then
                return vim.fs.abspath(path), nil
            end

            path = vim.fs.joinpath(cwd, path)

            -- If a Markdown file exists then it is a Markdown file
            -- GitHub does not like it when there is no .md in the inline link
            if uv.fs_stat(path .. ".md") then
                path = path .. ".md"
            end

            -- If the path is still not found, check if it's a URL
            if not uv.fs_stat(path) then
                vim.notify("Mdn: Linked file at '" .. path .. "' not found", vim.log.levels.ERROR)
                return path, -2
            end
        else
            -- Handle [link](#fragment)
            path = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        end
    end

    return vim.fs.normalize(path), nil
end

---Check and get fragment from the URI
---Error codes:
--- -1 : is URL
--- -2 : invalid path, error_text contains detected path and error
--- -3 : fragment not parsed
--- -4 : invalid fragment, error_text contains value retrieved from buf_fragments
---@param uri string URI to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string|nil fragment, number|nil error, string|nil error_text
function M.get_fragment_from_uri(uri, check_valid, opts)
    local fragment = ""
    if M.is_url(uri) == true then return fragment, -1 end

    opts = opts or {} -- unused

    vim.validate("uri", uri, "string")
    vim.validate("check_valid", check_valid, "boolean")

    fragment = uri:match(require("mdnotes.patterns").fragment) or ""

    if check_valid == true then
        if fragment ~= "" then

            -- Need path to open file to parse sections
            local path, err = M.get_path_from_uri(uri, true)
            if err ~= nil then
                return fragment, -2, path .. ", " .. err
            end

            local buf
            if path ~= "" then
                buf = vim.fn.bufadd(path)
                vim.fn.bufload(buf)
            else
                -- path == "" on scratch buffers
                buf = vim.api.nvim_get_current_buf()
            end

            local mdn_toc = require('mdnotes.toc')
            mdn_toc.populate_buf_fragments(buf)

            local new_fragment = mdn_toc.get_fragment_from_buf_fragments(buf, fragment)
            if new_fragment == nil then
                return fragment, -3
            end

            local search_ret = 0
            vim.api.nvim_buf_call(buf, function()
                search_ret = vim.fn.search("# " .. new_fragment)
            end)

            if search_ret == 0 then
                vim.notify("Mdn: Invalid fragment '" .. fragment .. "'", vim.log.levels.ERROR)
                return fragment, -4, new_fragment
            end

            fragment = new_fragment
        end
    end

    return fragment, nil
end

--TODO: Add location opts
---Open inline links
---@param uri string? URI to open
function M.open(uri)
    if uri == nil then
        local ildata = M.parse({ keep_pointy_brackets = false }) or {}
        uri = ildata.uri
    end
    if uri == nil then return "URI error" end

    local path, perror = M.get_path_from_uri(uri, true)
    if perror ~= nil and perror ~= -1 then return path .. ", " .. perror end

    local fragment, ferror = M.get_fragment_from_uri(uri, true)
    if ferror ~= nil and ferror ~= -1 then return fragment .. ", " .. ferror end

    -- Check if the file exists and is a Markdown file
    if path ~= "" and uv.fs_stat(path) and path:sub(-3) == ".md" then
        require('mdnotes').open_buf(path)
        if fragment ~= "" then
            -- Navigate to fragment
            vim.fn.cursor(vim.fn.search("# " .. fragment), 1)
            vim.api.nvim_input('zz')
        end

        return vim.api.nvim_get_current_buf()
    end

    return vim.ui.open(uri)
end

--TODO: Add location opts
---Check if inline link is an image
---@param inline_link string?
---@return boolean
function M.is_image(inline_link)
    local inline_link_pattern = require("mdnotes.patterns").inline_link
    if inline_link == nil then
        local txtdata = require('mdnotes').get_text_in_pattern(inline_link_pattern)
        inline_link = txtdata.text
    end

    if inline_link == nil or inline_link:sub(1,1) ~= "!" then
        return false
    else
        return true
    end
end

--TODO: Add location opts
---Check if inline link is an image
---@param uri string?
---@return boolean is_url Text to use when checking for an inline link
function M.is_url(uri)
    local mdn_patterns = require("mdnotes.patterns")
    local inline_link_pattern = mdn_patterns.inline_link
    if uri == nil then
        local txtdata = require('mdnotes').get_text_in_pattern(inline_link_pattern)
        _, uri = txtdata.text:match(mdn_patterns.text_uri)
    end

    if vim.tbl_contains(M.uri_website_tbl, uri:match("%w+")) then
        return true
    else
        return false
    end
end

--TODO: Add location opts
---Insert Markdown inline link with the text in the clipboard
---@param uri string? Text to use in URI
function M.insert(uri, move_cursor)
    if uri == nil then uri = vim.fn.getreg('+') end
    if move_cursor == nil then move_cursor = true end

    if uri == '' then
        vim.notify("Mdn: Nothing detected in clipboard, \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    local cur_col = vim.fn.col('.')
    local txtdata = require('mdnotes').get_text()

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buffer, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {'[' .. txtdata.text .. '](' .. uri .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buffer)
        vim.fn.cursor({txtdata.lnum, cur_col + 1})
    end
end

--TODO: Add location opts
--Delete Markdown inline link and leave the text
function M.delete()
    local ildata = M.parse()
    local lnum = vim.fn.line('.')

    if ildata == nil or ildata.text == nil or ildata.uri == nil then return end

    vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.text})
    vim.fn.cursor({vim.fn.line('.'), ildata.col_start - 1})
end

--TODO: Add location opts
---Toggle inserting and deleting inline links
function M.toggle()
    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    if check_markdown_syntax(require("mdnotes.patterns").inline_link) then
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
    local args = {}

    if ildata == nil or ildata.text == nil or ildata.uri == nil then return end

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
        vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. user_input .. '](' .. ildata.uri .. ')'})
    elseif mode == "relink" then
        vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. user_input .. ')'})
    end

    vim.fn.cursor({ildata.lnum, ildata.col_start})
end

--TODO: Add location opts and move parsing to outside rename_relink
---Relink inline link
---@param new_text string?
function M.relink(new_text)
    rename_relink("relink", new_text)
end

--TODO: Add location opts and move parsing to outside rename_relink
---Rename inline link
---@param new_text string?
function M.rename(new_text)
    rename_relink("rename", new_text)
end

--TODO: Add location opts
---Normalize inline link
function M.normalize()
    local ildata = M.parse()
    local new_uri = ""
    local lnum = vim.fn.line('.')

    if ildata == nil or ildata.text == nil or ildata.uri == nil then return end

    new_uri = vim.fs.normalize(ildata.uri)
    if new_uri:match("%s") then
        new_uri = "<" .. new_uri .. ">"
    end

    vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. new_uri .. ')'})
    vim.fn.cursor({lnum, ildata.col_start})
end

--TODO: Add location opts
---Convert the fragment of the inline link under the cursor to GFM-style fragment
function M.convert_fragment_to_gfm()
    local ildata = M.parse()
    local new_fragment = ""
    local lnum = vim.fn.line('.')
    local convert_text_to_gfm = require('mdnotes.toc').convert_text_to_gfm

    if ildata == nil or ildata.text == nil then return end

    -- Remove any < or > from uri
    local uri = ildata.uri:gsub("[<>]?", "")

    local fragment = uri:match(require("mdnotes.patterns").fragment) or ""
    new_fragment = convert_text_to_gfm(fragment)

    local hash_location = uri:find("#") or 1
    local new_uri = uri:sub(1, hash_location) .. new_fragment

    vim.api.nvim_buf_set_text(0, lnum - 1, ildata.col_start - 1, lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. new_uri .. ')'})
    vim.fn.cursor({lnum, ildata.col_start})
end

--TODO: Add location opts
---Validate that the inline link is correct
function M.validate()
    local ildata = M.parse()
    if ildata == nil or ildata.text == nil or ildata.uri == nil then
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

    local fragment = M.get_fragment_from_uri(ildata.uri, true)
    if fragment == nil then
        vim.notify("Mdn: Inline link does not seem to point to a valid fragment", vim.log.level.WARN)
        return nil
    end

    vim.notify("Mdn: Valid inline link", vim.log.levels.INFO)
end

return M
