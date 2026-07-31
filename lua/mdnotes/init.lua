---@module 'mdnotes'

local M = {}

local uv = vim.loop or vim.uv

---@class MdnInLineLocation
---@field buf integer? Buffer number
---@field lnum integer? Line number
---@field col_start integer? Start column of text
---@field col_end integer? End column of text
---@field cur_col integer? Set the current cursor position on the line

---@class MdnMultiLineLocation
---@field buf integer? Buffer number
---@field startl integer? Start line
---@field endl integer? End line

---@class MdnSearchOpts
---@field buf integer?
---@field origin_lnum integer? Line number between the lower and upper limits
---@field lower_limit_lnum integer? Lower line number limit of search
---@field upper_limit_lnum integer? Higher line number limit of search

---@class MdnSearchResult
---@field valid boolean Is the search item valid
---@field buf integer? Buffer number
---@field startl integer? Start line of the item
---@field endl integer? End line of the item

---@class MdnText: MdnInLineLocation
---@field text string? Text in the corresponding location

---@type MdnConfig
M.config = {}

---@type string Open command for opening buffers
M.open_cmd = nil

---@type string Current working directory
M.cwd = nil

---@type string Plugin install directory
M.plugin_install_dir = nil

---@class MdnFragment
---@field hash string The '#' present in the heading
---@field text string Original fragment text from the file headings
---@field gfm string GFM style text of fragment
---@field lnum integer Line number of the heading

---@class MdnBufFragments
---@field buf integer Buffer number
---@field fragments table<MdnFragment> 

---@type table<MdnBufFragments>
M.buf_fragments = {}

---Mdnotes Config Class
---@class MdnConfig
---@field index_file string? Index file name or path
---@field journal_file (string|fun(): string)? Journal file name or path
---@field assets_path (string|fun(): string)? Path to assets folder
---@field asset_insert_behaviour '"copy"'|'"move"'? Behaviour when inserting assets from clipboard
---@field asset_overwrite_behaviour '"overwrite"'|'"error"'? Behaviour when the asset being inserted already exists
---@field asset_delete_behaviour '"remove"'|'"garbage"'? Behaviour when the deleting an asset
---@field open_behaviour '"buffer"'|'"tab"'|'"split"'|'"vsplit"'? Behaviour when opening buffers
---@field strong_format '"**"'|'"__"'? Strong format delimiter
---@field emphasis_format '"*"'|'"_"'? Emphasis format delimiter
---@field date_format string? Date format when using journal_insert_entry(), see :h strftime()
---@field prefer_lsp boolean? To prefer Markdown LSP functions rather than the mdnotes functions
---@field auto_list_continuation boolean? Automatic list continuation
---@field auto_list_renumber boolean? Automatic renumbering of ordered lists
---@field auto_table_best_fit boolean? Automatic table best fit
---@field default_keymaps boolean?
---@field autocmds boolean|MdnAutocmdsConfig?
---@field table_best_fit_padding integer? Add padding around cell contents when using tables_best_fit
---@field toc_depth integer? Depth shown in the ToC
---@field user_commands table? User commands in the Mdn namespace
local default_config = {
    index_file = "",
    journal_file = "",
    assets_path = "",
    asset_insert_behaviour = "copy",
    asset_overwrite_behaviour = "error",
    asset_delete_behaviour = "garbage",
    open_behaviour = "buffer",
    strong_format = "**",
    emphasis_format = "*",
    date_format = "%a %d %b %Y",
    prefer_lsp = false,
    auto_list_continuation = true,
    default_keymaps = false,
    autocmds = true,
    table_best_fit_padding = 0,
    toc_depth = 4,
    user_commands = {}
}

---Mdnotes Config for autocmds
---@class MdnAutocmdsConfig
---@field set_cwd boolean set_cwd() autocmd for path resolution
---@field record_buf boolean record_buf() autocmd for buffer history
---@field populate_buf_fragments boolean populate_buf_fragments() autocmd for ToC fragments
---@field ordered_list_renumber boolean ordered_list_renumber() autocmd for ordered lists
---@field table_best_fit boolean best_fit() autocmd for tables
---@field outliner_state boolean autocmd for Outliner mode state notification
---@field journal_insert_entry boolean autocmd for inserting a journal entry on opening the journal file
---@field populate_buf_reference_links boolean populate_buf_reference_links() autocmd reference links
local default_autocmd_config = {
    set_cwd = true,
    record_buf = true,
    populate_buf_fragments = true,
    ordered_list_renumber = true,
    table_best_fit = true,
    outliner_state_notification = true,
    journal_insert_entry = true,
    populate_buf_reference_links = true
}

