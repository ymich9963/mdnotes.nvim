---@module 'mdnotes'

local M = {}

---@type MdnConfig
M.config = {}

---@type string|nil Open command for opening buffers
M.open_cmd = nil

---@type string|nil Current working directory
M.cwd = nil

---@type string|nil Plugin install directory
M.plugin_install_dir = nil

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

---Get the list item's indent level and indicator. Also increment when using ordered lists
---@param inc_val integer Value to increment the list item by
---@return string indent, string list_indicator Indent of the list item and the corresponding list indicator
local function get_indent_indicator(inc_val)
    local mdnotes_patterns = require('mdnotes.patterns')
    local line = vim.api.nvim_get_current_line()
    local indent, marker, separator, text = require('mdnotes.formatting').resolve_list_content(line)

    local type = "unordered"
    if separator ~= "" then
        type = "ordered"
    end

    local check_text = text:gsub(mdnotes_patterns.task, ""):gsub("[%s]", "")

    if check_text and check_text ~= "" then
        if type == "unordered" then
            if text:match(mdnotes_patterns.task) then
                return indent, "\n" .. marker .. " " .. "[ ] "
            else
                return indent, "\n" .. marker .. " "
            end
        end

        if type == "ordered" then
            if text:match(mdnotes_patterns.task) then
                return indent, "\n" .. tostring(tonumber(marker + inc_val)) .. separator .. " " .. "[ ] "
            else
                return indent, "\n" .. tostring(tonumber(marker + inc_val)) .. separator .. " "
            end
        end
    end

    return indent, "\n"
end

---New line remaps
---@param key '"o"'|'"O"'|'"<CR>"'
---@param expr_set boolean If remap is used when opts.expr is true
---@return string|nil
function M.new_line_remap(key, expr_set)
    vim.validate("key", key, "string")
    vim.validate("expr_set", expr_set, "boolean")

    local lnum = vim.fn.line('.')
    local indent, list_remap = "", ""

    if key == "o" or key == "<CR>" then
        indent, list_remap = get_indent_indicator(1)
    elseif key == "O" then
        indent, list_remap = get_indent_indicator(-1)
    end

    if expr_set == true then
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

---@class MdnGetFilesInCwd
---@field extension string? Specify extension e.g. ".md". Use ".*" for all file extensions
---@field hidden boolean? Get hidden files
---@field fs_type '"file"'|'"directory"'|'"link"'|'"fifo"'|'"socket"'|'"char"'|'"block"'|'"unknown"'|'"all"' Specify type from vim.fs.dir() return
---@field pattern string? Lua pattern for names containing pattern

---Get the files in the cwd
---@param opts MdnGetFilesInCwd?
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

return M
