---@module 'mdnotes'

local M = {}

local uv = vim.loop or vim.uv

---Supported inlinr Markdown element types
---@alias MdnSupportedInlineMEType
---| '"wikilink"'
---| '"inline_link"'
---| '"strong"'
---| '"emphasis"'
---| '"strikethrough"'
---| '"inline_code"'
---| '"autolink"'
---| '"reference_link"'
---| '"footnote_reference"'

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
---@field raw string? Raw text in the corresponding location

---@class MdnParseLinesOpts
---@field location MdnMultiLineLocation?
---@field str boolean? Return a string instead of an object
---@field no_duplicates boolean? Remove duplicate results
---@field location_only boolean? Do not parse and return only location data

---@type MdnConfig
M.config = {}

---@type string Open command for opening buffers
M.open_cmd = nil

---@type string Current working directory
M.cwd = ""

---@type string Plugin install directory
M.plugin_install_dir = nil

---@class MdnFragment
---@field hash string The '#' present in the heading
---@field text string Original fragment text from the file headings
---@field gfm string GFM style text of fragment
---@field lnum integer Line number of the heading

---@alias MdnBufFragments table<table<MdnFragment>>

---@type MdnBufFragments
M.buf_fragments = {}

---Store default function to check for picker override
M.default_ui_select = vim.ui.select

---Mdnotes Config Class
---@class MdnConfig
---@field index_file string? Index file name or path
---@field journal_file (string|fun(): string)? Journal file name or path
---@field assets_path (string|fun(): string)? Path to assets folder
---@field asset_insert_behaviour '"copy"'|'"move"'? Behaviour when inserting assets from clipboard
---@field asset_overwrite_behaviour '"overwrite"'|'"error"'? Behaviour when the asset being inserted already exists
---@field asset_delete_behaviour '"remove"'|'"garbage"'? Behaviour when the deleting an asset
---@field wikilink_delete_behaviour '"remove"'|'"garbage"'? Behaviour when the deleting a WikiLink
---@field open_behaviour '"buffer"'|'"tab"'|'"split"'|'"vsplit"'? Behaviour when opening buffers
---@field strong_format '"**"'|'"__"'? Strong format delimiter
---@field emphasis_format '"*"'|'"_"'? Emphasis format delimiter
---@field date_format string? Date format when using journal_insert_entry(), see :h strftime()
---@field prefer_lsp boolean? To prefer Markdown LSP functions rather than the mdnotes functions
---@field auto_list_continuation boolean? Automatic list continuation
---@field default_keymaps boolean?
---@field autocmds boolean|MdnAutocmdsConfig?
---@field table_best_fit_padding integer? Add padding around cell contents when using tables_best_fit
---@field toc_depth integer? Depth shown in the ToC
---@field parser '"treesitter"'|'"patterns"'? Parse text using treesitter or patterns
---@field user_commands table? User commands in the Mdn namespace
local default_config = {
    index_file = "",
    journal_file = "",
    assets_path = "",
    asset_insert_behaviour = "copy",
    asset_overwrite_behaviour = "error",
    asset_delete_behaviour = "garbage",
    wikilink_delete_behaviour = "garbage",
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
    parser = "treesitter",
    user_commands = {}
}