---Validate user config
---@param user_config MdnConfig
---@return MdnConfig
local function validate_config(user_config)
    local config = vim.tbl_deep_extend("force", default_config, user_config or {})

    vim.validate("index_file", config.index_file, "string")
    vim.validate("journal_file", config.journal_file, {"string", "function"})
    vim.validate("assets_path", config.assets_path, {"string", "function"})
    vim.validate("asset_insert_behaviour", config.asset_insert_behaviour, "string", false, "'copy' or 'move'")
    vim.validate("asset_overwrite_behaviour", config.asset_overwrite_behaviour, "string", false, "'overwrite' or 'error'")
    vim.validate("asset_delete_behaviour", config.asset_delete_behaviour, "string", false, "'remove' or 'garbage'")
    vim.validate("open_behaviour", config.open_behaviour, "string", false, "'buffer', 'tab', 'split', or 'vsplit'")
    vim.validate("strong_format", config.strong_format, "string", false, "'**' or '__'")
    vim.validate("emphasis_format", config.emphasis_format, "string", false, "'*' or '_'")
    vim.validate("date_format", config.date_format, "string")
    vim.validate("prefer_lsp", config.prefer_lsp, "boolean")
    vim.validate("auto_list_continuation", config.auto_list_continuation, "boolean")
    vim.validate("default_keymaps", config.default_keymaps, "boolean")
    vim.validate("autocmds", config.autocmds, {"boolean", "table"})
    vim.validate("table_best_fit_padding", config.table_best_fit_padding, "number")
    vim.validate("toc_depth", config.toc_depth, "number")
    vim.validate("user_commands", config.user_commands, "table")

    return config
end

---Resolve the autocmd config options
local function resolve_autocmd_config()
    if type(M.config.autocmds) == "table" then
        M.config.autocmds = vim.tbl_deep_extend("force", vim.deepcopy(default_autocmd_config), M.config.autocmds)
    end

    if M.config.autocmds == false then
        M.config.autocmds = vim.tbl_map(function() return false end, default_autocmd_config)
    end

    if M.config.autocmds == true or M.config.autocmds == nil then
        M.config.autocmds = vim.deepcopy(default_autocmd_config)
    end

    -- Delete if false
    if M.config.autocmds.set_cwd == false then
        vim.api.nvim_del_augroup_by_name('mdn.cwd')
    end
    if M.config.autocmds.record_buf == false then
        vim.api.nvim_del_augroup_by_name('mdn.record')
    end
    if M.config.autocmds.populate_buf_fragments == false then
        vim.api.nvim_del_augroup_by_name('mdn.pop_frag')
    end
    if M.config.autocmds.ordered_list_renumber == false then
        vim.api.nvim_del_augroup_by_name('mdn.renumber')
    end
    if M.config.autocmds.table_best_fit == false then
        vim.api.nvim_del_augroup_by_name('mdn.best_fit')
    end
    if M.config.autocmds.outliner_state_notification == false then
        vim.api.nvim_del_augroup_by_name('mdn.outliner')
    end
    if M.config.autocmds.journal_insert_entry == false then
        vim.api.nvim_del_augroup_by_name('mdn.journal')
    end
    if M.config.autocmds.populate_buf_reference_links == false then
        vim.api.nvim_del_augroup_by_name('mdn.pop_rl')
    end
end

local function resolve_open_cmd()
    if M.config.open_behaviour == "buffer" then
        M.open_cmd = 'edit '
    elseif M.config.open_behaviour == "tab" then
        M.open_cmd = 'tabnew '
    elseif M.config.open_behaviour == "split" then
        M.open_cmd = 'split '
    elseif M.config.open_behaviour == "vsplit" then
        M.open_cmd = 'vsplit '
    end
end

---Setup function
---@param user_config MdnConfig
function M.setup(user_config)
    M.config = validate_config(user_config)
    M.config.index_file = vim.fs.normalize(M.config.index_file)

    resolve_open_cmd()
    resolve_autocmd_config()

    M.set_cwd()

    -- Get plugin install dir
    for _, dir in ipairs(vim.api.nvim_list_runtime_paths()) do
        if dir:match(".*mdnotes.nvim$") then
            M.plugin_install_dir = vim.fs.normalize(dir)
            break
        end
    end
