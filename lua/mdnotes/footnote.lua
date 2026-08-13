---@module 'mdnotes.footnote'

local M = {}

---@class MdnFootnote
---@field identifier string Footnote identifier
---@field text string Footnote text
---@field lnum integer Footnote line number

---@class MdnBufFootnotes
---@field buf integer Buffer number
---@field footnotes table<MdnFootnote>

---Table containing buffer footnotes
---@type table<MdnBufFootnotes>
M.buf_footnotes = {}

---Counter for footnote number
---@type integer
M.fcounter = 1

---@class MdnFootnoteReferenceData: MdnInLineLocation
---@field identifier string Footnote identifier

---Get the footnote reference text, and the start and end columns
---@param opts {footnote_reference: string?, location: MdnInLineLocation?}?
---@return MdnFootnoteReferenceData?
function M.parse(opts)
    opts = opts or {}

    local fref = opts.footnote_reference

    vim.validate("footnote_reference", fref, { "string", "nil" })

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local fref_pattern = require("mdnotes.patterns").footnote_reference
    local f_pattern = require("mdnotes.patterns").footnote
    local txtdata = {}

    if fref == nil then
        if not check_markdown_syntax(fref_pattern, { location = opts.location }) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(fref_pattern, { location = opts.location })
        fref = txtdata.raw or ""

        -- Check if a footnote was matched instead of a footnote reference
        local line = vim.api.nvim_buf_get_lines(txtdata.buf, txtdata.lnum - 1, txtdata.lnum, false)[1]
        if line:match(f_pattern) then return nil end
    end

    local identifier = fref:match(require("mdnotes.patterns").footnote_identifier)

    -- Table key 'text' also exists in txtdata but does not get ovewritten with "keep" behaviour
    return vim.tbl_extend("force", {
        identifier = identifier,
    }, txtdata)
end

