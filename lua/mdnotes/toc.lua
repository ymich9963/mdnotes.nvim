---@module 'mdnotes.toc'
local M = {}

---@class MdnotesFragment
---@field  hash string The '#' present in the heading
---@field  text string Original fragment text from the file headings
---@field  lnum integer Line number of the heading

---@alias MdnotesFragmentGfm table<string> Parsed GFM-style fragment text

---@class MdnotesBufFragments
---@field buf_num integer Buffer number
---@field parsed table<table<MdnotesFragment>, MdnotesFragmentGfm> 

---@type table<table<MdnotesBufFragments>>
M.buf_fragments = {}

---Parse the fragments in the buffer number
---@param bufnr integer Buffer number to parse the fragments
function M.populate_buf_fragments(bufnr)
    local buf_exists = false
    local fragments = M.get_fragments_from_buf(bufnr)
    for _,v in ipairs(M.buf_fragments) do
        if v.buf_num == bufnr then
            buf_exists = true
            -- Check if the fragments have changed
            if v.parsed.fragments ~= fragments then
                v.parsed.fragments = fragments
                v.parsed.gfm = M.parse_fragments_to_gfm_style(fragments)
            end
            break
        end
    end

    if buf_exists == false then
        table.insert(M.buf_fragments, {
            buf_num = bufnr,
            parsed = {
                fragments = fragments,
                gfm = M.parse_fragments_to_gfm_style(fragments)
            }
        })
    end
end

---Get fragments from the Markdown buffer headings
---@param bufnr integer?
---@return table<MdnotesFragment>
function M.get_fragments_from_buf(bufnr)
    if bufnr == nil then bufnr = 0 end
    local fragments = {}
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local heading_format_pattern = require('mdnotes.patterns').heading

    for lnum, line in ipairs(buf_lines) do
        local hash, text = line:match(heading_format_pattern)
        if text and hash and #hash <= require('mdnotes').config.toc_depth then
            table.insert(fragments, {hash = hash, text = text, lnum = lnum})
        end
    end

    return fragments
end

---Get fragment from GFM-style fragment
---@param fragment string GFM-style fragment
---@return string
function M.get_fragment_from_gfm(fragment)
    for _, v in ipairs(M.buf_fragments) do
        for i, vv in ipairs(v.parsed.gfm) do
            if vv == fragment then
                return v.parsed.fragments[i].text
            end
        end
    end

    return fragment
end

---Convert the inputted text to GFM-style text based on 
---https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links
---@param text string Text for conver
---@return string
function M.convert_text_to_gfm(text)
    -- Lowercase
    text =text:lower()

    -- Trim start and end whitespace
    text = vim.trim(text)

    -- Remove any non-alphanumeric
    -- characters but keep spaces
    text = text:gsub("[^%w ]+", "")

    -- Replaces spaces with dashes
    text = text:gsub(" ", "-")

    return text
end

---Get the GFM-style fragments from the fragment fragments
---@param fragments MdnotesFragment
---@return MdnotesFragmentGfm
function M.parse_fragments_to_gfm_style(fragments)
    local gfm_fragments = {}
    for _, fragment in ipairs(fragments) do
        table.insert(gfm_fragments, M.convert_text_to_gfm(fragment.text))
    end

    return gfm_fragments
end

---Generate Table of Contents (ToC)
---@param write_to_buf boolean? Whether to insert the resulting text or not
---@return table<string>|nil toc
function M.generate(write_to_buf)
    if write_to_buf == nil then write_to_buf = true end
    if vim.bo.filetype ~= "markdown" then
        vim.notify("Mdn: Cannot generate a ToC for a non-Markdown file", vim.log.levels.ERROR)
        return
    end

    local toc = {}
    local fragments = {}
    local gfm_fragments = {}
    local found = false

    local cur_buf_num = vim.api.nvim_get_current_buf()
    for _, v in ipairs(M.buf_fragments) do
        if v.buf_num == cur_buf_num then
            fragments = v.parsed.fragments
            gfm_fragments = v.parsed.gfm
            found = true
        end
    end

    if found == false then
        vim.notify("Mdn: Parsed fragments for current buffer not found", vim.log.levels.ERROR)
        return
    end

    for i = 1, #fragments do
        local _, hash_count = fragments[i].hash:gsub("#", "")
        local spaces = string.rep(" ", vim.o.shiftwidth * (hash_count - 1), "")
        table.insert(toc, ("%s- [%s](#%s)"):format(spaces, fragments[i].text, gfm_fragments[i]))
    end

    if write_to_buf == true then
        vim.print("true")
        vim.api.nvim_put(toc, "l", false, false)
        return nil
    elseif write_to_buf == false then
        vim.print("false")
        return toc
    end
end

return M