---Mdnotes Config for autocmds
---@class MdnAutocmdsConfig
---@field set_cwd boolean set_cwd() autocmd for path resolution
---@field record_buf boolean record_buf() autocmd for buffer history
---@field populate_buf_fragments boolean populate_buf_fragments() autocmd for ToC fragments
---@field ordered_list_renumber boolean ordered_list_renumber() autocmd for ordered lists
---@field table_best_fit boolean best_fit() autocmd for tables
---@field outliner_state_notification boolean autocmd for Outliner mode state notification
---@field journal_insert_entry boolean autocmd for inserting a journal entry on opening the journal file
---@field populate_buf_reference_links boolean populate_buf_reference_links() autocmd reference links
---@field populate_buf_footnotes boolean populate_buf_footnotes() autocmd footnotes
local default_autocmd_config = {
    set_cwd = true,
    record_buf = true,
    populate_buf_fragments = true,
    ordered_list_renumber = true,
    table_best_fit = true,
    outliner_state_notification = true,
    journal_insert_entry = true,
    populate_buf_reference_links = true,
    populate_buf_footnotes = true
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
    vim.validate("wikilink_delete_behaviour", config.wikilink_delete_behaviour, "string", false, "'remove' or 'garbage'")
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
    vim.validate("parser", config.parser, "string", false, "'patterns' or 'treesitter'")

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
    if M.config.autocmds.populate_buf_footnotes == false then
        vim.api.nvim_del_augroup_by_name('mdn.pop_fn')
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

local function set_g()
    _G.Mdn = M
    _G.Mdn.assets = require('mdnotes.assets')
    _G.Mdn.footnote = require('mdnotes.footnote')
    _G.Mdn.formatting = require('mdnotes.formatting')
    _G.Mdn.heading = require('mdnotes.heading')
    _G.Mdn.history = require('mdnotes.history')
    _G.Mdn.inline_link = require('mdnotes.inline_link')
    _G.Mdn.journal = require('mdnotes.journal')
    _G.Mdn.list = require('mdnotes.list')
    _G.Mdn.outliner = require('mdnotes.outliner')
    _G.Mdn.patterns = require('mdnotes.patterns')
    _G.Mdn.reference_link = require('mdnotes.reference_link')
    _G.Mdn.table = require('mdnotes.table')
    _G.Mdn.toc = require('mdnotes.toc')
    _G.Mdn.wikilink = require('mdnotes.wikilink')
    _G.Mdn.demo = require('mdnotes.demo')
end

local function ts_parser_check()
    local parsers_found = false
    if vim.treesitter.language.add('markdown')
        and vim.treesitter.language.add('markdown_inline') then
        parsers_found = true
    end

    if M.config.parser == "treesitter" and parsers_found == false then
        M.config.parser = "patterns"
    end
end

---Setup function
---@param user_config MdnConfig
function M.setup(user_config)
    M.config = validate_config(user_config)
    M.config.index_file = vim.fs.normalize(M.config.index_file)

    -- Load autocmds
    require('mdnotes.autocmds')

    resolve_open_cmd()
    resolve_autocmd_config()
    set_g()
    ts_parser_check()

    -- Load commands
    require('mdnotes.commands')

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

---Get the garbage directory
function M.get_garbage_dir()
    local garbage_path = vim.fs.normalize(vim.fs.joinpath(M.cwd, "garbage"))

    -- Create directory if it does not exist
    if vim.fn.isdirectory(garbage_path) == 0 then
        uv.fs_mkdir(garbage_path, tonumber('777', 8))
    end

    return garbage_path
end

---Open the buffer using the cwd
---@param buf integer|string
---@param opts {hor: boolean?, vert: boolean?}?
function M.open_buf(buf, opts)
    vim.validate("buf", buf, {"number", "string"})
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local hor = opts.hor or false
    local vert = opts.vert or false
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
        edit_cmd = open_cmd .. buf
    end

    vim.cmd(edit_cmd)
end

---Resolving any required internal :grep calls
---@param pattern string grep pattern
---@param path string File path
function M.mdn_grep(pattern, path)
    vim.validate("pattern", pattern, "string")
    vim.validate("path", path, "string")

    if vim.o.grepprg == "internal" then
        pattern = pattern:gsub("<", "\\<")
        pattern = pattern:gsub("/", "\\/")
        pattern = "/\\v" .. pattern .. "/"
        path = vim.fs.joinpath(vim.fs.normalize(path), "*")
    else
        pattern = '"' .. pattern .. '"'
    end

    vim.cmd.grep({args = {pattern, path}, mods = {emsg_silent = true}})

    if vim.o.grepprg == "internal" then
        -- do nothing
    else
        -- Remove subdirectories from results
        -- Replicates appending * to cwd
        local qflist = vim.fn.getqflist()
        local new_qflist = {}
        for _, v in ipairs(qflist) do
            local bufname = vim.api.nvim_buf_get_name(v.bufnr)
            local dirname = vim.fs.dirname(bufname)
            if dirname == path then
                table.insert(new_qflist, v)
            end
        end

        vim.fn.setqflist(new_qflist)
    end

end

---Check text for valid inline Markdown syntax
---@param imetype MdnSupportedInlineMEType Inline markdown element type
---@param opts {location: MdnInLineLocation?, entire_line: boolean?}?
---@return boolean valid, table<table?> cols_tbl
function M.check_inline_markdown_syntax(imetype, opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        local pattern = require('mdnotes.patterns')[imetype]
        return M.check_inline_markdown_syntax_re(pattern, opts)
    elseif parser == "treesitter" then
        return M.check_inline_markdown_syntax_ts(imetype, opts)
    end

    return false, {}
end

---Check text for valid inline Markdown syntax using Lua patterns
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnInLineLocation?, entire_line: boolean?}?
---@return boolean valid, table<table?> pos_tbl
function M.check_inline_markdown_syntax_re(pattern, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local entire_line = opts.entire_line or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')
    local col_end = locopts.col_end or vim.fn.col('.')
    local cur_col = locopts.cur_col or math.floor((col_start + col_end)/2)

    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    local position_tbl = {}

    for start_pos, text, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        local pos_tbl = {col_start = start_pos, col_end = end_pos, lnum = lnum}
        if entire_line == false then
            if start_pos <= cur_col and end_pos > cur_col then
                return true, pos_tbl
            end
        else
            table.insert(position_tbl, pos_tbl)
        end
    end

    if vim.tbl_isempty(position_tbl) then
        return false, {}
    end

    return true, position_tbl
end

---Check text for valid inline Markdown syntax using treesitter
---@param imetype MdnSupportedInlineMEType Inline markdown element type
---@param opts {location: MdnInLineLocation?, entire_line: boolean?}?
---@return boolean valid, table<table?> cols_tbl
function M.check_inline_markdown_syntax_ts(imetype, opts)
    vim.validate("imetype", imetype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local process_node = require('mdnotes.treesitter')[imetype]
    if process_node == nil then
        return false, {}
    end

    local entire_line = opts.entire_line or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')

    local node
    if entire_line == false then
        node = vim.treesitter.get_node({
            bufnr = buf,
            ignore_injections = false,
            pos = {lnum - 1, col_start - 1}
        })

        if node == nil then
            return false, {}
        end

        local pos_tbl = process_node(node:parent(), buf, "inline")

        -- Try again with not the parent node
        if pos_tbl == nil then
            pos_tbl = process_node(node, buf, "inline")
        end

        if pos_tbl == nil then
            return false, {}
        end

        return true, pos_tbl
    else
        node = vim.treesitter.get_node({
            bufnr = buf,
            ignore_injections = false,
            pos = {lnum - 1, 0}
        })

        if node == nil then
            return false, {}
        end

        -- Ensure we are not at an injection
        while node:type() ~= "inline" do
            node = node:parent()
            if node == nil then
                return false, {}
            end
        end

        local cols_tbl = {}
        local function get_node_data_tbl(_node)
            local pos_tbl = process_node(_node, buf, "inline") or {}
            if pos_tbl.lnum == lnum then
                table.insert(cols_tbl, pos_tbl)
            end
            for child in _node:iter_children() do
                get_node_data_tbl(child)
            end
        end

        for child in node:iter_children() do
            get_node_data_tbl(child)
        end

        if vim.tbl_isempty(cols_tbl) then
            return false, {}
        end

        return true, cols_tbl
    end
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
    vim.validate("opts", opts, "table", true)

    opts = opts or {}
    local locopts = opts.location or {}

    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.getpos("'<")[3]
    local col_end = locopts.col_end or vim.fn.getpos("'>")[3]
    local cur_col = locopts.cur_col or vim.fn.col('.')

    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]

    -- Case where linewise-visual was used prior to get_text()
    -- If visual was used then the number would be reset
    if col_end == 2147483647 then
        col_end = col_start
    end

    -- Limit the end column value
    -- Visual mode and grep can give end_col values after the line ending
    if col_end > #line then
        col_end = #line
    end

    -- Raw text
    local raw = line:sub(col_start, col_end)

    -- This would happen by default when executing in Normal mode
    if col_start == col_end then
        vim.api.nvim_buf_call(buf, function()
            -- Ensure cursor is at the correct spot
            vim.fn.cursor(lnum, cur_col)

            -- Get the word under cursor and cursor position
            raw = vim.fn.expand("<cWORD>")
        end)

        -- Search for the word in the line and check if it's under the cursor
        for i = 1, #line do
            local start_pos, end_pos = line:find(raw, i, true)
            if start_pos and end_pos then
                if start_pos <= cur_col and end_pos >= cur_col then
                    col_start = start_pos
                    col_end = end_pos
                    break
                end
            end
        end
    end

    -- Reset markers to starting values
    vim.fn.setpos("'<", {0,0,0,0})
    vim.fn.setpos("'>", {0,0,0,0})

    -- Case where get_text() was called on a space character
    -- while in Normal mode and no prior Visual mode selection occured
    if col_start == 0 and col_end == 0 then
        return {
            buf = buf,
            lnum = lnum,
            col_start = col_start,
            col_end = col_end,
            cur_col = cur_col,
            raw = nil,
        }
    end

    return {
        buf = buf,
        lnum = lnum,
        col_start = col_start,
        col_end = col_end,
        cur_col = cur_col,
        raw = raw,
    }
end

---Get the text inside a pattern as well as the start and end columns
---Can use opts.location to specify location of search
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnInLineLocation?}?
---@return MdnText
function M.get_text_in_pattern(pattern, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')
    local col_end = locopts.col_end or vim.fn.col('.')
    local cur_col = locopts.cur_col or math.floor((col_start + col_end) / 2)

    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]

    local found_raw_text = ""
    for start_pos, search_text, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if start_pos <= cur_col and end_pos > cur_col then
            found_raw_text = search_text
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
        raw = found_raw_text,
    }
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
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local files = {}

    local function remove(name)
        if vim.tbl_contains(files, name) then
            for i, v in ipairs(files) do
                if v == name then
                    table.remove(files, i)
                    break
                end
            end
        end
    end

    local hidden = opts.hidden or false

    for name, type in vim.fs.dir(M.cwd) do
        table.insert(files, name)

        if opts.extension ~= nil then
            if name:match("^.*(%..*)") == opts.extension or opts.extension == ".*" then
                -- continue iteration
            else
                remove(name)
            end
        end

        -- Remove hidden by default
        if name:sub(1,1) == "." then
            if hidden == true then
                -- continue iteration
            else
                remove(name)
            end
        end

        if opts.fs_type ~= nil then
            if type == opts.fs_type or type == "all" then
                -- continue iteration
            else
                remove(name)
            end
        end

        if opts.pattern ~= nil then
            if name:match(opts.pattern) then
                -- continue iteration
            else
                remove(name)
            end
        end
    end

    return files
