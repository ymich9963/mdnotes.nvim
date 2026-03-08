---@module 'mdnotes.inline_link'

local M = {}

local uv = vim.loop or vim.uv

---@type table<string> URIs that indicate websites
M.uri_website_tbl = {"https", "http"}

---@class MdnInlineLinkData: MdnInLineLocation
---@field img_char '"!"'|'""' Inline link image character
---@field text string Inline link text
---@field uri string Inline link URI ir destination

---Get the inline link data such as the image designator, link text, link URI/destination,
---and the start and end columns
---@param opts {inline_link: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation}?
---@return MdnInlineLinkData?
function M.parse(opts)
    opts = opts or {}

    local inline_link = opts.inline_link
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false

    vim.validate("inline_link", inline_link, { "string", "nil" })
    vim.validate("keep_pointy_brackets", keep_pointy_brackets, "boolean")

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local il_pattern = require("mdnotes.patterns").inline_link
    local txtdata

    -- Overwrite if location is given
    if opts.location or inline_link == nil then
        if not check_markdown_syntax(il_pattern, {location = opts.location}) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(il_pattern, { location = opts.location })
        inline_link = txtdata.text or ""
    end

    local text, uri = inline_link:match(require("mdnotes.patterns").text_uri)

    -- Remove any < or > from uri
    if keep_pointy_brackets == false then
        uri = uri:gsub("[<>]?", "")
    end

    local img_char = ""
    if M.is_image({ inline_link = inline_link }) == true then
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
---@param uri string URI to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string path, integer? error, string? error_text
function M.get_path_from_uri(uri, check_valid, opts)
    local path = ""
    if M.is_url({ uri = uri }) == true then return path, -1, "is URL" end

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
                return path, -2, "file not found"
            end
        else
            -- Handle [link](#fragment)
            path = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        end
    end

    return vim.fs.normalize(path), nil
end

---Check and get fragment from the URI
---@param uri string URI to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string? fragment, integer? error, string? error_text
function M.get_fragment_from_uri(uri, check_valid, opts)
    local fragment = ""
    if M.is_url({ uri = uri }) == true then return fragment, -1, "is URL" end

    opts = opts or {} -- unused

    vim.validate("uri", uri, "string")
    vim.validate("check_valid", check_valid, "boolean")

    fragment = uri:match(require("mdnotes.patterns").fragment) or ""

    if check_valid == true then
        if fragment ~= "" then

            -- Need path to open file to parse sections
            local path, err = M.get_path_from_uri(uri, true)
            if err ~= nil then
                return fragment, -2, "invalid path: " .. path .. ", " .. err
            end

            local buf
            if path ~= "" then
                buf = vim.fn.bufadd(path)
                vim.fn.bufload(buf)
            else
                -- path == "" on scratch buffers
                buf = vim.api.nvim_get_current_buf()
            end

            require('mdnotes').populate_buf_fragments(buf)

            local new_fragment = require('mdnotes').find_fragment_in_buf_fragments(buf, fragment)
            if new_fragment == nil then
                return fragment, -3, "fragment not parsed"
            end

            local search_ret = 0
            vim.api.nvim_buf_call(buf, function()
                search_ret = vim.fn.search("# " .. new_fragment)
            end)

            if search_ret == 0 then
                vim.notify("Mdn: Invalid fragment '" .. fragment .. "'", vim.log.levels.ERROR)
                return fragment, -4, "invalid fragment: ".. new_fragment
            end

            fragment = new_fragment
        end
    end

    return fragment, nil
end

---Open inline links in the appropriate programme
---@param opts {uri: string?, location: MdnInLineLocation?}?
---@return integer|vim.SystemObj|string?
function M.open(opts)
    opts = opts or {}

    -- Overwrite if location is given
    local uri = opts.uri
    if opts.location or uri == nil then
        uri = (M.parse({ keep_pointy_brackets = false, location = opts.location }) or {}).uri
    end

    if uri == nil then return "URI error" end

    vim.validate("uri", uri, "string")

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

---Check if inline link is an image
---@param opts {inline_link: string?, location: MdnInLineLocation}?
---@return boolean
function M.is_image(opts)
    opts = opts or {}

    local inline_link = opts.inline_link

    vim.validate("inline_link", inline_link, { "string", "nil" })

    if opts.location or inline_link == nil then
        local inline_link_pattern = require("mdnotes.patterns").inline_link
        local txtdata = require('mdnotes').get_text_in_pattern(inline_link_pattern, { location = opts.location })
        inline_link = txtdata.text or ""
    end

    if inline_link == nil or inline_link:sub(1,1) ~= "!" then
        return false
    else
        return true
    end
end

---Check if inline link is an image
---@param opts {uri: string?, location: MdnInLineLocation}?
---@return boolean is_url
function M.is_url(opts)
    opts = opts or {}

    local uri = opts.uri
    if opts.location or uri == nil then
        local mdn_patterns = require("mdnotes.patterns")
        local txtdata = require('mdnotes').get_text_in_pattern(mdn_patterns.inline_link, { location = opts.location })
        _, uri = txtdata.text:match(mdn_patterns.text_uri)
    end

    vim.validate("uri", uri, { "string", "nil" })

    if uri == nil or not vim.tbl_contains(M.uri_website_tbl, uri:match("%w+")) then
        return false
    else
        return true
    end
end

---Insert Markdown inline link with the text in the clipboard
---@param opts {uri: string?, move_cursor: boolean?, location: MdnInLineLocation}?
function M.insert(opts)
    opts = opts or {}
    local uri = opts.uri or vim.fn.getreg('+')
    local move_cursor = opts.move_cursor ~= false
    local locopts = opts.location or {}

    if uri == '' then
        vim.notify("Mdn: Nothing detected in clipboard, \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    local cur_col = vim.fn.col('.')
    local txtdata = require('mdnotes').get_text({ location = locopts })

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buffer, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {'[' .. txtdata.text .. '](' .. uri .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buffer)
        vim.fn.cursor({txtdata.lnum, cur_col + 1})
    end
end

---Delete Markdown inline link and leave the text
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.delete(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local locopts = opts.location or {}
    local ildata = M.parse({ location = locopts })

    if ildata == nil or ildata.text == nil or ildata.uri == nil then return end

    vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.text})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buffer)
        vim.fn.cursor({vim.fn.line('.'), ildata.col_start - 1})
    end
