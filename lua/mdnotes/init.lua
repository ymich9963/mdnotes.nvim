---@module 'mdnotes'
local M = {}

---@type MdnotesConfig
M.config = {}

---@type string|nil Open command for opening buffers
M.open_cmd = nil

---@type string|nil Current working directory
M.cwd = nil

---@type string|nil Plugin install directory
M.plugin_install_dir = nil

---Mdnotes Config Class
---@class MdnotesConfig
---@field index_file string? Index file name or path
---@field journal_file string? Journal file name or path
---@field assets_path string? Path to assets folder
---@field asset_insert_behaviour '"copy"'|'"move"'? Behaviour when inserting assets from clipboard
---@field asset_overwrite_behaviour '"overwrite"'|'"error"'? Behaviour when the asset being inserted already exists
---@field open_behaviour '"buffer"'|'"tab"'|'"split"'|'"vsplit"'? Behaviour when opening buffers
---@field strong_format '"**"'|'"__"'? Strong format indicator
---@field emphasis_format '"*"'|'"_"'? Emphasis format indicator
---@field date_format string? Date format when using insert_journal_entry(), see :h strftime()
---@field prefer_lsp boolean? To prefer Markdown LSP functions rather than the mdnotes functions
---@field auto_list boolean? Automatic list continuation
---@field auto_list_renumber boolean? Automatic renumbering of ordered lists
---@field auto_table_best_fit boolean? Automatic table best fit
---@field default_keymaps boolean?
---@field autocmds boolean?
---@field table_best_fit_padding integer? Add padding around cell contents when using tables_best_fit
---@field toc_depth integer? Depth shown in the ToC
local default_config = {
    index_file = "",
    journal_file = "",
    assets_path = "",
    asset_insert_behaviour = "copy",
    asset_overwrite_behaviour = "error",
    open_behaviour = "buffer",
    strong_format = "**",
    emphasis_format = "*",
    date_format = "%a %d %b %Y",
    prefer_lsp = false,
    auto_list = true,
    auto_list_renumber = true,
    auto_table_best_fit = true,
    default_keymaps = false,
    autocmds = true,
    table_best_fit_padding = 0,
    toc_depth = 4
}

---Validate user config
---@param user_config MdnotesConfig
---@return MdnotesConfig
local function validate_config(user_config)
    local config = vim.tbl_deep_extend("force", default_config, user_config or {})

    vim.validate("index_file", config.index_file, "string")
    vim.validate("journal_file", config.journal_file, "string")
    vim.validate("assets_path", config.assets_path, "string")
    vim.validate("asset_insert_behaviour", config.asset_insert_behaviour, "string", false, "'copy' or 'move'")
    vim.validate("asset_overwrite_behaviour", config.asset_overwrite_behaviour, "string", false, "'overwrite' or 'error'")
    vim.validate("open_behaviour", config.open_behaviour, "string", false, "'buffer', 'tab', 'split', or 'vsplit'")
    vim.validate("strong_format", config.strong_format, "string", false, "'**' or '__'")
    vim.validate("emphasis_format", config.emphasis_format, "string", false, "'*' or '_'")
    vim.validate("date_format", config.date_format, "string")
    vim.validate("prefer_lsp", config.prefer_lsp, "boolean")
    vim.validate("auto_list", config.auto_list, "boolean")
    vim.validate("auto_list_renumber", config.auto_list_renumber, "boolean")
    vim.validate("auto_table_best_fit", config.auto_table_best_fit, "boolean")
    vim.validate("default_keymaps", config.default_keymaps, "boolean")
    vim.validate("autocmds", config.autocmds, "boolean")
    vim.validate("table_best_fit_padding", config.table_best_fit_padding, "number")
    vim.validate("toc_depth", config.toc_depth, "number")

    return config
end

---Setup function
---@param user_config MdnotesConfig
function M.setup(user_config)
    M.config = validate_config(user_config)
    M.config.index_file = vim.fs.normalize(M.config.index_file)
    M.config.journal_file = vim.fs.normalize(M.config.journal_file)
    M.config.assets_path = vim.fs.normalize(M.config.assets_path)

    if M.config.open_behaviour == "buffer" then
        M.open_cmd = 'edit '
    elseif M.config.open_behaviour == "tab" then
        M.open_cmd = 'tabnew '
    elseif M.config.open_behaviour == "split" then
        M.open_cmd = 'split '
    elseif M.config.open_behaviour == "vsplit" then
        M.open_cmd = 'vsplit '
    end

    if M.config.autocmds == false then
        vim.api.nvim_del_augroup_by_name("Mdnotes")
    end

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
---@param expr_set boolean? If remap is used when opts.expr is true
---@return string|nil
function M.new_line_remap(key, expr_set)
    if expr_set == nil then expr_set = false end
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

---Go to journal file
function M.go_to_journal_file()
    if M.config.journal_file == "" then
        vim.notify("Mdn: Please specify a journal file to use this feature", vim.log.levels.ERROR)
        return
    end

    M.open_buf(M.config.journal_file)
end

---Insert an entry to the journal file
function M.journal_insert_entry()
    local strftime = vim.fn.strftime(M.config.date_format):match("([^\n\r\t]+)")
    local journal_entry_template = {
        "## " .. strftime,
        "",
        "",
        "",
        "---",
        "",
    }

    vim.fn.cursor({1 ,0})
    vim.api.nvim_put(journal_entry_template, "V", false, false)
    vim.fn.cursor({3 ,0})
end

---Open containing folder of index file
function M.open_containing_folder()
    local index_file = M.config.index_file
    if not index_file or index_file == "" then
        vim.notify("Mdn: Please specify an index file to use this feature", vim.log.levels.ERROR)
        return
    end

    -- There might be issues with code below, see issue
    -- https://github.com/neovim/neovim/issues/36293
    vim.ui.open(vim.fs.dirname(index_file))
end

return M

