---@module 'mdnotes.assets'

local M = {}

---@class MdnReferenceLinkData: MdnInLineLocation
---@field text string Reference link text
---@field label string Reference link label

---Get the reference link data such as the link text, link label, and the start and end columns
---@param opts {reference_link: string?, keep_pointy_brackets: boolean?, location: MdnInLineLocation?}?
---@return MdnInlineLinkData?
function M.parse(opts)
    opts = opts or {}

    local reference_link = opts.reference_link
    local keep_pointy_brackets = opts.keep_pointy_brackets ~= false

    vim.validate("inline_link", reference_link, { "string", "nil" })
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
function M.get_buf_reference_link_entries(bufnr)
    if bufnr == nil then bufnr = 0 end
    local reference_links = {}
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local rl_entry_pattern = require('mdnotes.patterns').reference_link_entry

    for lnum, line in ipairs(buf_lines) do
        local label, destination = line:match(rl_entry_pattern)
        if label and destination then
            table.insert(reference_links, {label = label, destination = destination, lnum = lnum})
        end
    end

    return reference_links
end

return M