end

---Set the current working directory
function M.set_cwd()
    M.cwd = vim.fs.normalize(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
end

---Open the buffer using the cwd
---@param buf integer|string
---@param opts {hor: boolean?, vert: boolean?}?
function M.open_buf(buf, opts)
    opts = opts or {}
    local hor = opts.hor or false
    local vert = opts.vert or false

    vim.validate("buf", buf, {"number", "string"})
    vim.validate("hor", hor, "boolean")
    vim.validate("vert", vert, "boolean")

    if hor == true and vert == true then
        hor = false
        vert = false
    end

    local open_cmd = ""
    if hor == true then
        open_cmd = "split "
    elseif vert == true then
        open_cmd = "vsplit "
    else
        open_cmd = M.open_cmd
    end

    local edit_cmd = ""
    if type(buf) == "number" then
        edit_cmd = open_cmd .. buf
    elseif type(buf) == "string" then
        vim.cmd.cd({ args = {M.cwd}, mods = {silent = true}})
        edit_cmd = open_cmd .. buf
    end

    vim.cmd(edit_cmd)
end

---Resolving any required internal :grep calls
---@param pattern string grep pattern
---@param path string File path
function M.mdn_grep(pattern, path)
    if vim.o.grepprg == "internal" then
        pattern = pattern:gsub("<", "\\<")
        pattern = pattern:gsub("/", "\\/")
        pattern = "/\\v" .. pattern .. "/"
        path = vim.fs.joinpath(vim.fs.normalize(path), "*")
    else
        pattern = '"' .. pattern .. '"'
    end

    vim.cmd.grep({args = {pattern, path}, mods = {emsg_silent = true}})
end

---Check text for valid Markdown syntax
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnInLineLocation?, entire_line: boolean?}?
---@return boolean? valid, table|table<table>? cols_tbl
function M.check_markdown_syntax(pattern, opts)
    opts = opts or {}
    vim.validate("pattern", pattern, "string")

    local entire_line = opts.entire_line or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')
    local col_end = locopts.col_end or vim.fn.col('.')
    local cur_col = locopts.cur_col or math.floor((col_start + col_end)/2)

    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    local cols_tbl = {}

    for start_pos, text, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        local pos_tbl = {start_pos, end_pos}
        if entire_line == false then
            if start_pos <= cur_col and end_pos > cur_col then
                return true, pos_tbl
            end
        else
            table.insert(cols_tbl, pos_tbl)
        end
    end

    if not vim.tbl_isempty(cols_tbl) then
        return true, cols_tbl
    end

    return false, {}
end

---Check if Markdown LSP server can be used in the current buffer
---@return boolean
function M.check_markdown_lsp_cur_buf()
    if not vim.tbl_isempty(vim.lsp.get_clients({bufnr = 0})) and vim.bo.filetype == "markdown" and M.config.prefer_lsp == true then
        return true
    else
        return false
    end
end

---Get the text that was either, selected using Visual mode, under cursor in Normal mode, or specified using the opts table
---@param opts {location: MdnInLineLocation?}?
---@return MdnText
function M.get_text(opts)
    opts = opts or {}
    local locopts = opts.location or {}

    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.getpos("'<")[3]
    local col_end = locopts.col_end or vim.fn.getpos("'>")[3]
    local cur_col = locopts.cur_col or vim.fn.col('.')

    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]

    -- Limit the end column value
    -- Visual mode and grep can give end_col values after the line ending
    if col_end > #line then
        col_end = #line
    end

    local text = line:sub(col_start, col_end)

    -- This would happen by default when executing in Normal mode
    if col_start == col_end then
        vim.api.nvim_buf_call(buf, function()
            -- Ensure cursor is at the correct spot
            vim.fn.cursor(lnum, cur_col)

            -- Get the word under cursor and cursor position
            text = vim.fn.expand("<cWORD>")
        end)

        -- Search for the word in the line and check if it's under the cursor
        for i = 1, #line do
            local start_pos, end_pos = line:find(text, i, true)
            if start_pos and end_pos then
                if start_pos <= cur_col and end_pos >= cur_col then
                    col_start = start_pos
                    col_end = end_pos
                    break
                end
            end
        end
    end

    -- Reset markers
    vim.fn.setpos("'<", {0,1,1,0})
    vim.fn.setpos("'>", {0,1,1,0})

    return {
        buf = buf,
        lnum = lnum,
        col_start = col_start,
        col_end = col_end,
        cur_col = cur_col,
        text = text,
    }
