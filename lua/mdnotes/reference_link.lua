---@module 'mdnotes.assets'

local M = {}

---@class MdnReferenceLinkDefinition
---@field label string Reference link label
---@field destination string Reference link destination
---@field lnum integer Reference link definition line number

---@class MdnBufReferenceLinks
---@field buf_num integer Buffer number
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

---@param bufnr integer?
---@return table<MdnReferenceLinkDefinition>?
function M.get_buf_reference_link_definitions(bufnr)
    if bufnr == nil then bufnr = vim.api.nvim_get_current_buf() end
    local reference_links = {}
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local rl_def_pattern = require('mdnotes.patterns').reference_link_definition

    for lnum, line in ipairs(buf_lines) do
        local label, destination = line:match(rl_def_pattern)
        if label and destination then
            table.insert(reference_links, {label = label, destination = destination, lnum = lnum})
        end
    end

    return reference_links
end

function M.populate_buf_reference_links(bufnr)
    if bufnr == nil then bufnr = vim.api.nvim_get_current_buf() end

    local rl_tbl = M.get_buf_reference_link_definitions(bufnr)

    local exists = false
    for _,v in ipairs(M.buf_reference_links) do
        if v.buf_num == bufnr then
            exists = true
            if v.reference_links ~= rl_tbl then
                v.reference_links = rl_tbl
            end

            break
        end
    end

    if exists == false then
        table.insert(M.buf_reference_links, {buf_num = bufnr, reference_links = rl_tbl})
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
    vim.api.nvim_buf_set_text(txtdata.buffer, txtdata.lnum - 1, txtdata.col_start - 1, txtdata.lnum - 1, txtdata.col_end - 1, {'[' .. txtdata.text .. '][]'})
    vim.api.nvim_buf_set_lines(txtdata.buffer, vim.fn.line("$"), vim.fn.line("$") + 1, false, {'[' .. txtdata.text .. ']: ' ..  destination})

    -- Update buf_reference_links
    M.populate_buf_reference_links(txtdata.buffer)

    if move_cursor == true then
        vim.cmd.buffer(txtdata.buffer)
        vim.fn.cursor({txtdata.lnum, vim.fn.col('.') + 1})
    end
end

function M.get_rl_definition(label, bufnr)
    if bufnr == nil then bufnr = vim.api.nvim_get_current_buf() end

    for _, v in pairs(M.buf_reference_links) do
        if v.buf_num == bufnr then
            for _, vv in pairs(v.reference_links) do
                if vv.label == label then
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
    local rldef = M.get_rl_definition(rldata.label, rldata.buffer)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'", vim.log.levels.ERROR)
        return
    end

    vim.cmd.buffer(rldata.buffer)
    vim.fn.cursor({rldef.lnum, 1})
end

---Delete Markdown reference link but leave the text
---@param opts {move_cursor: boolean?, location: MdnInLineLocation?}?
function M.delete(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local rldata = M.parse({ location = opts.location })

    if rldata == nil or rldata.text == nil or rldata.label == nil then return end

    vim.api.nvim_buf_set_text(rldata.buffer, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {rldata.text})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buffer)
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
    if rldata == nil or rldata.text == nil or rldata.label == nil then return end

    local rldef = M.get_rl_definition(rldata.label, rldata.buffer)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'", vim.log.levels.ERROR)
        return
    end

    local cur_pos = vim.fn.getpos('.')

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

    -- Execute changes
    vim.cmd.s({args = {"/\\[" .. rldef.label .. "\\]/\\[" .. input_label .. "\\]/g"}, range={1, vim.fn.line("$")}, mods = {emsg_silent = true, noautocmd = true}})

    if input_label == "" then
        rldef.label = rldata.text
    else
        rldef.label = input_label
    end
    rldef.destination = input_destination

    vim.api.nvim_buf_set_lines(rldata.buffer, rldef.lnum - 1, rldef.lnum, false, {M.get_rl_definition_from_obj(rldef)})

    vim.cmd.wall({bang = true, mods = {silent = true, noautocmd = true}})
    M.populate_buf_reference_links(rldata.buffer)
    vim.fn.setpos('.', cur_pos)
end

function M.cleanup_definitions(bufnr)
    if bufnr == nil then bufnr = vim.api.nvim_get_current_buf() end

    local rl_tbl = M.get_buf_reference_link_definitions(bufnr)
    if rl_tbl == nil then
        vim.notify("Mdn: No reference links found in buffer", vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_buf_call(bufnr, function()
        for _, v in pairs(rl_tbl) do
            local search_ret = vim.fn.search("\\[" .. v.label .. "\\]", "n")
            if search_ret ==  v.lnum then
                vim.api.nvim_buf_set_lines(bufnr, v.lnum - 1, v.lnum, false, {})
            end
        end
    end)

    vim.cmd.wall({bang = true, mods = {silent = true, noautocmd = true}})
    M.populate_buf_reference_links(bufnr)
end

---Get an reference link string from an MdnReferenceLinkData object
---@param rldata MdnReferenceLinkData? Reference link object
---@return string reference_link
function M.get_rl_from_obj(rldata)
    if rldata == nil then return "" end
    return '[' .. rldata.text .. '][' .. rldata.label .. ']'
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

    vim.api.nvim_buf_set_text(rldata.buffer, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {new_rl})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buffer)
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

    vim.api.nvim_buf_set_text(rldata.buffer, rldata.lnum - 1, rldata.col_start - 1, rldata.lnum - 1, rldata.col_end - 1, {new_rl})

    if move_cursor == true then
        vim.cmd.buffer(rldata.buffer)
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

    local rldef = M.get_rl_definition(rldata.label, rldata.buffer)
    if rldef == nil then
        vim.notify("Mdn: No definition found for label '" .. rldata.label .. "'. If you can confirm it exists, try writing the buffer or parse definitions manually with ':Mdn reference_link populate_buf_reference_links'", vim.log.levels.ERROR)
        return
    end

    return require('mdnotes').open(rldef.destination)
end

function M.convert_from_inline(opts)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false
    local ildata = require('mdnotes.inline_link').parse({ location = opts.location })
    if ildata == nil or ildata.text == nil then return end

    -- Set the line and cursor position
    vim.api.nvim_buf_set_text(ildata.buffer, ildata.lnum - 1, ildata.col_start - 1, ildata.lnum - 1, ildata.col_end - 1, {'[' .. ildata.text .. '][]'})
    vim.api.nvim_buf_set_lines(ildata.buffer, vim.fn.line("$"), vim.fn.line("$") + 1, false, {'[' .. ildata.text .. ']: ' ..  ildata.destination})

    -- Update buf_reference_links
    M.populate_buf_reference_links(ildata.buffer)

    if move_cursor == true then
        vim.cmd.buffer(ildata.buffer)
        vim.fn.cursor({ildata.lnum, vim.fn.col('.') + 1})
    end
end

return M
