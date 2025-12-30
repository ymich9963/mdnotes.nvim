local M = {}

local function get_current_header(buf_fragments)
    local cur_buf_num = vim.api.nvim_get_current_buf()
    local cur_lnum = vim.fn.line(".")

    for _, v in ipairs(buf_fragments) do
        for j, vv in ipairs(v.parsed.original) do
            -- Once the header entry's lnum is more than the current
            -- it means we have to subtract 1 to get the current header
            if v.buf_num == cur_buf_num and vv.lnum > cur_lnum then
                return v.parsed.original[j - 1], j - 1, cur_buf_num
            end
        end
    end
end

function M.goto_next()
    local buf_fragments = require('mdnotes.toc').buf_fragments
    local _, index, cur_buf_num = get_current_header(buf_fragments)

    for _, v in ipairs(buf_fragments) do
        if v.buf_num == cur_buf_num then
            vim.fn.cursor(vim.fn.search(v.parsed.original[index + 1].text), 1)
            vim.api.nvim_input('zz')
            break
        end
    end
end

function M.goto_previous()
    local buf_fragments = require('mdnotes.toc').buf_fragments
    local _, index, cur_buf_num = get_current_header(buf_fragments)

    for _, v in ipairs(buf_fragments) do
        if v.buf_num == cur_buf_num then
            -- Reset to 2 so that in the next line it is 1
            if index - 1 < 1 then index = 2 end
            vim.fn.cursor(vim.fn.search(v.parsed.original[index - 1].text), 1)
            vim.api.nvim_input('zz')
            break
        end
    end
end

return M