end

---Toggle inserting and deleting inline links
---@param opts {location: MdnInLineLocation?}?
function M.toggle(opts)
    opts = opts or {}
    local locopts = opts.location or {}

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    if check_markdown_syntax(require("mdnotes.patterns").inline_link, { location = locopts }) then
        M.delete({ location = locopts })
    else
        M.insert({ location = locopts })
    end
end

---Relink inline link
---@param opts {new_link: string?, move_cursor: boolean?, location: MdnInLineLocation?}?
function M.relink(opts)
    opts = opts or {}
    local new_link = opts.new_link
    local move_cursor = opts.move_cursor ~= false
    local locopts = opts.location or {}

    local ildata = M.parse({ location = locopts })
    if ildata == nil or ildata.text == nil or ildata.uri == nil then return end

    local user_input
    if new_link == nil then
        vim.ui.input({prompt = "Relink URI: ", default = ildata.uri }, function(input) user_input = input end)
    else
        user_input = new_link
    end

    if user_input == "" or user_input == nil then
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. user_input .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buffer)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Rename inline link
---@param opts {new_name: string?, move_cursor: boolean?, location: MdnInLineLocation?}?
function M.rename(opts)
    opts = opts or {}
    local new_name = opts.new_name
    local move_cursor = opts.move_cursor ~= false
    local locopts = opts.location or {}

    local ildata = M.parse({ location = locopts })
    if ildata == nil or ildata.text == nil or ildata.uri == nil then return end

    local user_input
    if new_name == nil then
        vim.ui.input({prompt = "Rename link text: ", default = ildata.text }, function(input) user_input = input end)
    else
        user_input = new_name
    end

    if user_input == "" or user_input == nil then
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. user_input .. '](' .. ildata.uri .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buffer)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Normalize inline link
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.normalize(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local locopts = opts.location or {}
    local ildata = M.parse({ location = locopts })
    local new_uri = ""

    if ildata == nil or ildata.text == nil or ildata.uri == nil then return end

    new_uri = vim.fs.normalize(ildata.uri)
    if new_uri:match("%s") then
        new_uri = "<" .. new_uri .. ">"
    end

    vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. new_uri .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buffer)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Convert the fragment of the inline link under the cursor to GFM-style fragment
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.convert_fragment_to_gfm(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local locopts = opts.location or {}
    local ildata = M.parse({ location = locopts })
    local new_fragment = ""
    local convert_text_to_gfm = require('mdnotes').convert_text_to_gfm

    if ildata == nil or ildata.text == nil then return end

    -- Remove any < or > from uri
    local uri = ildata.uri:gsub("[<>]?", "")

    local fragment = uri:match(require("mdnotes.patterns").fragment) or ""
    new_fragment = convert_text_to_gfm(fragment)

    local hash_location = uri:find("#") or 1
    local new_uri = uri:sub(1, hash_location) .. new_fragment

    vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.img_char .. '[' .. ildata.text .. '](' .. new_uri .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buffer)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Validate inline link without opening it
---@param opts {silent: boolean?, location: MdnInLineLocation?}?
---@return boolean valid, string error
function M.validate(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local locopts = opts.location or {}
    local ildata = M.parse({ location = locopts })

    if ildata == nil or ildata.text == nil or ildata.uri == nil then
        if silent == false then
            vim.notify("Mdn: No valid inline link detected", vim.log.level.WARN)
        end

        return false, "no valid inline link detected"
    end

    if ildata.uri:match(" ") and not ildata.uri:match("<.+>") then
        if silent == false then
            vim.notify("Mdn: Destinations with spaces must be enclosed with < and >. Execute ':Mdn inline_link normalize' for a quick fix", vim.log.levels.ERROR)
        end

        return false, "destinations with spaces must be enclosed with < and >"
    end

    ildata.uri = ildata.uri:gsub("[<>]?", "")

    local _, perror = M.get_path_from_uri(ildata.uri, true)
    if perror == -2 then
        if silent == false then
            vim.notify("Mdn: Inline link does not seem to point to a valid path", vim.log.level.WARN)
        end

        return false, "invalid path"
    end

    local _, ferror = M.get_fragment_from_uri(ildata.uri, true)
    if ferror ~= nil and ferror ~= -1 then
        if silent == false then
            vim.notify("Mdn: Inline link does not seem to point to a valid fragment", vim.log.level.WARN)
        end

        return false, "invalid fragment"
    end

    vim.notify("Mdn: Valid inline link", vim.log.levels.INFO)

    return true, "valid"
end

return M
