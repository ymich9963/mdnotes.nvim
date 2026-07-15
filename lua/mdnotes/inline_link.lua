---@module 'mdnotes.inline_link'

local M = {}

local uv = vim.loop or vim.uv

---@class MdnInlineLinkData: MdnInLineLocation
---@field img_char '"!"'|'""' Inline link image character
---@field text string Inline link text
---@field destination string Inline link destination
---@field title string Inline link title

---Get the inline link data such as the image designator, link text, link destination,
---and the start and end columns
---@param opts {inline_link: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation?}?
---@return MdnInlineLinkData?
function M.parse(opts)
    opts = opts or {}

    local inline_link = opts.inline_link
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false

    vim.validate("inline_link", inline_link, { "string", "nil" })
    vim.validate("keep_pointy_brackets", keep_pointy_brackets, "boolean")

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local il_pattern = require("mdnotes.patterns").inline_link
    local txtdata = {}

    -- Overwrite if location is given
    if opts.location ~= nil or inline_link == nil then
        if not check_markdown_syntax(il_pattern, { location = opts.location }) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(il_pattern, { location = opts.location })
        inline_link = txtdata.text or ""
    end

    local text, destination = inline_link:match(require("mdnotes.patterns").text_dest)
    local title = destination:match(require("mdnotes.patterns").dest_title) or ""
    if title ~= "" then
        destination = destination:sub(1, #destination - #title - 3) -- 2 quotes and 1 space
    end

    -- Remove any < or > from destination
    if keep_pointy_brackets == false then
        destination = destination:gsub("[<>]?", "")
    end

    local img_char = ""
    if M.is_image({ inline_link = inline_link }) == true then
        img_char = "!"
    end

    -- Table key 'text' also exists in txtdata but does not get ovewritten with "keep" behaviour
    return vim.tbl_extend("keep", {
        img_char = img_char,
        text = text,
        destination = destination,
        title = title,
    }, txtdata)
end

---Get an inline link string from an MdnInlineLinkData object
---@param ildata MdnInlineLinkData? Inline link object
---@return string inline_link
function M.get_il_from_obj(ildata)
    if ildata == nil then return "" end
    if ildata.title == nil or ildata.title == "" then
        return ildata.img_char .. '[' .. ildata.text .. '](' .. ildata.destination .. ')'
    else
        return ildata.img_char .. '[' .. ildata.text .. '](' .. ildata.destination .. ' "' .. ildata.title .. '")'
    end
end

---Check and get path from the destination
---@param destination string destination to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string path, integer? error, string? error_text
function M.get_path_from_destination(destination, check_valid, opts)
    local path = ""
    if M.is_url({ destination = destination }) == true then return path, -1, "is URL" end

    opts = opts or {} -- unused

    vim.validate("destination", destination, "string")
    vim.validate("check_valid", check_valid, "boolean")

    local cwd =require('mdnotes').cwd
    path = destination:match(require("mdnotes.patterns").dest_no_fragment) or ""

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

---Check and get fragment from the destination
---@param destination string destination to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string? fragment, integer? error, string? error_text
function M.get_fragment_from_destination(destination, check_valid, opts)
    local fragment = ""
    if M.is_url({ destination = destination }) == true then return fragment, -1, "is URL" end

    opts = opts or {} -- unused

    vim.validate("destination", destination, "string")
    vim.validate("check_valid", check_valid, "boolean")

    fragment = destination:match(require("mdnotes.patterns").fragment) or ""

    if check_valid == true then
        if fragment ~= "" then

            -- Need path to open file to parse sections
            local path, err = M.get_path_from_destination(destination, true)
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
---@param opts {inline_link: string?, location: MdnInLineLocation?}?
---@return integer|vim.SystemObj|string?
function M.open(opts)
    opts = opts or {}

    local inline_link = opts.inline_link

    vim.validate("inline_link", inline_link, {"string", "nil"})

    local ildata

    -- Prefer to use the inline link parameter
    if inline_link == nil then
        ildata = M.parse({ keep_pointy_brackets = false, location = opts.location })
    else
        ildata = M.parse({ inline_link = inline_link, keep_pointy_brackets = false })
    end

    -- If no inline link under cursor and no inline link was given, open picker
    if ildata == nil then
        inline_link = M.get_il_from_picker()
        ildata = M.parse({ inline_link = inline_link, keep_pointy_brackets = false })
    end

    if ildata == nil then return end

    local destination = ildata.destination
    if destination == nil then return "destination error" end

    local path, perror = M.get_path_from_destination(destination, true)
    if perror ~= nil and perror ~= -1 then return path .. ", " .. perror end

    local fragment, ferror = M.get_fragment_from_destination(destination, true)
    if ferror ~= nil and ferror ~= -1 then return fragment .. ", " .. ferror end

    -- Check if the file exists and is a Markdown file
    if path ~= "" and uv.fs_stat(path) and vim.endswith(path, ".md") then
        require('mdnotes').open_buf(path)
        if fragment ~= "" then
            -- Navigate to fragment
            vim.fn.cursor(vim.fn.search("# " .. fragment), 1)
            vim.api.nvim_input('zz')
        end

        return vim.api.nvim_get_current_buf()
    end

    return vim.ui.open(destination)
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
---@param opts {destination: string?, location: MdnInLineLocation}?
---@return boolean is_url
function M.is_url(opts)
    opts = opts or {}

    local destination = opts.destination
    if opts.location or destination == nil then
        local mdn_patterns = require("mdnotes.patterns")
        local txtdata = require('mdnotes').get_text_in_pattern(mdn_patterns.inline_link, { location = opts.location })
        _, destination = txtdata.text:match(mdn_patterns.text_dest)
    end

    vim.validate("destination", destination, { "string", "nil" })

    if destination == nil or not vim.tbl_contains({"http", "https"}, destination:match("%w+")) then
        return false
    else
        return true
    end
end

---Insert Markdown inline link with the text in the clipboard
---@param opts {destination: string?, move_cursor: boolean?, location: MdnInLineLocation}?
function M.insert(opts)
    opts = opts or {}
    local destination = opts.destination or vim.fn.getreg('+')
    local move_cursor = opts.move_cursor ~= false

    if destination == '' then
        vim.notify("Mdn: Nothing detected in clipboard, \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    local txtdata = require('mdnotes').get_text({ location = opts.location })

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {'[' .. txtdata.text .. '](' .. destination .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') + 1})
    end
end

---Delete Markdown inline link and leave the text
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?, store: boolean?}?
function M.delete(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local store = opts.store or false
    local ildata = M.parse({ location = opts.location })

    if ildata == nil or ildata.text == nil or ildata.destination == nil then return end

    vim.api.nvim_buf_set_text(ildata.buf, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.text})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({vim.fn.line('.'), ildata.col_start - 1})
    end

    if store == true then
        vim.fn.setreg('+', ildata.destination)
    end
end

---Toggle inserting and deleting inline links
---@param opts {destination: string?, location: MdnInLineLocation?}?
function M.toggle(opts)
    opts = opts or {}

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    if check_markdown_syntax(require("mdnotes.patterns").inline_link, { location = opts.location }) then
        M.delete({ location = opts.location, store = true })
    else
        M.insert({ destination = opts.destination, location = opts.location })
    end
end

---Relink inline link
---@param opts {new_link: string?, move_cursor: boolean?, location: MdnInLineLocation?}?
function M.relink(opts)
    opts = opts or {}
    local new_link = opts.new_link
    local move_cursor = opts.move_cursor ~= false

    local ildata = M.parse({ location = opts.location })
    if ildata == nil or ildata.text == nil or ildata.destination == nil then return end

    local user_input
    if new_link == nil then
        vim.ui.input({prompt = "Relink destination: ", default = ildata.destination }, function(input) user_input = input end)
    else
        user_input = new_link
    end

    if user_input == "" or user_input == nil then
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        return
    end

    ildata.destination = user_input
    local new_il = M.get_il_from_obj(ildata)

    vim.api.nvim_buf_set_text(ildata.buf, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {new_il})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Rename inline link
---@param opts {new_name: string?, move_cursor: boolean?, location: MdnInLineLocation?}?
function M.rename(opts)
    opts = opts or {}
    local new_name = opts.new_name
    local move_cursor = opts.move_cursor ~= false

    local ildata = M.parse({ location = opts.location })
    if ildata == nil or ildata.text == nil or ildata.destination == nil then return end

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

    ildata.text = user_input
    local new_il = M.get_il_from_obj(ildata)

    vim.api.nvim_buf_set_text(ildata.buf, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {new_il})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Normalize inline link
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.normalize(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local ildata = M.parse({ location = opts.location })
    local new_destination = ""

    if ildata == nil or ildata.text == nil or ildata.destination == nil then return end

    new_destination = vim.fs.normalize(ildata.destination)
    if new_destination:match("%s") then
        new_destination = "<" .. new_destination .. ">"
    end

    ildata.destination = new_destination
    local new_il = M.get_il_from_obj(ildata)

    vim.api.nvim_buf_set_text(ildata.buf, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {new_il})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Convert the fragment of the inline link under the cursor to GFM-style fragment
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.convert_fragment_to_gfm(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local ildata = M.parse({ location = opts.location })
    local new_fragment = ""
    local convert_text_to_gfm = require('mdnotes').convert_text_to_gfm

    if ildata == nil or ildata.text == nil then return end

    -- Remove any < or > from destination
    local destination = ildata.destination:gsub("[<>]?", "")

    local fragment = destination:match(require("mdnotes.patterns").fragment) or ""
    new_fragment = convert_text_to_gfm(fragment)

    local hash_location = destination:find("#") or 1
    local new_destination = destination:sub(1, hash_location) .. new_fragment

    ildata.destination = new_destination
    local new_il = M.get_il_from_obj(ildata)

    vim.api.nvim_buf_set_text(ildata.buf, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {new_il})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({ildata.lnum, ildata.col_start})
    end
end

---Validate inline link without opening it
---@param opts {silent: boolean?, location: MdnInLineLocation?}?
---@return boolean valid, string error
function M.validate(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local ildata = M.parse({ location = opts.location })

    if ildata == nil or ildata.text == nil or ildata.destination == nil then
        if silent == false then
            vim.notify("Mdn: No valid inline link detected", vim.log.levels.WARN)
        end

        return false, "no valid inline link detected"
    end

    if ildata.destination:match(" ") and not ildata.destination:match("<.+>") then
        if silent == false then
            vim.notify("Mdn: Destinations with spaces must be enclosed with < and >. Execute ':Mdn inline_link normalize' for a quick fix", vim.log.levels.ERROR)
        end

        return false, "destinations with spaces must be enclosed with < and >"
    end

    ildata.destination = ildata.destination:gsub("[<>]?", "")

    local _, perror = M.get_path_from_destination(ildata.destination, true)
    if perror == -2 then
        if silent == false then
            vim.notify("Mdn: Inline link does not seem to point to a valid path", vim.log.levels.WARN)
        end

        return false, "invalid path"
    end

    local _, ferror = M.get_fragment_from_destination(ildata.destination, true)
    if ferror ~= nil and ferror ~= -1 then
        if silent == false then
            vim.notify("Mdn: Inline link does not seem to point to a valid fragment", vim.log.levels.WARN)
        end

        return false, "invalid fragment"
    end

    if silent == false then
        vim.notify("Mdn: Valid inline link", vim.log.levels.INFO)
    end

    return true, "valid"
end

---Open a picker to get the inline link from
function M.get_il_from_picker(buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No inline links in current file to go to", vim.log.levels.ERROR)
        return
    end

    local sel_list = {}
    for _, v in ipairs(parsed_tbl) do
        table.insert(sel_list, v.text .. " | " .. v.destination)
    end

    local il_index = nil
    vim.ui.select(sel_list, {
        prompt = "Select an inline link to go to",
    }, function (_, idx)
        il_index = idx
    end)

    if il_index == nil then
        return
    end

    return M.get_il_from_obj(parsed_tbl[il_index])
end

---Parse the inline links in the specified lines
---@param opts {location: MdnMultiLineLocation?, str: boolean?, silent: boolean?}?
---@return table<MdnInlineLinkData>?
function M.parse_lines(opts)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')
    local str = opts.str or false

    local pattern = require('mdnotes.patterns').inline_link
    local scan_lines = require('mdnotes').scan_lines

    local scanned_lines = scan_lines(pattern, { location = {startl = startl, endl = endl, buf = buf }, silent = true})
    if scanned_lines == nil then return nil end

    local parsed_tbl = {}
    for _, item in ipairs(scanned_lines) do
        for _, cols in ipairs(item.cols) do
            local data = M.parse({ location = {buf = buf, lnum = item.lnum, col_start = cols[1], col_end = cols[2] }})
            if str == true then
                table.insert(parsed_tbl, M.get_il_from_obj(data))
            else
                table.insert(parsed_tbl, data)
            end
        end
    end

    return parsed_tbl
end

return M