end

---Get the text inside a pattern as well as the start and end columns
---Can use opts.location to specify location of search
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnInLineLocation?}?
---@return MdnText
function M.get_text_in_pattern(pattern, opts)
    opts = opts or {}

    vim.validate("pattern", pattern, "string")

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')
    local col_end = locopts.col_end or vim.fn.col('.')
    local cur_col = locopts.cur_col or math.floor((col_start + col_end) / 2)

    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]

    local found_text = ""
    for start_pos, search_text, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos <= cur_col and end_pos > cur_col then
            found_text = search_text
            col_start = start_pos
            col_end = end_pos
            break
        end
    end

    return {
        buf = buf,
        lnum = lnum,
        col_start = col_start,
        col_end = col_end,
        cur_col = cur_col,
        text = found_text,
    }
end

---Get the list item's indent level and delimiter. Also increment when using ordered lists
---@param inc_val integer Value to increment the list item by
---@return string indent, string list_delimiter Indent of the list item and the corresponding list delimiter
local function get_indent_indicator(inc_val)
    local mdnotes_patterns = require('mdnotes.patterns')
    local line = vim.api.nvim_get_current_line()
    local lcontent = require('mdnotes.formatting').resolve_list_content(line)
    if lcontent == nil then return "", "\n" end

    local check_text = lcontent.text:gsub(mdnotes_patterns.task, ""):gsub("[%s]", "")

    if check_text and check_text ~= "" then
        if lcontent.type == "unordered" then
            if lcontent.text:match(mdnotes_patterns.task) then
                return lcontent.indent, "\n" .. lcontent.marker .. " " .. "[ ] "
            else
                return lcontent.indent, "\n" .. lcontent.marker .. " "
            end
        end

        if lcontent.type == "ordered" then
            if lcontent.text:match(mdnotes_patterns.task) then
                return lcontent.indent, "\n" .. tostring(tonumber(lcontent.marker + inc_val)) .. lcontent.separator .. " " .. "[ ] "
            else
                return lcontent.indent, "\n" .. tostring(tonumber(lcontent.marker + inc_val)) .. lcontent.separator .. " "
            end
        end
    end

    return lcontent.indent, "\n"
end

