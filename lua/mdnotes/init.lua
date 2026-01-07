local M = {}

local uv = vim.loop or vim.uv

M.config = {}
M.patterns = {}
M.open_cmd = nil

local default_config = {
    index_file = "",
    journal_file = "",
    assets_path = "",
    insert_file_behaviour = "copy",         -- "copy" or "move" files when inserting from clipboard
    asset_overwrite_behaviour = "error",    -- "overwrite" or "error" when finding assset file conflicts
    open_behaviour = "buffer",              -- "buffer", "tab", "split", or "vsplit" to open when following links
    strong_format = "**",                   -- "**" or "__"
    emphasis_format = "*",                  -- "*" or "_"
    date_format = "%a %d %b %Y",            -- date format based on :h strftime()
    prefer_lsp = false,                     -- to prefer LSP functions than the mdnotes functions
    auto_list = true,                       -- automatic list continuation
    auto_list_renumber = true,              -- automatic renumbering of ordered lists
    auto_table_best_fit = true,             -- automatic table best fit
    default_keymaps = false,
	table_best_fit_padding = 0,             -- add padding around cell contents when using tables_best_fit
    toc_depth = 4                           -- depth shown in the ToC
}

local function validate_config(user_config)
    local config = vim.tbl_deep_extend("force", default_config, user_config or {})

    vim.validate("index_file", config.index_file, "string")
    vim.validate("journal_file", config.journal_file, "string")
    vim.validate("assets_path", config.assets_path, "string")
    vim.validate("insert_file_behaviour", config.insert_file_behaviour, "string", false, "'copy' or 'move'")
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
    vim.validate("table_best_fit_padding", config.table_best_fit_padding, "number")
    vim.validate("toc_depth", config.toc_depth, "number")

    return config
end

function M.setup(user_config)
    M.config = validate_config(user_config)
    M.config.index_file = vim.fs.normalize(M.config.index_file)
    M.config.journal_file = vim.fs.normalize(M.config.journal_file)
    M.config.assets_path = vim.fs.normalize(M.config.assets_path)
    -- TODO: Remove this
    M.patterns = require('mdnotes.patterns')

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

function M.list_remap(inc_val)
    -- ul = unordered list, ol = ordered list
    local line = vim.api.nvim_get_current_line()
    local ul_indent, ul_marker, ul_text = line:match(M.patterns.unordered_list)
    local ol_indent, ol_marker, ol_separator, ol_text = line:match(M.patterns.ordered_list)
    local indent = ul_indent or ol_indent
    local text = ul_text or ol_text or ""

    text = text:gsub(M.patterns.task, "")
    text = text:gsub("[%s]", "")

    if text and text ~= "" then
        if ul_marker then
            if ul_text:match(M.patterns.task) then
                return indent, "\n" .. ul_marker .. " " .. "[ ] "
            else
                return indent, "\n" .. ul_marker .. " "
            end
        end

        if ol_marker then
            if ol_text:match(M.patterns.task) then
                return indent, "\n" .. tostring(tonumber(ol_marker + inc_val)) .. ol_separator .. " " .. "[ ] "
            else
                return indent, "\n" .. tostring(tonumber(ol_marker + inc_val)) .. ol_separator .. " "
            end
        end
    end

    return indent, "\n"
end

function M.open()
    local validate_tbl = require('mdnotes.inline_link').validate(true) or {}
    local _, uri, path, fragment, _, _ = unpack(validate_tbl)

    if not uri or not path or not fragment then return end

    -- Fix bug when opening link that's not saved
    -- Unsure if undesired but I think makes sense
    vim.cmd("silent w")

    -- Check if the file exists
    if uv.fs_stat(path) then
        vim.cmd(M.open_cmd .. path)
        if fragment and fragment ~= "" then
            -- Navigate to fragment
            fragment = require('mdnotes.toc').get_fragment(fragment)
            vim.fn.cursor(vim.fn.search("# " .. fragment), 1)
            vim.api.nvim_input('zz')
        end

        return
    end

    -- If nothing has happened so far then just open it
    -- This if-statement should be removed in Neovim 0.12
    if vim.fn.has("win32") == 1 then
        vim.system({'cmd.exe', '/c', 'start', '', uri})
    else
        vim.ui.open(uri)
    end
end

function M.go_to_index_file()
    if M.config.index_file == "" then
        vim.notify(("Mdn: Please specify an index file to use this feature."), vim.log.levels.ERROR)
        return
    end

    vim.cmd(M.open_cmd .. M.config.index_file)
end

function M.go_to_journal_file()
    if M.config.journal_file == "" then
        vim.notify(("Mdn: Please specify a diary file to use this feature."), vim.log.levels.ERROR)
        return
    end

    vim.cmd(M.open_cmd .. M.config.journal_file)
end

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

    vim.api.nvim_win_set_cursor(0, {1 ,0})
    vim.api.nvim_put(journal_entry_template, "V", false, false)
    vim.api.nvim_win_set_cursor(0, {3 ,0})
end

return M

