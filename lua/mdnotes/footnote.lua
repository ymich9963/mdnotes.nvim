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
---@param opts {footnote_reference: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation?}?
---@return MdnFootnoteReferenceData?
function M.parse(opts)
    opts = opts or {}

    local footnote_reference = opts.footnote_reference
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false

    vim.validate("reference_link", footnote_reference, { "string", "nil" })
    vim.validate("keep_pointy_brackets", keep_pointy_brackets, "boolean")

    local check_markdown_syntax = require('mdnotes').check_markdown_syntax
    local f_pattern = require("mdnotes.patterns").footnote_reference
    local txtdata = {}

    if footnote_reference == nil then
        if not check_markdown_syntax(f_pattern, { location = opts.location }) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(f_pattern, { location = opts.location })
        footnote_reference = txtdata.text or ""
    end

    local identifier = footnote_reference:match(require("mdnotes.patterns").footnote_identifier)
    local number = tonumber(identifier)
    local type
    if number ~= nil then
        type = "numeric"
        identifier = number
    else
        type = "word"
    end

    -- Table key 'text' also exists in txtdata but does not get ovewritten with "keep" behaviour
    return vim.tbl_extend("keep", {
        identifier = identifier,
        type = type,
    }, txtdata)
end

---Get the footnotes for specified buffer
---@param opts {buf: integer?, only_labels: boolean?}?
---@return table<MdnFootnote|string>?
function M.get_buf_footnotes(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local only_labels = opts.only_labels or false

    local footnotes = {}
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local footnote_pattern = require('mdnotes.patterns').footnote

    for lnum, line in ipairs(buf_lines) do
        local identifier, text = line:match(footnote_pattern)
        if identifier and text then
            if only_labels == false then
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

    if identifier == nil then
        identifier = tostring(M.fcounter)
        M.fcounter = M.fcounter + 1
    end

    vim.api.nvim_buf_set_text(buf, lnum - 1, cur_col, lnum - 1, cur_col, {'[^' .. identifier .. ']'})

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
function M.go_to_footnote(opts)
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
---@return string reference_link_definition
function M.get_footnote_from_obj(footnote)
    if footnote == nil then return "" end
    return '[^' .. footnote.identifier .. ']: ' .. footnote.text
end

---Update reference link definition label and destination
---@param opts {identifier:string?, new_identifier: string?, new_text: string?, location: MdnInLineLocation?, skip_input: boolean?, silent: boolean?}?
function M.update_footnote(opts)
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
        if v.label == identifier then
            v.label = new_identifier
            vim.api.nvim_buf_set_text(v.buf, v.lnum - 1, v.col_start - 1, v.lnum - 1, v.col_end - 1, {M.get_fref_from_obj(v)})
        end
    end

    -- Execute changes in reference link definition
    footnote.identifier = new_identifier or ""
    footnote.text = new_text or ""
    vim.api.nvim_buf_set_lines(buf, footnote.lnum - 1, footnote.lnum, false, {M.get_footnote_from_obj(footnote)})

    vim.cmd.wall({bang = true, mods = {silent = true, noautocmd = true}})
    M.populate_buf_footnotes(buf)
end

---Cleanup unused footnotes and references
---@param opts {buf: integer?, silent: boolean?}?
function M.cleanup(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local buf = opts.buf or vim.api.nvim_get_current_buf()

    local footnotes_tbl = M.get_buf_footnotes({ buf = buf })
    if footnotes_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No reference link definitions found in buffer", vim.log.levels.ERROR)
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

    table.sort(footnotes_tbl, function(a, b)
        return a.lnum > b.lnum
    end)

    for _, v in ipairs(footnotes_tbl) do
        local found_def = false
        for _, vv in pairs(parsed_tbl) do
            if v.label == vv.label then
                found_def = true
                break
            end
        end
        if found_def == false then
            vim.api.nvim_buf_set_lines(buf, v.lnum - 1, v.lnum, false, {})
        end
    end

    M.populate_buf_footnotes(buf)

    for _, v in pairs(parsed_tbl) do
        local found_link = false
        for _, vv in pairs(footnotes_tbl) do
            if v.label == vv.label then
                found_link = true
                break
            end
        end
        if found_link == false then
            vim.api.nvim_buf_set_text(v.buf, v.lnum - 1, v.col_start - 1, v.lnum - 1, v.col_end - 1, {v.text})
        end
    end
end

---Get an reference link string from an MdnReferenceLinkData object
---@param fdata MdnFootnoteReferenceData? Reference link object
---@return string reference_link
function M.get_fref_from_obj(fdata)
    if fdata == nil then return "" end
    return '[' .. fdata.identifier .. ']'
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

    local pattern = require('mdnotes.patterns').footnote_reference
    local scan_lines = require('mdnotes').scan_lines

    local scanned_lines = scan_lines(pattern, { location = {startl = startl, endl = endl, buf = buf }, silent = true})
    if scanned_lines == nil then return nil end

    local parsed_tbl = {}
    for _, item in ipairs(scanned_lines) do
        for _, cols in ipairs(item.cols) do
            local data = M.parse({ location = {buf = buf, lnum = item.lnum, col_start = cols[1], col_end = cols[2] }})
            if str == true then
                table.insert(parsed_tbl, M.get_fref_from_obj(data))
            else
                table.insert(parsed_tbl, data)
            end
        end
    end

    return parsed_tbl
end

---Find occurences of the same label in the reference link
---@param opts {identifier: string?, location: MdnInLineLocation?, silent: boolean?}?
function M.find_footnote_references(opts)
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
        if v.label == identifier then
            table.insert(qflist, {bufnr = v.buf, lnum = v.lnum, col = v.start_col, end_col = v.end_coa, text = v.text})
        end
    end

    vim.fn.setqflist(qflist)
    vim.cmd.copen()

    return qflist
end

---Find occurences of the same label in the reference link
---@param opts {location: MdnInLineLocation?, silent: boolean?}?
function M.renumber(opts)
    opts = opts or {}

    local silent = opts.silent or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        if silent == false then
            vim.notify("Mdn: No footnote references in current buffer", vim.log.levels.ERROR)
        end

        return
    end

    for i, v in pairs(parsed_tbl) do
        if v.type == "numeric" then
            
        end
    end
end

return M
