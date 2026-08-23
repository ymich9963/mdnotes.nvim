---@module 'mdnotes.toc'

local M = {}

---@class MdnToc: MdnMultiLineLocation
---@field lines table<string>
---@field depth integer

local check_markdown_lsp_cur_buf = function() return require('mdnotes').check_markdown_lsp_cur_buf() end

---Generate Table of Contents (ToC)
---@param opts { buf: integer?, lnum: integer?, write: boolean?, depth: integer?, silent: boolean?}?
---@return MdnToc? toc
function M.generate(opts)
    vim.validate("opts", opts, "table", true)

    opts = opts or {}
    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local lnum = opts.lnum or vim.fn.line('.')
    local depth = opts.depth or require('mdnotes').config.toc_depth
    local write = opts.write ~= false
    local silent = opts.silent or false

    vim.validate("depth", depth, "number")
    vim.validate("write", write, "boolean")
    vim.validate("silent", silent, "boolean")

    if vim.bo.filetype ~= "markdown" then
        if silent == false then
            vim.notify("Mdn: Cannot generate a ToC for a non-Markdown file", vim.log.levels.ERROR)
        end

        return nil
    end

    local toc = {}
    local fragments = {}
    local found = false
    local buf_fragments = require('mdnotes').buf_fragments

    for _, v in ipairs(buf_fragments) do
        if v.buf == buf then
            fragments = v.fragments
            found = true
            break
        end
    end

    if found == false then
        if silent == false then
            vim.notify("Mdn: Parsed fragments for buffer '" .. buf .. "' not found", vim.log.levels.ERROR)
        end

        return nil
    end

    for i = 1, #fragments do
        local hash_count = select(2, fragments[i].hash:gsub("#", ""))
        if hash_count <= tonumber(depth) then
            local spaces = string.rep(" ", vim.o.shiftwidth * (hash_count - 1), "")
            table.insert(toc, ("%s- [%s](#%s)"):format(spaces, fragments[i].text, fragments[i].gfm))
        end
    end

    if write == true then
        vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum - 1, false, toc)
    end

    return {
        contents = toc,
        depth = depth,
        startl = lnum,
        endl = lnum + #toc - 1,
        buf = buf
    }
end

---Check if there is a ToC in the specified search range or under the cursor
---@param opts {search: MdnSearchOpts?}?
---@return MdnSearchResult
function M.check_toc_valid(opts)
    vim.validate("opts", opts, "table", true)

    opts = opts or {}
    local search_opts = opts.search or {}
    vim.validate("search_opts", search_opts, "table")

    local buf = search_opts.buf or vim.api.nvim_get_current_buf()
    local origin_lnum = search_opts.origin_lnum or vim.fn.line('.')
    local lower_limit_lnum = search_opts.upper_limit_lnum or 1
    local upper_limit_lnum = search_opts.lower_limit_lnum or vim.fn.line('$')

    local toc_startl = 0
    local toc_endl = 0
    local resolve_list_content = require('mdnotes.formatting').parse_list_item
    local il_parse = require('mdnotes.inline_link').parse

    for i = origin_lnum, lower_limit_lnum, -1 do
        local cur_line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
        local lcontent = resolve_list_content(cur_line)
        if lcontent == nil then break end
        if lcontent.text == "" then break end
        local ildata = il_parse({ inline_link = lcontent.text })
        if ildata == nil then break end
        toc_startl = i
    end

    if toc_startl == 0 then
        return { valid = false }
    end

    for i = origin_lnum, upper_limit_lnum do
        local cur_line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
        local lcontent = resolve_list_content(cur_line)
        if lcontent == nil then break end
        if lcontent.text == "" then break end
        local ildata = il_parse({ inline_link = lcontent.text })
        if ildata == nil then break end
        toc_endl = i
    end

    if toc_endl == 0 then
        return { valid = false }
    end

    return {
        valid = true,
        buf = buf,
        startl = toc_startl,
        endl = toc_endl,
    }
end

---Parse the table
---@param opts {silent: boolean?, search: MdnSearchOpts?}?
---@return MdnToc?
function M.parse(opts)
    vim.validate("opts", opts, "table", true)

    opts = opts or {}
    local search_opts = opts.search or {}
    vim.validate("search_opts", search_opts, "table")

    local buf = search_opts.buf or vim.api.nvim_get_current_buf()
    local silent = opts.silent or false

    vim.validate("silent", silent, "boolean")

    local tocsearch = M.check_toc_valid({ search = search_opts })
    if tocsearch.valid == false then
        if silent == false then
            vim.notify("Mdn: No valid ToC detected", vim.log.levels.ERROR)
        end

        return
    end

    local toc_lines = vim.api.nvim_buf_get_lines(buf, tocsearch.startl - 1, tocsearch.endl, false)
    if vim.tbl_isempty(toc_lines) then
        if silent == false then
            vim.notify("Mdn: Error parsing ToC", vim.log.levels.ERROR)
        end

        return
    end

    local depth = 1
    local resolve_list_content = require('mdnotes.formatting').parse_list_item
    for _, line in ipairs(toc_lines) do
        local indent_count = select(2, resolve_list_content(line).indent:gsub(" ", ""))
        if indent_count ~= 0 then
            local temp = (indent_count / vim.o.shiftwidth) + 1
            if temp > depth then
                depth = temp
            end
        end
    end

    if depth % 1 ~= 0 then
        if silent == false then
            vim.notify("Mdn: ToC depth cannot be fractional, please check indentation", vim.log.levels.ERROR)
        end

        return
    end

    return {
        contents = toc_lines,
        depth = depth,
        startl = tocsearch.startl,
        endl = tocsearch.endl,
        buf = buf
    }
end

---Update ToC in-place
---@param opts {depth: integer?, write: boolean?, search: MdnSearchOpts?, silent: boolean?}?
---@return MdnToc? toc
function M.update(opts)
    vim.validate("opts", opts, "table", true)

    opts = opts or {}
    local silent = opts.silent or false
    local write = opts.write ~= false

    local tocdata = M.parse({ silent = silent, search = opts.search })
    if tocdata == nil then
        -- Errors would already be outputted
        return
    end

    vim.api.nvim_buf_set_lines(tocdata.buf, tocdata.startl - 1, tocdata.endl, false, {})

    local depth = opts.depth or tocdata.depth

    return M.generate({ depth = tonumber(depth), write = write })
end

---Browse the ToC in a location list. Uses gO if LSP is enabled.
function M.browse()
    if check_markdown_lsp_cur_buf() then
        vim.api.nvim_feedkeys("gO", "n", true)

        return
    end

    local pattern = "^\\#+ .+"
    if vim.o.grepprg == "internal" then
        pattern = pattern:gsub("+", "*")
        pattern = "/" .. pattern .. "/"
    else
        pattern = "'" .. pattern .. "'"
    end

    vim.cmd.lgrep({args = {pattern, "%"}, mods = {emsg_silent = true}})
    vim.cmd.lopen()
end

return M
