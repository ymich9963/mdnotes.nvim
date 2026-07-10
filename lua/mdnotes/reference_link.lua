---@module 'mdnotes.assets'

local M = {}

---@class MdnReferenceLinkDefinition
---@field label string Reference link label
---@field destination string Reference link destination
---@field lnum integer Reference link definition line number

---@class MdnBufReferenceLinks
---@field buf integer Buffer number
---@field reference_links table<MdnReferenceLinkDefinition>

---@type table<MdnBufReferenceLinks>
M.buf_reference_links = {}

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

    -- Overwrite if location is given
    if opts.location ~= nil or reference_link == nil then
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

---@param opts {buf: integer?, only_labels: boolean?}?
---@return table<MdnReferenceLinkDefinition>?
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

function M.populate_buf_reference_links(buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    local rl_tbl = M.get_buf_reference_link_definitions({ buf = buf })

    local exists = false
    for _,v in ipairs(M.buf_reference_links) do
        if v.buf == buf then
            exists = true
            if v.reference_links ~= rl_tbl then
                v.reference_links = rl_tbl
            end

            break
        end
    end

    if exists == false then
        table.insert(M.buf_reference_links, {buf = buf, reference_links = rl_tbl})
    end
end

---Insert Markdown inline link with the text in the clipboard
---@param opts {label: string?, destination: string?, move_cursor: boolean?, location: MdnInLineLocation}?
function M.insert(opts)
    opts = opts or {}
    local destination = opts.destination or vim.fn.getreg('+')
    local move_cursor = opts.move_cursor ~= false

    local rldef = M.get_rl_definition(opts.label)
    if destination == '' and rldef ~= nil then
        vim.notify("Mdn: Nothing detected in clipboard, \"+ register empty...", vim.log.levels.ERROR)
        return
    end

    local txtdata = require('mdnotes').get_text({ location = opts.location })

    local link_label = opts.label or ""
    local def_label = opts.label or txtdata.text

    vim.api.nvim_buf_set_text(txtdata.buf, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end, {'[' .. txtdata.text .. '][' .. link_label .. ']'})

    if rldef == nil then
        vim.api.nvim_buf_set_lines(txtdata.buf, vim.fn.line("$"), vim.fn.line("$") + 1, false, {'[' .. def_label .. ']: ' ..  destination})
    end

    -- Update buf_reference_links
    M.populate_buf_reference_links(txtdata.buf)

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buf)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') + 1})
    end
end

function M.get_rl_definition(label, buf)
    if label == nil then return end
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    for _, v in pairs(M.buf_reference_links) do
        if v.buf == buf then
            for _, vv in pairs(v.reference_links) do
                if vv.label == string.lower(label) then
                    return vv
                end
            end
            break
        end
    end
end

---Go to reference link definition
---@param opts {location: MdnInLineLocation?}?
function M.go_to_definition(opts)
    opts = opts or {}

    local rldata = M.parse({ location = opts.location })
    if rldata == nil or rldata.text == nil or rldata.label == nil then return end
    local rldef = M.get_rl_definition(rldata.label, rldata.buf)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'", vim.log.levels.ERROR)
        return
    end

    vim.cmd.buffer(rldata.buf)
    vim.fn.cursor({rldef.lnum, 1})
end

---Delete Markdown reference link but leave the text
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

---@param opts {new_label: string?, new_destination: string?, location: MdnInLineLocation?}?
function M.update_definition(opts)
    opts = opts or {}

    local new_label = opts.new_label
    local new_destination = opts.new_destination

    local rldata = M.parse({ location = opts.location })
    if rldata == nil or rldata.text == nil or rldata.label == nil then
        vim.notify("Mdn: No reference link found for parsing", vim.log.levels.ERROR)
        return
    end

    local rldef = M.get_rl_definition(rldata.label, rldata.buf)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'", vim.log.levels.ERROR)
        return
    end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = rldata.buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No reference links in current buffer", vim.log.levels.ERROR)
        return
    end

    -- Get input for label
    local input_label
    if new_label == nil then
        vim.ui.input({prompt = "Update label: ", default = rldef.label }, function(input) input_label = input end)
    else
        input_label = new_label
    end
    if input_label == nil then
        vim.cmd.echo() -- clear cmdline
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        return
    end

    -- Get input for destination
    local input_destination
    if new_destination == nil then
        vim.ui.input({prompt = "Update destination: ", default = rldef.destination }, function(input) input_destination = input end)
    else
        input_destination = new_destination
    end
    if input_destination == "" or input_destination == nil then
        vim.cmd.echo() -- clear cmdline
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        return
    end

    -- Execute changes for reference links
    for _, v in pairs(parsed_tbl) do
        if v.label == rldata.label then
            v.label = input_label
            vim.api.nvim_buf_set_text(v.buf, v.lnum - 1, v.col_start - 1, v.lnum - 1, v.col_end - 1, {M.get_rl_from_obj(v)})
        end
    end

    -- Execute changes in reference link definition
    if input_label == "" then
        rldef.label = rldata.text
    else
        rldef.label = input_label
    end
    rldef.destination = input_destination
    vim.api.nvim_buf_set_lines(rldata.buf, rldef.lnum - 1, rldef.lnum, false, {M.get_rl_definition_from_obj(rldef)})

    vim.cmd.wall({bang = true, mods = {silent = true, noautocmd = true}})
    M.populate_buf_reference_links(rldata.buf)
