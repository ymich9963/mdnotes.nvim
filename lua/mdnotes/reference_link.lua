---@module 'mdnotes.assets'

local M = {}

---@class MdnReferenceLinkDefinition
---@field label string Reference link label
---@field destination string Reference link destination
---@field lnum integer Reference link definition line number

---@class MdnBufReferenceLinkDefintions
---@field buf integer Buffer number
---@field defintions table<MdnReferenceLinkDefinition>

---Table containing buffer reference link defintions
---@type table<MdnBufReferenceLinkDefintions>
M.buf_reference_link_definitions = {}

---@class MdnReferenceLinkData: MdnInLineLocation
---@field text string Reference link text
---@field label string Reference link label

---Get the reference link data such as the link text, link label, and the start and end columns
---@param opts {reference_link: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation?}?
---@return MdnReferenceLinkData?
function M.parse(opts)
    opts = opts or {}

    local reference_link = opts.reference_link
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false

    vim.validate("reference_link", reference_link, { "string", "nil" })
    vim.validate("keep_pointy_brackets", keep_pointy_brackets, "boolean")

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local rl_pattern = require("mdnotes.patterns").reference_link
    local txtdata = {}

    if reference_link == nil then
        if not check_markdown_syntax(rl_pattern, { location = opts.location }) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(rl_pattern, { location = opts.location })
        reference_link = txtdata.text or ""
    end

    local text, label = reference_link:match(require("mdnotes.patterns").text_label)

    if text and label == "" then
        label = text
    end

    -- Table key 'text' also exists in txtdata but does not get ovewritten with "keep" behaviour
    return vim.tbl_extend("keep", {
        text = text,
        label = label,
    }, txtdata)
end