---Get the footnotes of the specified buffer
---@param opts {buf: integer?, only_identifiers: boolean?}?
---@return table<MdnFootnote|string>?
function M.get_buf_footnotes(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local only_identifiers = opts.only_identifiers or false

    local footnotes = {}
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local footnote_pattern = require('mdnotes.patterns').footnote

    for lnum, line in ipairs(buf_lines) do
        local identifier, text = line:match(footnote_pattern)
        if identifier and text then
            if only_identifiers == false then
                table.insert(footnotes, {identifier = string.lower(identifier), text = text, lnum = lnum})
            else
                table.insert(footnotes, string.lower(identifier))
            end
        end
    end

    return footnotes
end

---Populate the buf_footnotes table
---@param buf integer? Buffer number
function M.populate_buf_footnotes(buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    local footnotes_tbl = M.get_buf_footnotes({ buf = buf })

    local exists = false
    for _,v in ipairs(M.buf_footnotes) do
        if v.buf == buf then
            exists = true
            if v.footnotes ~= footnotes_tbl then
                v.footnotes = footnotes_tbl
            end

            break
        end
    end

    if exists == false then
        table.insert(M.buf_footnotes, {buf = buf, footnotes = footnotes_tbl})
    end
end

---Insert Markdown footnote
---@param opts {identifier: string?, text: string?, move_cursor: boolean?, location: MdnInLineLocation}?
function M.insert(opts)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local cur_col = locopts.cur_col or vim.fn.col('.')

    local move_cursor = opts.move_cursor ~= false
    local identifier = opts.identifier
    local text = opts.text or ""

    -- Ensure fcounter is at the correct value
    local buf_footnotes = {}
    for _, v in pairs(M.buf_footnotes) do
        if v.buf == buf then
            buf_footnotes = v.footnotes
        end
    end

    if M.fcounter ~= #buf_footnotes then
        M.fcounter = #buf_footnotes
    end

    -- Set identifier based on fcounter if not given
    if identifier == nil then
        M.fcounter = M.fcounter + 1
        identifier = tostring(M.fcounter)
    end

    vim.api.nvim_buf_set_text(buf, lnum - 1, cur_col - 1, lnum - 1, cur_col - 1, {'[^' .. identifier .. ']'})

    if M.get_footnote(identifier, buf) == nil then
        vim.api.nvim_buf_set_lines(buf, vim.fn.line("$"), vim.fn.line("$") + 1, false, {'[^' .. identifier .. ']: ' ..  text})
    end

    -- Update buf_footnotes
    M.populate_buf_footnotes(buf)

    if move_cursor == true then
        vim.cmd.buffer(buf)
        vim.fn.cursor({lnum, vim.fn.col('.') + 1})
    end
end

---Get the footnote object
---@param identifier string Footnote identifier
---@param buf integer?
---@return MdnFootnote?
function M.get_footnote(identifier, buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end
    if identifier == nil then return nil end

    for _, v in pairs(M.buf_footnotes) do
        if v.buf == buf then
            for _, vv in pairs(v.footnotes) do
                if vv.identifier == string.lower(identifier) then
                    return vv
                end
            end
            break
        end
    end
end

---Go to footnote
---@param opts {identifier: string?, location: MdnInLineLocation?, silent: boolean?}?
function M.go_to(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local identifier = opts.identifier
    local buf = (opts.location or {}).buf or vim.api.nvim_get_current_buf()

    if identifier == nil then
        local fdata = M.parse({ location = opts.location })
        if fdata == nil then return end
        identifier = fdata.identifier
    end

    local footnote = M.get_footnote(identifier, buf)
    if footnote == nil then
        if silent == false then
            vim.notify("Mdn: No footnote found for '" .. identifier .. "'", vim.log.levels.ERROR)
        end

        return
    end

    vim.cmd.buffer(buf)
    vim.fn.cursor({footnote.lnum, 1})
end

---Get a footnote string from an MdnFootnote object
---@param footnote MdnFootnote? Footnote object
---@return string footnote
function M.get_footnote_from_obj(footnote)
    if footnote == nil then return "" end
    return '[^' .. footnote.identifier .. ']: ' .. footnote.text
end

---Update footnote identifier and text
---@param opts {identifier:string?, new_identifier: string?, new_text: string?, location: MdnInLineLocation?, skip_input: boolean?, silent: boolean?}?
function M.update(opts)
    opts = opts or {}

    local identifier = opts.identifier
    local buf = (opts.location or {}).buf or vim.api.nvim_get_current_buf()
    local new_identifier = opts.new_identifier
    local new_text = opts.new_text
    local skip_input = opts.skip_input or false
    local silent = opts.silent or false

    local fdata
    if identifier == nil then
        fdata = M.parse({ location = opts.location })
        if fdata == nil or fdata.identifier == nil then
            if silent == false then
                vim.notify("Mdn: No reference link found for parsing", vim.log.levels.ERROR)
            end

            return
        end
        identifier = fdata.identifier
    end

    local footnote = M.get_footnote(identifier, buf)
    if footnote == nil then
        if silent == false then
            vim.notify("Mdn: No footnote found for identifier '" .. identifier .. "'", vim.log.levels.ERROR)
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

    if new_identifier == nil then
        if skip_input == false then
            vim.ui.input({prompt = "Update identifier: ", default = footnote.identifier }, function(input) new_identifier = input end)
        else
            new_identifier = footnote.identifier
        end
    end

    if new_text == nil then
        if skip_input == false then
            vim.ui.input({prompt = "Update text: ", default = footnote.text }, function(input) new_text = input end)
        else
            new_text = footnote.text
        end
    end

    -- Execute changes for reference links
    for _, v in pairs(parsed_tbl) do
        if v.identifier == identifier then
            v.identifier = new_identifier
            vim.api.nvim_buf_set_text(v.buf, v.lnum - 1, v.col_start - 1, v.lnum - 1, v.col_end - 1, {M.get_fref_from_obj(v)})
        end
    end

    -- Execute changes in reference link definition
    footnote.identifier = new_identifier or ""
    footnote.text = new_text or ""
    vim.api.nvim_buf_set_lines(buf, footnote.lnum - 1, footnote.lnum, false, {M.get_footnote_from_obj(footnote)})

    M.populate_buf_footnotes(buf)
end

---Cleanup unused footnotes and footnote references
---@param opts {buf: integer?, silent: boolean?}?
function M.cleanup(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local buf = opts.buf or vim.api.nvim_get_current_buf()

    local footnotes_tbl = M.get_buf_footnotes({ buf = buf })
    if footnotes_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No footnotes found in buffer", vim.log.levels.ERROR)
        end

        return
    end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No footnote references in current buffer", vim.log.levels.ERROR)
        end

        return
    end

    table.sort(footnotes_tbl, function(a, b)
        return a.lnum > b.lnum
    end)

    for _, v in ipairs(footnotes_tbl) do
        local found_f = false
        for _, vv in pairs(parsed_tbl) do
            if v.identifier == vv.identifier then
                found_f = true
                break
            end
        end
        if found_f == false then
            vim.api.nvim_buf_set_lines(buf, v.lnum - 1, v.lnum, false, {})
        end
    end

    footnotes_tbl = M.get_buf_footnotes({ buf = buf }) or {}
    for _, v in pairs(parsed_tbl) do
        local found_fref = false
        for _, vv in pairs(footnotes_tbl) do
            if v.identifier == vv.identifier then
                found_fref = true
                break
            end
        end
        if found_fref == false then
            vim.api.nvim_buf_set_text(v.buf, v.lnum - 1, v.col_start - 1, v.lnum - 1, v.col_end - 1, {})
        end
    end

    M.populate_buf_footnotes(buf)
end

---Get a footnote reference string from an MdnFootnoteReferenceData object
---@param fdata MdnFootnoteReferenceData? Footnote reference object
---@return string fref
function M.get_fref_from_obj(fdata)
    if fdata == nil then return "" end
    return '[^' .. fdata.identifier .. ']'
end

---Parse the footnote references in the specified lines
---@param opts {location: MdnMultiLineLocation?, str: boolean?, silent: boolean?, no_duplicates: boolean?}?
---@return table<MdnFootnoteReferenceData>?
function M.parse_lines(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local str = opts.str or false
    local pattern = require('mdnotes.patterns').footnote_reference
    local parse_lines = require('mdnotes').parse_lines

    local get_func = nil
    if str == true then
        get_func = M.get_fref_from_obj
    end

    return parse_lines(pattern, M.parse, {location = opts.location, silent = silent, no_duplicates = opts.no_duplicates, get_func = get_func})
end

---Find references of the same footnote identifier
---@param opts {identifier: string?, location: MdnInLineLocation?, silent: boolean?}?
function M.find_references(opts)
    opts = opts or {}

    local identifier = opts.identifier
    local silent = opts.silent or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()

    if identifier == nil then
        local fdata = M.parse({ location = opts.location })
        if fdata == nil or fdata.identifier == nil then
            if silent == false then
                vim.notify("Mdn: No footnote reference found for parsing", vim.log.levels.ERROR)
            end

            return
        end
        identifier = fdata.identifier
    end

    local footnote = M.get_footnote(identifier, buf)
    if footnote == nil then
        if silent == false then
            vim.notify("Mdn: No footnote found for identifier '" .. identifier .. "'", vim.log.levels.ERROR)
        end

        return
    end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No footnote references in current buffer", vim.log.levels.ERROR)
        end

        return
    end

    local qflist = {}
    for _, v in pairs(parsed_tbl) do
        if v.identifier == identifier then
            table.insert(qflist, {bufnr = v.buf, lnum = v.lnum, col = v.start_col, end_col = v.end_col, text = v.raw})
        end
    end

    vim.fn.setqflist(qflist)
    vim.cmd.copen()

    return qflist
end

---Renumber integer footnote references
---@param opts {location: MdnInLineLocation?, silent: boolean?}?
function M.renumber(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()

    -- Cleanup before renumbering
    M.cleanup({buf = buf})

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true, no_duplicates = true})
    if parsed_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No footnote references in current buffer", vim.log.levels.ERROR)
        end

        return
    end

    -- Remove words
    local parsed_numbers = {}
    for _, v in ipairs(parsed_tbl) do
        if tonumber(v.identifier) ~= nil then
            table.insert(parsed_numbers, v)
        end
    end

    -- Renumber references and footnotes
    for i, v in ipairs(parsed_numbers) do
        M.update({identifier = v.identifier, new_identifier = tostring(i), skip_input = true, silent = silent, location = opts.location })
    end

    -- Set new counter
    M.fcounter = #parsed_numbers

    -- Re-order footnotes based on new numbers
    local footnotes_tbl = M.get_buf_footnotes({buf = buf})
    if footnotes_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No footnotes found in buffer", vim.log.levels.ERROR)
        end

        return
    end

    local temp_lnum = 0
    table.sort(footnotes_tbl, function(a, b)
        if tonumber(a.identifier) == nil or tonumber(b.identifier) == nil then
            return false
        end

        if tonumber(a.identifier) < tonumber(b.identifier) then
            temp_lnum = b.lnum
            b.lnum = a.lnum
            a.lnum = temp_lnum
            return true
        end

        return false
    end)

    for _, v in ipairs(footnotes_tbl) do
        vim.api.nvim_buf_set_lines(buf, v.lnum - 1, v.lnum, false, {M.get_footnote_from_obj(v)})
    end

    M.populate_buf_footnotes(buf)
end

return M
