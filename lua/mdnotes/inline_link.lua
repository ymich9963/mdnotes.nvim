---@module 'mdnotes.inline_link'

local M = {}

local default_ui_select = require('mdnotes').default_ui_select

---@class MdnInlineLinkData: MdnText
---@field img_char '"!"'|'""' Inline link image character
---@field text string Inline link text
---@field destination string Inline link destination
---@field title string Inline link title

---Get the inline link data such as the image designator, link text, link destination,
---and the start and end columns
---@param opts {inline_link: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation?}?
---@return MdnInlineLinkData?
function M.parse(opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.parse_re(opts)
    elseif parser == "treesitter" then
        return M.parse_ts(opts)
    end
end

---Parse using Lua patterns
---@param opts {inline_link: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation?}?
---@return MdnInlineLinkData?
function M.parse_re(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local inline_link = opts.inline_link
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false

    vim.validate("inline_link", inline_link, "string", true)
    vim.validate("keep_pointy_brackets", keep_pointy_brackets, "boolean")

    local check_markdown_syntax_re = require('mdnotes').check_markdown_syntax_re
    local il_pattern = require("mdnotes.patterns").inline_link
    local txtdata = {}

    -- Overwrite if location is given
    if opts.location ~= nil or inline_link == nil then
        if not check_markdown_syntax_re(il_pattern, { location = opts.location }) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(il_pattern, { location = opts.location })
        inline_link = txtdata.raw or ""
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
    if M.is_image(inline_link) == true then
        img_char = "!"
    end

    -- Table key 'text' also exists in txtdata but does not get ovewritten with "keep" behaviour
    return vim.tbl_extend("force", {
        img_char = img_char,
        text = text,
        destination = destination,
        title = title,
    }, txtdata)
end

---Parse using treesitter
---@param opts {inline_link: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation?}?
---@return MdnInlineLinkData?
function M.parse_ts(opts)
    opts = opts or {}

    local inline_link = opts.inline_link
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')
    local col_end = locopts.col_end or vim.fn.col('.')
    local cur_col = locopts.cur_col or math.floor((col_start + col_end) / 2)

    vim.validate("inline_link", inline_link, "string", true)
    vim.validate("keep_pointy_brackets", keep_pointy_brackets, "boolean")

    local node, source
    if opts.location ~= nil or inline_link == nil then
        node = vim.treesitter.get_node({
            bufnr = buf,
            ignore_injections = false,
            pos = {lnum - 1, col_start - 1}
        })
        source = buf
    else
        local parser = vim.treesitter.get_string_parser(inline_link, "markdown_inline")
        local tree = parser:parse()[1]
        node = tree:root():child(0)
        source = inline_link
    end

    local node_data
    local process_node = require('mdnotes.treesitter')["inline_link"] or function() return {} end
    local function get_node_data(_node)
        if _node ~= nil then
            node_data = process_node(_node, source, false)
            if node_data == nil then
                get_node_data(_node:parent())
            end
        end
    end

    get_node_data(node)

    if node_data == nil then
        return nil
    end

    -- Remove any < or > from destination
    if keep_pointy_brackets == false then
        node_data.destination = node_data.destination:gsub("[<>]?", "")
    end

    -- Remove quotes
    if node_data.title ~= "" then
        node_data.title = node_data.title:sub(2, #node_data.title - 1)
    end

    node_data.cur_col = cur_col

    return node_data
end

---Get an inline link string from an MdnInlineLinkData object
---@param ildata MdnInlineLinkData? Inline link object
---@return string? inline_link
function M.get_il_from_obj(ildata)
    vim.validate("ildata", ildata, "table", true)
    if ildata == nil then return nil end

    local destination = tostring(ildata.destination)
    if destination:match("%s") then
       destination = "<" .. destination .. ">"
    end
    if ildata.title == nil or ildata.title == "" then
        return ildata.img_char .. '[' .. ildata.text .. '](' .. destination .. ')'
    else
        return ildata.img_char .. '[' .. ildata.text .. '](' .. destination .. ' "' .. ildata.title .. '")'
    end
end

---Open inline links in the appropriate programme
---@param opts {inline_link: string?, location: MdnInLineLocation?, silent: boolean?, picker: boolean?}?
---@return integer|vim.SystemObj|string?
function M.open(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local inline_link = opts.inline_link
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local silent = opts.silent or false
    local picker = opts.picker or false

    vim.validate("inline_link", inline_link, "string", true)

    local ildata

    -- Prefer to use the inline link parameter
    if inline_link == nil then
        ildata = M.parse({ keep_pointy_brackets = false, location = opts.location })
    else
        ildata = M.parse({ inline_link = inline_link, keep_pointy_brackets = false })
    end

    -- If no inline link under cursor and no inline link was given, open picker
    if ildata == nil and picker == true then
        --INFO: RECURSION! I AM A GENIUS!!!
        ildata = M.picker(function(sel_obj) M.open({ inline_link = sel_obj.raw }) end, buf)
    end

    if ildata == nil then
        -- Notification shows when picker is shown if not default
        if silent == false and default_ui_select == vim.ui.select then
            vim.notify("Mdn: No inline link found", vim.log.levels.ERROR)
        end

        return
    end

    return require('mdnotes').open(ildata.destination)
end

---Check if inline link is an image
---@param inline_link string
---@return boolean
function M.is_image(inline_link)
    vim.validate("inline_link", inline_link, "string")

    if inline_link:sub(1,1) == "!" then
        return true
    else
        return false
    end
end

---Insert Markdown inline link with the text in the clipboard
---@param opts {destination: string?, move_cursor: boolean?, location: MdnInLineLocation, silent: boolean?}?
function M.insert(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local destination = opts.destination or vim.fn.getreg('+')
    local move_cursor = opts.move_cursor ~= false
    local silent = opts.silent or false

    if destination == '' then
        if silent == false then
            vim.notify("Mdn: Nothing detected in clipboard, \"+ register empty...", vim.log.levels.ERROR)
        end

        return
    end

    local txtdata = require('mdnotes').get_text({ location = opts.location })
    if txtdata.raw == nil then
        return
    end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {'[' .. txtdata.raw .. '](' .. destination .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') + 1})
    end
end

---Delete Markdown inline link and leave the text
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?, store: boolean?}?
function M.delete(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local store = opts.store or false
    local ildata = M.parse({ location = opts.location })

    if ildata == nil or ildata.text == nil or ildata.destination == nil then return end

    vim.api.nvim_buf_set_text(ildata.buf, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {ildata.text})

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({vim.fn.line('.'), vim.fn.col('.') - 1})
    end

    if store == true then
        vim.fn.setreg('+', ildata.destination)
    end
end

---Toggle inserting and deleting inline links
---@param opts {destination: string?, location: MdnInLineLocation?}?
function M.toggle(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    if check_markdown_syntax("inline_link", { location = opts.location }) then
        M.delete({ location = opts.location, store = true })
    else
        M.insert({ destination = opts.destination, location = opts.location })
    end
end

---Relink inline link
---@param opts {new_link: string?, move_cursor: boolean?, location: MdnInLineLocation?, silent: boolean?}?
function M.relink(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local new_link = opts.new_link
    local move_cursor = opts.move_cursor ~= false
    local silent = opts.silent or false

    local ildata = M.parse({ location = opts.location, keep_pointy_brackets = false })
    if ildata == nil or ildata.text == nil or ildata.destination == nil then return end

    local user_input
    if new_link == nil then
        vim.ui.input({prompt = "Relink destination: ", default = ildata.destination }, function(input) user_input = input end)
    else
        user_input = new_link
    end

    if user_input == "" or user_input == nil then
        if silent == false then
            vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        end

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
---@param opts {new_name: string?, move_cursor: boolean?, location: MdnInLineLocation?, silent: boolean?}?
function M.rename(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local new_name = opts.new_name
    local move_cursor = opts.move_cursor ~= false
    local silent = opts.silent or false

    local ildata = M.parse({ location = opts.location, keep_pointy_brackets = false })
    if ildata == nil or ildata.text == nil or ildata.destination == nil then return end

    local user_input
    if new_name == nil then
        vim.ui.input({prompt = "Rename link text: ", default = ildata.text }, function(input) user_input = input end)
    else
        user_input = new_name
    end

    if user_input == "" or user_input == nil then
        if silent == false then
            vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        end

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

---Normalize inline link using Lua patterns
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.normalize(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local ildata = M.parse_re({ location = opts.location, keep_pointy_brackets = false })
    if ildata == nil then return end

    local new_destination = ""
    local destination = vim.fs.normalize(ildata.destination)
    local fragment = destination:match(require("mdnotes.patterns").fragment)
    if fragment ~= nil then
        local convert_text_to_gfm = require('mdnotes').convert_text_to_gfm
        local new_fragment = convert_text_to_gfm(fragment)
        local hash_location = destination:find("#")
        new_destination = destination:sub(1, hash_location) .. new_fragment
    else
        new_destination = destination
    end

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
---@return boolean valid, string? error
function M.validate(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local silent = opts.silent or false
    local ildata = M.parse_re({ location = opts.location })

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

    local _, perror = require('mdnotes').get_path_from_destination(ildata.destination, true)
    if perror == -2 then
        if silent == false then
            vim.notify("Mdn: Inline link does not seem to point to a valid path", vim.log.levels.WARN)
        end

        return false, "invalid path"
    end

    local _, ferror = require('mdnotes').get_fragment_from_destination(ildata.destination, true)
    if ferror ~= nil and ferror ~= -1 then
        if silent == false then
            vim.notify("Mdn: Inline link does not seem to point to a valid fragment", vim.log.levels.WARN)
        end

        return false, "invalid fragment"
    end

    if silent == false then
        vim.notify("Mdn: Valid inline link", vim.log.levels.INFO)
    end

    return true, nil
end

---Open a picker to get the inline link from
---@param on_end fun(sel_obj): any Callback function for when the coroutine finishes
---@param buf integer Buffer number
function M.picker(on_end, buf)
    vim.validate("on_end", on_end, "function")
    vim.validate("buf", buf, "number")
    if buf == 0 then buf = vim.api.nvim_get_current_buf() end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No inline links in current file", vim.log.levels.ERROR)
        return
    end

    local ui_opts = {
        prompt = "Select an inline link:",
        format_item = function(item)
            return item.text .. " | " .. item.destination
        end,
    }

    return require('mdnotes').mdn_picker(parsed_tbl, on_end, ui_opts)
end

---Parse the inline links in the specified lines
---@param opts {location: MdnMultiLineLocation?, str: boolean?, no_duplicates: boolean?, location_only: boolean?}?
---@return table<MdnInlineLinkData>?
function M.parse_lines(opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.parse_lines_re(opts)
    elseif parser == "treesitter" then
        return M.parse_lines_ts(opts)
    end
end

---Parse the inline links in the specified lines using Lua patterns
---@param opts {location: MdnMultiLineLocation?, str: boolean?, no_duplicates: boolean?, location_only: boolean?}?
---@return table<MdnInlineLinkData>?
function M.parse_lines_re(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local str = opts.str or false
    local pattern = require('mdnotes.patterns').inline_link
    local parse_lines_re = require('mdnotes').parse_lines_re

    local get_func = nil
    if str == true then
        get_func = M.get_il_from_obj
    end
    local _opts = vim.tbl_extend("force", opts, {get_func = get_func})

    return parse_lines_re(pattern, M.parse_re, _opts)
end

---Parse the inline links in the specified lines using Lua patterns
---@param opts {location: MdnMultiLineLocation?, str: boolean?, no_duplicates: boolean?, location_only: boolean?}?
---@return table<MdnInlineLinkData>?
function M.parse_lines_ts(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local str = opts.str or false
    local parse_lines_ts = require('mdnotes').parse_lines_ts

    local get_func = nil
    if str == true then
        get_func = M.get_il_from_obj
    end
    local _opts = vim.tbl_extend("force", opts, {get_func = get_func})

    return parse_lines_ts("inline_link", _opts)
end

---@param opts {move_cursor: boolean?, location: MdnInLineLocation}?
function M.convert_from_reference(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local rldata = require('mdnotes.reference_link').parse({ location = opts.location })
    if rldata == nil or rldata.text == nil then return end

    local rldef = require('mdnotes.reference_link').get_rl_definition(rldata.label, rldata.buf)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'. If you can confirm it exists, try writing the buf or parse definitions manually with ':Mdn reference_link populate_buf_reference_links'", vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_buf_set_text(rldata.buf, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {'[' .. rldata.text .. '](' .. rldef.destination .. ')'})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buf)
        vim.fn.cursor({rldata.lnum, vim.fn.col('.') + 1})
    end
end

return M