---New line remaps
---@param key '"o"'|'"O"'|'"<CR>"'
---@param expr boolean If remap is used when opts.expr is true
---@return string?
function M.new_line_remap(key, expr)
    vim.validate("key", key, "string")
    vim.validate("expr_set", expr, "boolean")

    local lnum = vim.fn.line('.')
    local indent, list_remap = "", ""

    if key == "o" or key == "<CR>" then
        indent, list_remap = get_indent_indicator(1)
    elseif key == "O" then
        indent, list_remap = get_indent_indicator(-1)
    else
        return nil
    end

    if expr == true then
        return list_remap
    end

    list_remap = list_remap:gsub("[\n]","")

    if indent == nil then
        indent = ""
    end

    if key == "o" or key == "<CR>" then
        vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { indent .. list_remap })
        vim.fn.cursor({ lnum + 1, #indent + #list_remap + 1 })
    elseif key == "O" then
        vim.api.nvim_buf_set_lines(0, lnum - 1, lnum - 1, false, { indent .. list_remap })
        vim.fn.cursor({ lnum, #indent + #list_remap + 1 })
    end

    vim.api.nvim_input('a')
end

---Go to index file
function M.go_to_index_file()
    if M.config.index_file == "" then
        vim.notify("Mdn: Please specify an index file to use this feature", vim.log.levels.ERROR)
        return
    end

    M.open_buf(M.config.index_file)
end

---Open containing folder of current file
function M.open_containing_folder()
    vim.ui.open(M.cwd)
end

---@class MdnGetFilesInCwdOpts
---@field extension string? Specify extension e.g. ".md". Use ".*" for all file extensions
---@field hidden boolean? Get hidden files
---@field fs_type '"file"'|'"directory"'|'"link"'|'"fifo"'|'"socket"'|'"char"'|'"block"'|'"unknown"'|'"all"'? Specify type from vim.fs.dir() return
---@field pattern string? Lua pattern for names containing pattern

---Get the files in the cwd
---@param opts MdnGetFilesInCwdOpts?
---@return table<string> files Table with file names
function M.get_files_in_cwd(opts)
    opts = opts or {}

    local extension = opts.extension
    local hidden = opts.hidden
    local fs_type = opts.fs_type
    local pattern = opts.pattern

    vim.validate("extension", extension, {"string", "nil"})
    vim.validate("hidden", hidden, {"boolean", "nil"})
    vim.validate("fs_type", fs_type, {"string", "nil"})
    vim.validate("pattern", pattern, {"string", "nil"})

    local cwd = require('mdnotes').cwd
    local files = {}
    local add = false
    for name, type in vim.fs.dir(cwd) do
        if extension ~= nil then
            if name:match("^.*(%..*)") == extension or extension == ".*" then
                add = true
            else
                add = false
            end
        end

        if hidden ~= nil then
            if name:sub(1,1) == "." and hidden == true then
                add = true
            else
                add = false
            end
        end

        if fs_type ~= nil then
            if type == fs_type or type == "all" then
                add = true
            else
                add = false
            end
        end

        if pattern ~= nil then
            if name:match(pattern) then
                add = true
            else
                add = false
            end
        end

        if add == true then
            table.insert(files, name)
            add = false
        end
    end

    return files
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

---Parse the fragments in the specified buffer and update buf_fragments
---@param buf integer? Buffer number to parse the fragments
function M.populate_buf_fragments(buf)
    if buf == nil then buf = vim.api.nvim_get_current_buf() end

    local fragments_tbl = M.get_buf_fragments(buf)

    local exists = false
    for _,v in ipairs(M.buf_fragments) do
        if v.buf == buf then
            exists = true
            if v.fragments ~= fragments_tbl then
                v.fragments = fragments_tbl
            end

            break
        end
    end

    if exists == false then
        table.insert(M.buf_fragments, {buf = buf, fragments = fragments_tbl})
    end
end

---Get fragments from the Markdown buffer headings
---@param buf integer?
---@return table<MdnFragment>
function M.get_buf_fragments(buf)
    if buf == nil then buf = 0 end
    local fragments = {}
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local heading_format_pattern = require('mdnotes.patterns').heading

    for lnum, line in ipairs(buf_lines) do
        local hash, text = line:match(heading_format_pattern)
        if text and hash then
            table.insert(fragments, {hash = hash, text = text, gfm = M.convert_text_to_gfm(text), lnum = lnum})
        end
    end

    return fragments
end

---Find the fragment in the buf_fragments table of the specified buffer
---@param buf integer Buffer number
---@param fragment string Fragment
---@return string?
function M.find_fragment_in_buf_fragments(buf, fragment)
    local fragments
    for _, v in ipairs(M.buf_fragments) do
        if v.buf == buf then
            fragments = v.fragments
            break
        end
    end

    if fragments == nil then
        return nil
    end

    -- Check if it is a GFM style fragment
    for _, v in pairs(fragments) do
        if v.gfm == fragment then
            return v.text
        elseif v.text == fragment then
            return v.text
        end
    end

    return nil
end

---Get the buffer number from the buffer list using the buffer name 
---@param bufname string Buffer name
function M.get_buf_from_buf_list(bufname)
    local buf_list = vim.api.nvim_list_bufs()
    local ret = nil

    for _, buf in ipairs(buf_list) do
        local filename = vim.fs.basename(vim.api.nvim_buf_get_name(buf))
        if filename == bufname then
            ret = buf
            break
        end
    end

    return ret
end

---@class MdnScanLines
---@field lnum number Line number of specified pattern
---@field cols table<number, number> Table containing start and end columns of specified pattern

---Scan lines for inline Markdown items
---@param pattern MdnPattern Pattern that also returns start and end column numbers
---@param opts {location: MdnMultiLineLocation?, silent: boolean?}?
---@return table<MdnScanLines>?
function M.scan_lines(pattern, opts)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')
    local silent = opts.silent ~= false

    vim.validate("buf", buf, "number")
    vim.validate("silent", silent, "boolean")
    vim.validate("startl", startl, "number")
    vim.validate("endl", endl, "number")

    local scan_tbl = {}
    for lnum = startl, endl do
        local valid, cols_tbl = M.check_markdown_syntax(pattern, {entire_line = true, location = {lnum = lnum, buf = buf}})
        if valid == true then
            table.insert(scan_tbl, {lnum = lnum, cols = cols_tbl})
        end
    end

    if vim.tbl_isempty(scan_tbl) then
        return nil
    end

    return scan_tbl
end

---File statistics
---@param opts {buf: number?, silent: boolean?}?
---@return table statistics
function M.statistics(opts)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local silent = opts.silent ~= false
    local bytes = 0
    local chars = 0
    local words = 0
    local lines = 0
    local ils = 0
    local wls = 0
    local rls = 0
    local headings = 0

    local fn_wordcount
    vim.api.nvim_buf_call(buf, function()
        fn_wordcount = vim.fn.wordcount()
    end)
    local last_lnum = vim.fn.line('$')
    local mdn_patterns = require('mdnotes.patterns')

    bytes = fn_wordcount.bytes
    chars = fn_wordcount.chars
    words = fn_wordcount.words
    lines = last_lnum

    local ils_ret = M.scan_lines(mdn_patterns.inline_link, { location = { startl = 1, endl = last_lnum, buf = buf } }) or {}
    for _, ret in pairs(ils_ret or {}) do
        if ret.cols ~= nil then
            ils = ils + #ret.cols
        end
    end

    local wls_ret = M.scan_lines(mdn_patterns.wikilink, { location = { startl = 1, endl = last_lnum, buf = buf } }) or {}
    for _, ret in pairs(wls_ret) do
        if ret.cols ~= nil then
            wls = wls + #ret.cols
        end
    end

    local rls_ret = M.scan_lines(mdn_patterns.reference_link, { location = { startl = 1, endl = last_lnum, buf = buf } }) or {}
    for _, ret in pairs(rls_ret) do
        if ret.cols ~= nil then
            rls = rls + #ret.cols
        end
    end

    headings = #M.get_buf_fragments(buf)

    -- NOTE: Tried to print "formatted words" but because URLs might contain
    -- `_word_` then `word` is matched in scan_lines

    if silent ~= false then
        vim.notify(("Bytes:\t\t%s\n" ..
        "Characters:\t%s\n" ..
        "Words:\t\t%s\n" ..
        "Lines:\t\t%s\n" ..
        "Inline links:\t%s\n" ..
        "WikiLinks:\t%s\n" ..
        "Reference links:%s\n" ..
        "Headings:\t%s\n")
        :format(bytes, chars, words, lines, ils, wls, rls, headings)
        , vim.log.levels.INFO)
    end

    return {
        bytes = bytes,
        chars = chars,
        words = words,
        lines = lines,
        ils = ils,
        wls = wls,
        rls = rls,
        headings = headings,
    }
end

---Check if destination is a URL
---@param destination string
---@return boolean is_url
function M.is_url(destination)
    vim.validate("destination", destination, "string")

    if vim.tbl_contains({"http", "https"}, destination:match("%w+")) then
        return true
    else
        return false
    end
end

---Check and get path from the destination
---@param destination string destination to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string path, integer? error, string? error_text
function M.get_path_from_destination(destination, check_valid, opts)
    local path = ""
    if M.is_url(destination) == true then return path, -1, "is URL" end

    opts = opts or {} -- unused

    vim.validate("destination", destination, "string")
    vim.validate("check_valid", check_valid, "boolean")

    local cwd =require('mdnotes').cwd
    path = destination:match(require("mdnotes.patterns").dest_no_fragment) or ""

    if check_valid == true then
        if path ~= "" then

            -- Check if absolute path first
            if uv.fs_stat(path) then
                return vim.fs.abspath(path), nil
            end

            path = vim.fs.joinpath(cwd, path)

            -- If a Markdown file exists then it is a Markdown file
            -- GitHub does not like it when there is no .md in the inline link
            if uv.fs_stat(path .. ".md") then
                path = path .. ".md"
            end

            -- If the path is still not found, check if it's a URL
            if not uv.fs_stat(path) then
                return path, -2, "file not found"
            end
        else
            -- Handle [link](#fragment)
            path = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        end
    end

    return vim.fs.normalize(path), nil
end

---Check and get fragment from the destination
---@param destination string destination to check
---@param check_valid boolean Whether to check if the path is to a valid file or not
---@param opts table?
---@return string? fragment, integer? error, string? error_text
function M.get_fragment_from_destination(destination, check_valid, opts)
    local fragment = ""
    if M.is_url(destination) == true then return fragment, -1, "is URL" end

    opts = opts or {} -- unused

    vim.validate("destination", destination, "string")
    vim.validate("check_valid", check_valid, "boolean")

    fragment = destination:match(require("mdnotes.patterns").fragment) or ""

    if check_valid == true then
        if fragment ~= "" then

            -- Need path to open file to parse sections
            local path, err = M.get_path_from_destination(destination, true)
            if err ~= nil then
                return fragment, -2, "invalid path: " .. path .. ", " .. err
            end

            local buf
            if path ~= "" then
                buf = vim.fn.bufadd(path)
                vim.fn.bufload(buf)
            else
                -- path == "" on scratch buffers
                buf = vim.api.nvim_get_current_buf()
            end

            require('mdnotes').populate_buf_fragments(buf)

            local new_fragment = require('mdnotes').find_fragment_in_buf_fragments(buf, fragment)
            if new_fragment == nil then
                return fragment, -3, "fragment not parsed"
            end

            local search_ret = 0
            vim.api.nvim_buf_call(buf, function()
                search_ret = vim.fn.search("# " .. new_fragment)
            end)

            if search_ret == 0 then
                return fragment, -4, "invalid fragment: ".. new_fragment
            end

            fragment = new_fragment
        end
    end

    return fragment, nil
end

---Open destination in the appropriate programme
---@param destination string?
---@return integer|vim.SystemObj|string?
function M.open(destination)
    if destination == nil then return "destination error" end

    local path, perror = M.get_path_from_destination(destination, true)
    if perror ~= nil and perror ~= -1 then
        vim.notify("Mdn: Error getting path from destination: " .. path .. ", " .. perror, vim.log.levels.ERROR)
        return path .. ", " .. perror
    end

    local fragment, ferror = M.get_fragment_from_destination(destination, true)
    if ferror ~= nil and ferror ~= -1 then
        vim.notify("Mdn: Error getting fragment from destination: " .. fragment .. ", " .. ferror .. ". Ensure you have the correct fragment with ':Mdn miscellaneous view_fragments'", vim.log.levels.ERROR)
        return fragment .. ", " .. ferror
    end

    -- Check if the file exists and is a Markdown file
    if path ~= "" and uv.fs_stat(path) and vim.endswith(path, ".md") then
        M.open_buf(path)
        if fragment ~= "" then
            -- Navigate to fragment
            vim.fn.cursor(vim.fn.search("# " .. fragment), 1)
            vim.api.nvim_input('zz')
        end

        return vim.api.nvim_get_current_buf()
    end

    return vim.ui.open(destination)
end

---Pretty print buf_fragments
function M.view_fragments()
    local fragments = {}
    for _, v in pairs(M.buf_fragments) do
        if v.buf == vim.api.nvim_get_current_buf() then
            fragments = v.fragments
            break
        end
    end

    local text = "\t-Heading- | -GFM Style-\n"
    for i, v in pairs(fragments) do
        text = text .. i .. "\t" .. v.text .. " | #" .. v.gfm .. "\n"
    end

    vim.print(text)
end

---Parse the pattern in the specified lines
---@param pattern string? Pattern to use
---@param opts {location: MdnMultiLineLocation?, silent: boolean?, get_func: fun(a): string?}?
---@return table<MdnReferenceLinkData>?
function M.parse_lines(pattern, parse_func, opts)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')
    local get_func = opts.get_func or function(a) return a end

    local scan_lines = require('mdnotes').scan_lines

    local scanned_lines = scan_lines(pattern, { location = {startl = startl, endl = endl, buf = buf }, silent = true})
    if scanned_lines == nil then return nil end

    local parsed_tbl = {}
    for _, item in ipairs(scanned_lines) do
        for _, cols in ipairs(item.cols) do
            local data = parse_func({ location = {buf = buf, lnum = item.lnum, col_start = cols[1], col_end = cols[2] }})
            table.insert(parsed_tbl, get_func(data))
        end
    end

    return parsed_tbl
end

return M