end

---@param opts {buf: integer?}?
function M.cleanup_definitions(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()

    local rl_tbl = M.get_buf_reference_link_definitions({ buf = buf })
    if rl_tbl == nil then
        vim.notify("Mdn: No reference links found in buf", vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_buf_call(buf, function()
        for _, v in pairs(rl_tbl) do
            local search_ret = vim.fn.search("\\[" .. v.label .. "\\]", "n")
            if search_ret ==  v.lnum then
                vim.api.nvim_buf_set_lines(buf, v.lnum - 1, v.lnum, false, {})
            end
        end
    end)

    vim.cmd.wall({bang = true, mods = {silent = true, noautocmd = true}})
    M.populate_buf_reference_links(buf)
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

---Rename reference link but do NOT update definition
---@param opts {new_name: string?, move_cursor: boolean?, location: MdnInLineLocation?}?
function M.rename(opts)
    opts = opts or {}
    local new_name = opts.new_name
    local move_cursor = opts.move_cursor ~= false

    local rldata = M.parse({ location = opts.location })
    if rldata == nil or rldata.text == nil or rldata.label == nil then return end

    local user_input
    if new_name == nil then
        vim.ui.input({prompt = "Rename: ", default = rldata.text }, function(input) user_input = input end)
    else
        user_input = new_name
    end

    if user_input == "" or user_input == nil then
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
        return
    end

    rldata.text = user_input
    local new_rl = M.get_rl_from_obj(rldata)

    vim.api.nvim_buf_set_text(rldata.buf, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {new_rl})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buf)
        vim.fn.cursor({rldata.lnum, rldata.col_start})
    end
end

---Relable reference link but do NOT update definition
---@param opts {new_label: string?, move_cursor: boolean?, location: MdnInLineLocation?}?
function M.relabel(opts)
    opts = opts or {}
    local new_label = opts.new_label
    local move_cursor = opts.move_cursor ~= false

    local rldata = M.parse({ location = opts.location })
    if rldata == nil or rldata.text == nil or rldata.label == nil then return end

    local user_input
    if new_label == nil then
        vim.ui.input({prompt = "Relabel: ", default = rldata.label }, function(input) user_input = input end)
    else
        user_input = new_label
    end

    if user_input == nil then
        vim.notify("Mdn: Please enter valid text", vim.log.levels.ERROR)
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
---@param opts {reference_link: string?, location: MdnInLineLocation?}?
---@return integer|vim.SystemObj|string?
function M.open(opts)
    opts = opts or {}

    local reference_link = opts.reference_link

    vim.validate("reference_link", reference_link, {"string", "nil"})

    local rldata

    -- Overwrite if location is given
    if opts.location ~= nil or reference_link == nil then
        rldata = M.parse({ keep_pointy_brackets = false, location = opts.location })
    else
        rldata = M.parse({ reference_link = reference_link, keep_pointy_brackets = false })
    end
    if rldata == nil then
        vim.notify("Mdn: No reference link detected", vim.log.levels.ERROR)
        return
    end

    local rldef = M.get_rl_definition(rldata.label, rldata.buf)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'. If you can confirm it exists, try writing the buf or parse definitions manually with ':Mdn reference_link populate_buf_reference_links'", vim.log.levels.ERROR)
        return
    end

    return require('mdnotes').open(rldef.destination)
end

---@param opts {move_cursor: boolean?, location: MdnInLineLocation}?
function M.convert_from_inline(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local ildata = require('mdnotes.inline_link').parse({ location = opts.location })
    if ildata == nil or ildata.text == nil then return end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(ildata.buf, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {'[' .. ildata.text .. '][]'})
    vim.api.nvim_buf_set_lines(ildata.buf, vim.fn.line("$"), vim.fn.line("$") + 1, false, {'[' .. ildata.text .. ']: ' ..  ildata.destination})

    -- Update buf_reference_links
    M.populate_buf_reference_links(ildata.buf)

    if move_cursor == true then
        vim.cmd.buffer(ildata.buf)
        vim.fn.cursor({ildata.lnum, vim.fn.col('.') + 1})
    end
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

---@param opts {label: string?, location: MdnInLineLocation}?
function M.find_label(opts)
    opts = opts or {}

    local label = opts.label
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()

    if label == nil then
        local rldata = M.parse({ location = opts.location })
        if rldata == nil or rldata.text == nil or rldata.label == nil then
            vim.notify("Mdn: No reference link found for parsing", vim.log.levels.ERROR)
            return
        end
        label = rldata.label
    end

    local rldef = M.get_rl_definition(label, buf)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. label .. "'", vim.log.levels.ERROR)
        return
    end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No reference links in current buffer", vim.log.levels.ERROR)
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

return M
