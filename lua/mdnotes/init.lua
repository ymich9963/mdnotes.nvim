---@module 'mdnotes'

local M = {}

---@class MdnInLineLocation
---@field buffer integer? Buffer number
---@field lnum integer? Line number
---@field col_start integer? Start column of text
---@field col_end integer? End column of text
---@field cur_col integer? Set the current cursor position on the line

---@class MdnMultiLineLocation
---@field buffer integer? Buffer number
---@field startl integer? Start line
---@field endl integer? End line

---@class MdnSearchOpts
---@field buffer integer?
---@field origin_lnum integer? Line number between the lower and upper limits
---@field lower_limit_lnum integer? Lower line number limit of search
---@field upper_limit_lnum integer? Higher line number limit of search

---@class MdnSearchResult
---@field valid boolean Is the search item valid
---@field buffer integer? Buffer number
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
---@field lnum integer Line number of the heading

---@class MdnFragments
---@field fragment table<MdnFragment>

---@alias MdnFragmentsGfm table<string> Parsed GFM-style fragment text

---@class MdnBufFragments
---@field buf_num integer Buffer number
---@field parsed table<MdnFragments, MdnFragmentsGfm> 

---@type table<table<MdnBufFragments>>
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
---@field strong_format '"**"'|'"__"'? Strong format indicator
---@field emphasis_format '"*"'|'"_"'? Emphasis format indicator
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
local default_autocmd_config = {
    set_cwd = true,
    record_buf = true,
    populate_buf_fragments = true,
    ordered_list_renumber = true,
    table_best_fit = true,
    outliner_state_notification = true,
    journal_insert_entry = true
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
        vim.api.nvim_del_augroup_by_name('mdn.pop')
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
end

---Setup function
---@param user_config MdnConfig
function M.setup(user_config)
    M.config = validate_config(user_config)
    M.config.index_file = vim.fs.normalize(M.config.index_file)

    if M.config.open_behaviour == "buffer" then
        M.open_cmd = 'edit '
    elseif M.config.open_behaviour == "tab" then
        M.open_cmd = 'tabnew '
    elseif M.config.open_behaviour == "split" then
        M.open_cmd = 'split '
    elseif M.config.open_behaviour == "vsplit" then
        M.open_cmd = 'vsplit '
    end

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
function M.open_buf(buf)
    vim.validate("buf", buf, {"number", "string"})

    local edit_cmd = ""
    if type(buf) == "number" then
        edit_cmd = M.open_cmd .. buf
    elseif type(buf) == "string" then
        vim.cmd.cd({ args = {M.cwd}, mods = {silent = true}})
        edit_cmd = M.open_cmd .. buf
    end

    vim.cmd(edit_cmd)
end

---Check text for valid Markdown syntax
---@param pattern MdnPattern Pattern that returns the start and end columns, as well as the text
---@param opts {location: MdnInLineLocation?, entire_line: boolean?}?
---@return boolean? valid, number? start_col, number? end_col
function M.check_markdown_syntax(pattern, opts)
    opts = opts or {}
    vim.validate("pattern", pattern, "string")

    local entire_line = opts.entire_line or false
    local locopts = opts.location or {}
    local bufnum = locopts.buffer or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local cur_col = locopts.cur_col or vim.fn.col('.')

    local line = vim.api.nvim_buf_get_lines(bufnum, lnum - 1, lnum, false)[1]

    for start_pos, _, end_pos in line:gmatch(pattern) do
        start_pos = vim.fn.str2nr(start_pos)
        end_pos = vim.fn.str2nr(end_pos)
        if (start_pos <= cur_col and end_pos > cur_col) or entire_line == true then
            return true, start_pos, end_pos
        end
    end

    return false, -1, -1
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

    local bufnum = locopts.buffer or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.getpos("'<")[3]
    local col_end = locopts.col_end or vim.fn.getpos("'>")[3]
    local cur_col = locopts.cur_col or vim.fn.col('.')

    local line = vim.api.nvim_buf_get_lines(bufnum, lnum - 1, lnum, false)[1]
    local text = line:sub(col_start, col_end)

    -- This would happen by default when executing in Normal mode
    if col_start == col_end then
        vim.api.nvim_buf_call(bufnum, function()
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
        buffer = bufnum,
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
    local bufnum = locopts.buffer or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or -1
    local col_end = locopts.col_end or -1
    local cur_col = locopts.cur_col or math.floor((col_start + col_end) / 2)

    if cur_col == -1 then
        cur_col = vim.fn.col('.')
    end

    local line = vim.api.nvim_buf_get_lines(bufnum, lnum - 1, lnum, false)[1]

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
        buffer = bufnum,
        lnum = lnum,
        col_start = col_start,
        col_end = col_end,
        cur_col = cur_col,
        text = found_text,
    }
end

---Get the list item's indent level and indicator. Also increment when using ordered lists
---@param inc_val integer Value to increment the list item by
---@return string indent, string list_indicator Indent of the list item and the corresponding list indicator
local function get_indent_indicator(inc_val)
    local mdnotes_patterns = require('mdnotes.patterns')
    local line = vim.api.nvim_get_current_line()
    local lcontent = require('mdnotes.formatting').resolve_list_content(line)

    local type = "unordered"
    if lcontent.separator ~= "" then
        type = "ordered"
    end

    local check_text = lcontent.text:gsub(mdnotes_patterns.task, ""):gsub("[%s]", "")

    if check_text and check_text ~= "" then
        if type == "unordered" then
            if lcontent.text:match(mdnotes_patterns.task) then
                return lcontent.indent, "\n" .. lcontent.marker .. " " .. "[ ] "
            else
                return lcontent.indent, "\n" .. lcontent.marker .. " "
            end
        end

        if type == "ordered" then
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
---@param bufnr integer? Buffer number to parse the fragments
function M.populate_buf_fragments(bufnr)
    if bufnr == nil then bufnr = vim.api.nvim_get_current_buf() end

    local fragments = M.get_fragments_from_buf_headings(bufnr)
    local buf_exists = false
    for _,v in ipairs(M.buf_fragments) do
        if v.buf_num == bufnr then
            buf_exists = true
            -- Check if the fragments have changed
            if v.parsed.fragments ~= fragments then
                v.parsed.fragments = fragments
                v.parsed.gfm = M.convert_fragments_to_gfm_style(fragments)
            end
            break
        end
    end

    local entry = {
        buf_num = bufnr,
        parsed = {
            fragments = fragments,
            gfm = M.convert_fragments_to_gfm_style(fragments)
        }
    }

    if buf_exists == false then
        table.insert(M.buf_fragments, entry)
    end

    return entry
end

---Get fragments from the Markdown buffer headings
---@param bufnr integer?
---@return MdnFragments
function M.get_fragments_from_buf_headings(bufnr)
    if bufnr == nil then bufnr = 0 end
    local fragments = {}
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local heading_format_pattern = require('mdnotes.patterns').heading

    for lnum, line in ipairs(buf_lines) do
        local hash, text = line:match(heading_format_pattern)
        if text and hash then
            table.insert(fragments, {hash = hash, text = text, lnum = lnum})
        end
    end

    return fragments
end

---Convert MdnFragment table entries to GFM style and return as table
---@param fragments MdnFragments
---@return MdnFragmentsGfm
function M.convert_fragments_to_gfm_style(fragments)
    local gfm_fragments = {}
    for _, fragment in ipairs(fragments) do
        table.insert(gfm_fragments, M.convert_text_to_gfm(fragment.text))
    end

    return gfm_fragments
end

---Find the fragment in the buf_fragments table of the specified buffer
---@param bufnr integer Buffer number
---@param fragment string GFM-style fragment
---@return string?
function M.find_fragment_in_buf_fragments(bufnr, fragment)
    local parsed_fragments
    for _, v in ipairs(M.buf_fragments) do
        if v.buf_num == bufnr then
            parsed_fragments = v.parsed
            break
        end
    end

    if parsed_fragments == nil then return nil end

    local text

    -- Check if it is a GFM style fragment
    for i, v in ipairs(parsed_fragments.gfm) do
        if v == fragment then
            text = parsed_fragments.fragments[i].text
            break
        end
    end

    -- Check if it is an as-is fragment
    for _, v in ipairs(parsed_fragments.fragments) do
        if v.text == fragment then
            text = v.text
            break
        end
    end

    return text
end

---Get the buffer number from the buffer list using the buffer name 
---@param bufname string Buffer name
function M.get_buf_from_buf_list(bufname)
    local buf_list = vim.api.nvim_list_bufs()
    local ret = nil

    for _, bufnum in ipairs(buf_list) do
        local filename = vim.fs.basename(vim.api.nvim_buf_get_name(bufnum))
        if filename == bufname then
            ret = bufnum
            break
        end
    end

    return ret
end

return M