end

---Convert the inputted text to GFM-style text based on 
---https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links
---@param text string Text for conver
---@return string
function M.convert_text_to_gfm(text)
    vim.validate("text", text, "string")

    -- Lowercase
    text =text:lower()

    -- Trim start and end whitespace
    text = vim.trim(text)

    -- Remove any non-alphanumeric
    -- characters but keep spaces, dashes
    text = text:gsub("[^%w -]+", "")

    -- Replaces spaces with dashes
    text = text:gsub(" ", "-")

    return text
end

---Parse the fragments in the specified buffer and update buf_fragments
---@param buf integer? Buffer number to parse the fragments
function M.populate_buf_fragments(buf)
    vim.validate("buf", buf, "number", true)
    buf = buf or vim.api.nvim_get_current_buf()

    local fragments_tbl = M.get_buf_fragments({buf = buf})
    if M.buf_fragments[buf] ~= fragments_tbl then
        M.buf_fragments[buf] = fragments_tbl
    end
end

---Get fragments from the Markdown buffer headings
---@param opts {buf: integer?, only_text: boolean?}?
---@return table<MdnFragment|string>?
function M.get_buf_fragments(opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.get_buf_fragments_re(opts)
    elseif parser == "treesitter" then
        return M.get_buf_fragments_ts(opts)
    end
end

---Get fragments from the Markdown buffer headings using Lua patterns
---@param opts {buf: integer?, only_text: boolean?}?
---@return table<MdnFragment|string>
function M.get_buf_fragments_re(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local only_text = opts.only_text or false

    local fragments = {}
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local heading_format_pattern = require('mdnotes.patterns').heading

    for lnum, line in ipairs(buf_lines) do
        local hash, text = line:match(heading_format_pattern)
        if text and hash then
            if only_text == false then
                table.insert(fragments, {hash = hash, text = text, gfm = M.convert_text_to_gfm(text), lnum = lnum})
            else
                table.insert(fragments, text)
            end
        end
    end

    return fragments
end

---Get fragments from the Markdown buffer headings using treesitter
---@param opts {buf: integer?, only_text: boolean?}?
---@return table<MdnFragment|string>
function M.get_buf_fragments_ts(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local only_text = opts.only_text or false

    local parser, err = vim.treesitter.get_parser(buf, "markdown")
    if parser == nil or err ~= nil then
        vim.notify("Mdn: Error with treesitter 'markdown' parser: " .. err, vim.log.levels.ERROR)
        return {}
    end

    local fragments = {}
    local process_node_func = require('mdnotes.treesitter')["fragments"]
    local function get_node_data_tbl(node)
        local processed_node = process_node_func(node, buf)
        if processed_node ~= nil then
            if only_text == false then
                processed_node.buf = nil -- gets added by the process_node() function in treesitter.lua
                processed_node.cur_col = nil
                table.insert(fragments, processed_node)
            else
                table.insert(fragments, processed_node.hash .. " " .. processed_node.text)
            end
        end

        for child in node:iter_children() do
            get_node_data_tbl(child)
        end
    end

    local tree = parser:parse()[1]
    local node = tree:root()

    get_node_data_tbl(node)

    if fragments == nil then
        return {}
    end

    return fragments
end

---Find the fragment in the buf_fragments table of the specified buffer
---@param buf integer Buffer number
---@param fragment string Fragment
---@return string?
function M.find_fragment_in_buf_fragments(buf, fragment)
    vim.validate("buf", buf, "number")
    vim.validate("fragment", fragment, "string")

    local fragments = M.buf_fragments[buf]
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
    vim.validate("bufname", bufname, "string")

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

---File statistics
---@param opts {buf: number?, silent: boolean?}?
---@return table statistics
function M.statistics(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local silent = opts.silent or false

    vim.validate("buf", buf, "number")
    vim.validate("silent", silent, "boolean")

    local bytes = 0
    local chars = 0
    local words = 0
    local lines = 0
    local ils = 0
    local wls = 0
    local rls = 0
    local frefs = 0
    local headings = 0

    local fn_wordcount
    vim.api.nvim_buf_call(buf, function()
        fn_wordcount = vim.fn.wordcount()
    end)
    local last_lnum = vim.fn.line('$')

    bytes = fn_wordcount.bytes
    chars = fn_wordcount.chars
    words = fn_wordcount.words
    lines = last_lnum

    local func = function() end
    local patterns = require('mdnotes.patterns')
    ils = ils + #(M.parse_lines_re(patterns.inline_link, func, { location = { startl = 1, endl = last_lnum, buf = buf }, location_only = true}) or {})
    wls = wls + #(M.parse_lines_re(patterns.wikilink, func, { location = { startl = 1, endl = last_lnum, buf = buf }, location_only = true }) or {})
    rls = rls + #(M.parse_lines_re(patterns.reference_link, func, { location = { startl = 1, endl = last_lnum, buf = buf }, location_only = true }) or {})
    frefs = frefs + #(M.parse_lines_re(patterns.footnote_reference, func, { location = { startl = 1, endl = last_lnum, buf = buf }, location_only = true }) or {})
    headings = #M.get_buf_fragments({ buf = buf })

    -- NOTE: Tried to print "formatted words" but because URLs might contain
    -- `_word_` then `word` is matched in parse_lines

    if silent == false then
        vim.notify(("Bytes:\t\t%s\n" ..
        "Characters:\t%s\n" ..
        "Words:\t\t%s\n" ..
        "Lines:\t\t%s\n" ..
        "Inline links:\t%s\n" ..
        "WikiLinks:\t%s\n" ..
        "Ref. links:\t%s\n" ..
        "Footnote ref.:\t%s\n" ..
        "Headings:\t%s\n")
        :format(bytes, chars, words, lines, ils, wls, rls, frefs, headings)
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
        frefs = frefs,
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
    vim.validate("destination", destination, "string")
    vim.validate("check_valid", check_valid, "boolean")
    vim.validate("opts", opts, "table", true)

    local path = ""
    if M.is_url(destination) == true then return path, -1, "is URL" end

    opts = opts or {} -- unused

    path = destination:match(require("mdnotes.patterns").dest_no_fragment) or ""

    if check_valid == true then
        if path ~= "" then

            -- Check if absolute path first
            if uv.fs_stat(path) then
                return vim.fs.abspath(path), nil
            end

            path = vim.fs.joinpath(M.cwd, path)

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
    vim.validate("destination", destination, "string")
    vim.validate("check_valid", check_valid, "boolean")
    vim.validate("opts", opts, "table", true)

    local fragment = ""
    if M.is_url(destination) == true then return fragment, -1, "is URL" end

    opts = opts or {} -- unused

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

            M.populate_buf_fragments(buf)

            local new_fragment = M.find_fragment_in_buf_fragments(buf, fragment)
            if new_fragment == nil then
                return fragment, -3, "fragment not parsed"
            end

            local cur_pos = vim.fn.getpos(".")
            local search_ret = 0
            vim.api.nvim_buf_call(buf, function()
                search_ret = vim.fn.search("# " .. new_fragment)
            end)
            vim.fn.setpos(".", cur_pos)

            if search_ret == 0 then
                return fragment, -4, "invalid fragment: ".. new_fragment
            end

            fragment = new_fragment
        end
    end

    return fragment, nil
end

---Open destination in the appropriate programme
---@param destination string
---@return integer|vim.SystemObj|string?
function M.open(destination)
    vim.validate("destination", destination, "string")

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
    elseif path == "" then -- this would happen in scratch buffers
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
    local buf = vim.api.nvim_get_current_buf()
    local fragments = M.buf_fragments[buf]

    local text = "\t-Heading- | -GFM Style-\n"
    for i, v in pairs(fragments) do
        text = text .. i .. "\t" .. v.text .. " | #" .. v.gfm .. "\n"
    end

    vim.print(text)
end

local function is_parsed_tbl_duplicate(parsed_tbl, data)
    if data == nil then return false end
    if vim.tbl_contains(parsed_tbl, data) then
        return true
    end

    for _, v in ipairs(parsed_tbl) do
        if v.raw == data.raw then
            return true
        end
    end

    return false
end

---@class MdnParseLinesInitOpts: MdnParseLinesOpts
---@field process_func (fun(obj): any)?

---Parse the Markdown elements in the specified lines with Lua patterns
---@param pattern MdnPattern
---@param parse_func fun(...): table? Parse function
---@param opts MdnParseLinesInitOpts
---@return table?
function M.parse_lines_re(pattern, parse_func, opts)
    vim.validate("pattern", pattern, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local no_duplicates = opts.no_duplicates or false
    local location_only = opts.location_only or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')
    local process_func = opts.process_func or function(obj) return obj end

    local scan_tbl = {}
    for lnum = startl, endl do
        local valid, pos_tbl = M.check_inline_markdown_syntax_re(pattern, {entire_line = true, location = {lnum = lnum, buf = buf}})
        if valid == true then
            table.insert(scan_tbl, pos_tbl)
        end
    end
    scan_tbl = vim.iter(scan_tbl):flatten():totable() ---@diagnostic disable-line

    if vim.tbl_isempty(scan_tbl) then
        return nil
    end

    if location_only == true then
        return scan_tbl
    end

    local parsed_tbl = {}
    for _, v in ipairs(scan_tbl) do
        local data = parse_func({ location = {buf = buf, lnum = v.lnum, col_start = v.col_start, col_end = v.col_end }})
        data = process_func(data)
        if no_duplicates == true then
            if is_parsed_tbl_duplicate(parsed_tbl, data) == false then
                table.insert(parsed_tbl, data)
            end
        else
            table.insert(parsed_tbl, data)
        end
    end

    return parsed_tbl
end

---Parse the Markdown elements in the specified lines with treesitter
---@param tstype MdnTSNodeType Markdown node type
---@param opts MdnParseLinesInitOpts
---@return table?
function M.parse_lines_ts(tstype, opts)
    vim.validate("tstype", tstype, "string")
    vim.validate("opts", opts, "table", true)

    opts = opts or {}

    local no_duplicates = opts.no_duplicates or false
    local location_only = opts.location_only or false
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local startl = locopts.startl or vim.fn.line('.')
    local endl = locopts.endl or vim.fn.line('.')
    local get_func = opts.process_func or function(a) return a end

    local parser, err = vim.treesitter.get_parser(buf, "markdown_inline")
    if parser == nil or err ~= nil then
        vim.notify("Mdn: Error with treesitter 'markdown_inline' parser: " .. err, vim.log.levels.INFO)
        return
    end

    local location
    if location_only == true then
        location = "inline"
    end

    local node_data = {}
    local process_node_func = require('mdnotes.treesitter')[tstype]
    local function get_node_data_tbl(node)
        local processed_node = process_node_func(node, buf, location) or {lnum = 0}
        if processed_node.lnum >= startl and processed_node.lnum <= endl then
            local _processed_node = get_func(processed_node)
            if no_duplicates == true then
                if is_parsed_tbl_duplicate(node_data, _processed_node) == false then
                    table.insert(node_data, _processed_node)
                end
            else
                table.insert(node_data, _processed_node)
            end
        end
        for child in node:iter_children() do
            get_node_data_tbl(child)
        end
    end

    local tree = parser:parse()[1]
    local node = tree:root()

    get_node_data_tbl(node)

    if node_data == nil then
        return nil
    end

    return node_data
end

---@param items table Items to show
---@param on_end fun(sel_obj): any Callback function for when the coroutine finishes
---@param ui_opts vim.ui.select.Opts
function M.mdn_picker(items, on_end, ui_opts)
    vim.validate("items", items, "table")
    vim.validate("on_end", on_end, "function")
    vim.validate("ui_opts", ui_opts, "table")

    -- If it is overriden, it is assumed to be non-blocking
    if M.default_ui_select == vim.ui.select then
        local index = nil
        vim.ui.select(items, ui_opts, function (_, idx)
            index = idx
        end)

        if index == nil then
            return
        end

        return items[index]
    else
        coroutine.wrap(function()
            local co = coroutine.running()
            vim.ui.select(items, ui_opts, function (_, idx)
                coroutine.resume(co, idx)
            end)

            on_end(items[coroutine.yield()])
        end)()

        return
    end
end

return M
