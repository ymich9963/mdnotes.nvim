local M = {}

M.buf_fragments = {}

function M.get_fragment(fragment)
    for _, v in ipairs(M.buf_fragments) do
        for i, vv in ipairs(v.parsed.gfm) do
            if vv == fragment then
                return v.parsed.original[i].text
            end
        end
    end
    return fragment
end

function M.get_fragments_original()
    local fragments = {}
    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local heading_format_pattern = require('mdnotes.patterns').heading

    for lnum, line in ipairs(buf_lines) do
        local heading, text = line:match(heading_format_pattern)
        if text and heading and #heading <= require('mdnotes').config.toc_depth then
            table.insert(fragments, {heading = heading, text = text, lnum = lnum})
        end
    end

    return fragments
end

function M.convert_text_to_gfm(text)
    local ret = text:lower():gsub("[^%d%a%p ]+", ""):gsub(" ", "-")
    return ret
end

function M.get_fragments_gfm_from_original(original_fragments)
    local gfm_fragments = {}
    for _, fragment in ipairs(original_fragments) do
        table.insert(gfm_fragments, M.convert_text_to_gfm(fragment.text))
    end

    return gfm_fragments
end

function M.generate()
    if vim.bo.filetype ~= "markdown" then
        vim.notify(("Mdn: Cannot generate a ToC for a non-Markdown file."), vim.log.levels.ERROR)
        return
    end

    local toc = {}
    local original_fragments = {}
    local gfm_fragments = {}
    local found = false

    local cur_buf_num = vim.api.nvim_get_current_buf()
    for _, v in ipairs(M.buf_fragments) do
        if v.buf_num == cur_buf_num then
            original_fragments = v.parsed.original
            gfm_fragments = v.parsed.gfm
            found = true
        end
    end

    if not found then
        vim.notify(("Mdn: Parsed fragments for current buffer not found."), vim.log.levels.ERROR)
        return
    end

    for i = 1, #original_fragments do
        local _, hash_count = original_fragments[i].heading:gsub("#", "")
        local spaces = string.rep(" ", vim.o.shiftwidth * (hash_count - 1), "")
        table.insert(toc, ("%s- [%s](#%s)"):format(spaces, original_fragments[i].text, gfm_fragments[i]))
    end
    vim.api.nvim_put(toc, "V", false, false)
end

return M
