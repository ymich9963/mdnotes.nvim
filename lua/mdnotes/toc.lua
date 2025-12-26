local M = {}

M.buf_sections = {}

function M.get_section(section)
    for _, v in ipairs(M.buf_sections) do
        for i, vv in ipairs(v.parsed.gfm) do
            if vv == section then
                return v.parsed.original[i].text
            end
        end
    end
    return section
end

function M.get_sections_original()
    local sections = {}
    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local heading_format_pattern = require('mdnotes.patterns').heading

    for lnum, line in ipairs(buf_lines) do
        local heading, text = line:match(heading_format_pattern)
        if text and heading and #heading <= require('mdnotes.config').config.toc_depth then
            table.insert(sections, {heading = heading, text = text, lnum = lnum})
        end
    end

    return sections
end

function M.convert_text_to_gfm(text)
    local ret = text:lower():gsub("[^%d%a%p ]+", ""):gsub(" ", "-")
    return ret
end

function M.get_sections_gfm_from_original(original_sections)
    local gfm_sections = {}
    for _, section in ipairs(original_sections) do
        table.insert(gfm_sections, M.convert_text_to_gfm(section.text))
    end

    return gfm_sections
end

function M.generate()
    if vim.bo.filetype ~= "markdown" then
        vim.notify(("Mdn: Cannot generate a ToC for a non-Markdown file."), vim.log.levels.ERROR)
        return
    end

    local toc = {}
    local original_sections = {}
    local gfm_sections = {}
    local found = false

    local cur_buf_num = vim.api.nvim_get_current_buf()
    for _, v in ipairs(M.buf_sections) do
        if v.buf_num == cur_buf_num then
            original_sections = v.parsed.original
            gfm_sections = v.parsed.gfm
            found = true
        end
    end

    if not found then
        vim.notify(("Mdn: Parsed sections for current buffer not found."), vim.log.levels.ERROR)
        return
    end

    for i = 1, #original_sections do
        local _, hash_count = original_sections[i].heading:gsub("#", "")
        local spaces = string.rep(" ", vim.o.shiftwidth * (hash_count - 1), "")
        table.insert(toc, ("%s- [%s](#%s)"):format(spaces, original_sections[i].text, gfm_sections[i]))
    end
    vim.api.nvim_put(toc, "V", false, false)
end

return M