---Get the reference link defintions for specified buffer
---@param opts {buf: integer?, only_labels: boolean?}?
---@return table<MdnReferenceLinkDefinition|string>?
function M.get_buf_reference_link_definitions(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local only_labels = opts.only_labels or false

    local reference_links = {}
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local rl_def_pattern = require('mdnotes.patterns').reference_link_definition

    for lnum, line in ipairs(buf_lines) do
        local label, destination = line:match(rl_def_pattern)
        if label and destination then
            if only_labels == false then
                table.insert(reference_links, {label = string.lower(label), destination = destination, lnum = lnum})
            else
                table.insert(reference_links, string.lower(label))
            end
        end
    end

    return reference_links
end

---Populate the buf_reference_link_defintions table
---@param buf integer? Buffer number
function M.populate_buf_reference_link_definitions(buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    local rldef_table = M.get_buf_reference_link_definitions({ buf = buf })

    local exists = false
    for _,v in ipairs(M.buf_reference_link_definitions) do
        if v.buf == buf then
            exists = true
            if v.definitions ~= rldef_table then
                v.definitions = rldef_table
            end

            break
        end
    end

    if exists == false then
        table.insert(M.buf_reference_link_definitions, {buf = buf, definitions = rldef_table})
    end
end

---Insert Markdown reference link with the text in the clipboard
---@param opts {label: string?, destination: string?, move_cursor: boolean?, location: MdnInLineLocation, silent: boolean?}?
function M.insert(opts)
    opts = opts or {}
    local destination = opts.destination or vim.fn.getreg('+')
    local move_cursor = opts.move_cursor ~= false
    local silent = opts.silent or false

    local rldef = M.get_rl_definition(opts.label)
    if destination == '' and rldef ~= nil then
        if silent == false then
            vim.notify("Mdn: Nothing detected in clipboard, \"+ register empty...", vim.log.levels.ERROR)
        end

        return
    end

    local txtdata = require('mdnotes').get_text({ location = opts.location })

    local link_label = opts.label or ""
    local def_label = opts.label or txtdata.text

    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {'[' .. txtdata.text .. '][' .. link_label .. ']'})

    if rldef == nil then
        vim.api.nvim_buf_set_lines(txtdata.buf, vim.fn.line("$"), vim.fn.line("$") + 1, false, {'[' .. def_label .. ']: ' ..  destination})
    end

    -- Update buf_reference_link_definitions
    M.populate_buf_reference_link_definitions(txtdata.buf)

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') + 1})
    end
end

---Get the reference link definition object
function M.get_rl_definition(label, buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    for _, v in pairs(M.buf_reference_link_definitions) do
        if v.buf == buf then
            for _, vv in pairs(v.definitions) do
                if vv.label == string.lower(label) then
                    return vv
                end
            end
            break
        end
    end
end

---Go to reference link definition
---@param opts {label: string?, location: MdnInLineLocation?, silent: boolean?}?
function M.go_to_definition(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local label = opts.label
    local buf = (opts.location or {}).buf or vim.api.nvim_get_current_buf()

    if label == nil then
        local rldata = M.parse({ location = opts.location })
        if rldata == nil then return end
        label = rldata.label
    end

    local rldef = M.get_rl_definition(label, buf)
    if rldef == nil then
        if silent == false then
            vim.notify("Mdn: No definition found for label '" .. label .. "'", vim.log.levels.ERROR)
        end

        return
    end

    vim.cmd.buffer(buf)
    vim.fn.cursor({rldef.lnum, 1})
end

---Delete Markdown reference link and leave the text
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.delete(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local rldata = M.parse({ location = opts.location })

    if rldata == nil or rldata.text == nil or rldata.label == nil then return end

    vim.api.nvim_buf_set_text(rldata.buf, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {rldata.text})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buf)
        vim.fn.cursor({vim.fn.line('.'), rldata.col_start - 1})
    end
end

---Get an reference link definition string from an MdnReferenceLinkEntry object
---@param rldef MdnReferenceLinkDefinition? Reference link definition object
---@return string reference_link_definition
function M.get_rl_definition_from_obj(rldef)
    if rldef == nil then return "" end
    return '[' .. rldef.label .. ']: ' .. rldef.destination
end

---Update reference link definition label and destination
---@param opts {label:string?, new_label: string?, new_destination: string?, location: MdnInLineLocation?, skip_input: boolean?, silent: boolean?}?
function M.update_definition(opts)
    opts = opts or {}

    local label = opts.label
    local buf = (opts.location or {}).buf or vim.api.nvim_get_current_buf()
    local new_label = opts.new_label
    local new_destination = opts.new_destination
    local skip_input = opts.skip_input or false
    local silent = opts.silent or false

    local rldata
    if label == nil then
        rldata = M.parse({ location = opts.location })
        if rldata == nil or rldata.text == nil or rldata.label == nil then
            if silent == false then
                vim.notify("Mdn: No reference link found for parsing", vim.log.levels.ERROR)
            end

            return
        end
        label = rldata.label
    end

    local rldef = M.get_rl_definition(label, buf)
    if rldef == nil then
        if silent == false then
            vim.notify("Mdn: No definition found for label '" .. label .. "'", vim.log.levels.ERROR)
        end

        return
    end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No reference links in current buffer", vim.log.levels.ERROR)
        end

        return
    end

    if new_label == nil then
        if skip_input == false then
            vim.ui.input({prompt = "Update label: ", default = rldef.label }, function(input) new_label = input end)
        else
            new_label = rldef.label
        end
    end

    if new_destination == nil then
        if skip_input == false then
            vim.ui.input({prompt = "Update destination: ", default = rldef.destination }, function(input) new_destination = input end)
        else
            new_destination = rldef.destination
        end
    end

    -- Execute changes for reference links
    for _, v in pairs(parsed_tbl) do
        if v.label == label then
            v.label = new_label
            vim.api.nvim_buf_set_text(v.buf, v.lnum - 1, v.col_start - 1, v.lnum - 1, v.col_end - 1, {M.get_rl_from_obj(v)})
        end
    end

    -- Execute changes in reference link definition
    if new_label == "" and rldata ~= nil then
        -- When new label is set to blank, it will use the detected text as the label
        rldef.label = rldata.text
    else
        rldef.label = new_label or ""
    end
    rldef.destination = new_destination
    vim.api.nvim_buf_set_lines(buf, rldef.lnum - 1, rldef.lnum, false, {M.get_rl_definition_from_obj(rldef)})

    vim.cmd.wall({bang = true, mods = {silent = true, noautocmd = true}})
    M.populate_buf_reference_link_definitions(buf)
end

---Cleanup unused reference link definitions
---@param opts {buf: integer?, silent: boolean?}?
function M.cleanup_definitions(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local buf = opts.buf or vim.api.nvim_get_current_buf()

    local rldef_tbl = M.get_buf_reference_link_definitions({ buf = buf })
    if rldef_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No reference links found in buf", vim.log.levels.ERROR)
        end

        return
    end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No reference links in current buffer", vim.log.levels.ERROR)
        end

        return
    end

    for _, v in pairs(rldef_tbl) do
        local found = false
        for _, vv in pairs(parsed_tbl) do
            if v.label == vv.label then
                found = true
                break
            end
        end
        if found == false then
            vim.api.nvim_buf_set_lines(buf, v.lnum - 1, v.lnum, false, {""})
        end
    end

    M.populate_buf_reference_link_definitions(buf)
end

---Get an reference link string from an MdnReferenceLinkData object
---@param rldata MdnReferenceLinkData? Reference link object
---@return string reference_link
function M.get_rl_from_obj(rldata)
    if rldata == nil then return "" end
    if rldata.text == rldata.label then
        return '[' .. rldata.text .. '][]'
    else
        return '[' .. rldata.text .. '][' .. rldata.label .. ']'
    end
end

---Rename reference link but do not update definition
---@param opts {new_name: string?, move_cursor: boolean?, location: MdnInLineLocation?, silent: boolean?}?
function M.rename(opts)
    opts = opts or {}
    local new_name = opts.new_name
    local move_cursor = opts.move_cursor ~= false
    local silent = opts.silent or false

    local rldata = M.parse({ location = opts.location })
    if rldata == nil or rldata.text == nil or rldata.label == nil then return end

    if new_name == nil then
        vim.ui.input({prompt = "Rename: ", default = rldata.text }, function(input) new_name = input end)
    end

    if new_name == "" or new_name == nil then
        if silent == false then
            vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        end

        return
    end

    rldata.text = new_name
    vim.api.nvim_buf_set_text(rldata.buf, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {M.get_rl_from_obj(rldata)})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buf)
        vim.fn.cursor({rldata.lnum, rldata.col_start})
    end
end

---Relable reference link but do not update definition
---@param opts {new_label: string?, move_cursor: boolean?, location: MdnInLineLocation?, silent: boolean?}?
function M.relabel(opts)
    opts = opts or {}
    local new_label = opts.new_label
    local move_cursor = opts.move_cursor ~= false
    local silent = opts.silent or false

    local rldata = M.parse({ location = opts.location })
    if rldata == nil or rldata.text == nil or rldata.label == nil then return end

    local user_input
    if new_label == nil then
        vim.ui.input({prompt = "Relabel: ", default = rldata.label }, function(input) user_input = input end)
    else
        user_input = new_label
    end

    if user_input == nil then
        if silent == false then
            vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        end

        return
    end

    rldata.label = user_input
    local new_rl = M.get_rl_from_obj(rldata)

    vim.api.nvim_buf_set_text(rldata.buf, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {new_rl})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buf)
        vim.fn.cursor({rldata.lnum, rldata.col_start})
    end
end

---Open reference links in the appropriate programme
---@param opts {reference_link: string?, location: MdnInLineLocation?, silent: boolean?}?
---@return integer|vim.SystemObj|string?
function M.open(opts)
    opts = opts or {}

    local reference_link = opts.reference_link
    local silent = opts.silent or false

    vim.validate("reference_link", reference_link, {"string", "nil"})

    local rldata

    -- Overwrite if location is given
    if reference_link == nil then
        rldata = M.parse({ keep_pointy_brackets = false, location = opts.location })
    else
        rldata = M.parse({ reference_link = reference_link, keep_pointy_brackets = false })
    end

    if rldata == nil then
        reference_link = M.get_rl_from_picker()
        rldata = M.parse({ reference_link = reference_link, keep_pointy_brackets = false })
    end

    if rldata == nil then
        if silent == false then
            vim.notify("Mdn: No reference link found", vim.log.levels.ERROR)
        end

        return "err"
    end

    local rldef = M.get_rl_definition(rldata.label, rldata.buf)
    if rldef == nil then
        if silent == false then
            vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'. If you can confirm it exists, try writing the buf or parse definitions manually with ':Mdn reference_link populate_buf_reference_link_definitions'", vim.log.levels.ERROR)
        end

        return "err1"
    end

    return require('mdnotes').open(rldef.destination)
end

---Convert an inline link to a reference link with its definition
---@param opts {move_cursor: boolean?, location: MdnInLineLocation}?
---@return MdnReferenceLinkData? rldata, MdnReferenceLinkDefinition? rldef
function M.convert_from_inline(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local ildata = require('mdnotes.inline_link').parse({ location = opts.location })
    if ildata == nil or ildata.text == nil then return nil, nil end

    local rldata = {
        text = ildata.text,
        label = ildata.text,
        lnum = ildata.lnum,
        col_start = ildata.col_start,
        col_end = ildata.col_start + #ildata.text + 4,
        buf = ildata.buf
    }

    local rldef = {
        label = ildata.text,
        destination = ildata.destination,
        lnum = vim.fn.line("$")
    }

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(rldata.buf, rldata.lnum - 1, ildata.col_start - 1, rldata.lnum - 1, ildata.col_end - 1, {M.get_rl_from_obj(rldata)})
    vim.api.nvim_buf_set_lines(rldata.buf, vim.fn.line("$"), vim.fn.line("$") + 1, false, {M.get_rl_definition_from_obj(rldef)})

    -- Update buf_reference_link_definitions
    M.populate_buf_reference_link_definitions(ildata.buf)

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({ildata.lnum, vim.fn.col('.') + 1})
    end

    return rldata, rldef
end

---Parse the reference links in the specified lines
---@param opts {location: MdnMultiLineLocation?, str: boolean?, silent: boolean?}?
---@return table<MdnReferenceLinkData>?
function M.parse_lines(opts)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')
    local str = opts.str or false

    local pattern = require('mdnotes.patterns').reference_link
    local scan_lines = require('mdnotes').scan_lines

    local scanned_lines = scan_lines(pattern, { location = {startl = startl, endl = endl, buf = buf }, silent = true})
    if scanned_lines == nil then return nil end

    local parsed_tbl = {}
    for _, item in ipairs(scanned_lines) do
        for _, cols in ipairs(item.cols) do
            local data = M.parse({ location = {buf = buf, lnum = item.lnum, col_start = cols[1], col_end = cols[2] }})
            if str == true then
                table.insert(parsed_tbl, M.get_rl_from_obj(data))
            else
                table.insert(parsed_tbl, data)
            end
        end
    end

    return parsed_tbl
end

---@param opts {label: string?, location: MdnInLineLocation?, silent: boolean?}?
function M.find_label(opts)
    opts = opts or {}

    local label = opts.label
    local silent = opts.silent or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()

    if label == nil then
        local rldata = M.parse({ location = opts.location })
        if rldata == nil or rldata.text == nil or rldata.label == nil then
            if silent == false then
                vim.notify("Mdn: No reference link found for parsing", vim.log.levels.ERROR)
            end

            return
        end
        label = rldata.label
    end

    local rldef = M.get_rl_definition(label, buf)
    if rldef == nil then
        if silent == false then
            vim.notify("Mdn: No definition found for label '" .. label .. "'", vim.log.levels.ERROR)
        end

        return
    end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No reference links in current buffer", vim.log.levels.ERROR)
        end

        return
    end

    local qflist = {}
    for _, v in pairs(parsed_tbl) do
        if v.label == label then
            table.insert(qflist, {bufnr = v.buf, lnum = v.lnum, col = v.start_col, end_col = v.end_coa, text = v.text})
        end
    end

    vim.fn.setqflist(qflist)
    vim.cmd.copen()

    return qflist
end

---Open a picker to get the inline link from
---@param buf integer? Buffer number
---@return string?
function M.get_rl_from_picker(buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No inline links in current file to go to", vim.log.levels.ERROR)
        return
    end

    local sel_list = {}
    for _, v in ipairs(parsed_tbl) do
        table.insert(sel_list, M.get_rl_from_obj(v))
    end

    local rl_index = nil
    vim.ui.select(sel_list, {
        prompt = "Select an reference link to open",
    }, function (_, idx)
        rl_index = idx
    end)

    if rl_index == nil then
        return
    end

    return M.get_rl_from_obj(parsed_tbl[rl_index])
end

return M
