local M = {}

local default_config = {
    index_file = "",
    journal_file = "",
    assets_path = "",
    insert_file_behaviour = "copy",         -- "copy" or "move" files when inserting from clipboard
    asset_overwrite_behaviour = "error",    -- "overwrite" or "error" when finding assset file conflicts
    wikilink_open_behaviour = "buffer",     -- "buffer" or "tab" to open when following links
    bold_format = "**",                     -- "**" or "__"
    italic_format = "*",                    -- "*" or "_"
    date_format = "%a %d %b %Y",            -- date format based on :h strftime()
    prefer_lsp = true,                      -- to prefer LSP functions than the mdnotes functions
    auto_list = true,                       -- automatic list continuation
    default_keymaps = false,
}

function M.setup(user_config)
    M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
    M.config.index_file = vim.fs.normalize(M.config.index_file)
    M.config.journal_file = vim.fs.normalize(M.config.journal_file)
    M.config.assets_path = vim.fs.normalize(M.config.assets_path)

    if not vim.tbl_contains({"copy", "move"}, M.config.insert_file_behaviour) then
        vim.notify(("Mdn: 'insert_file_behaviour' value '%s' is invalid. Can only use 'copy' or 'move'. Defaulting to 'copy'."):format(M.config.insert_file_behaviour), vim.log.levels.ERROR)
        M.config.insert_file_behaviour = "copy"
    end

    if not vim.tbl_contains({"overwrite", "error"}, M.config.asset_overwrite_behaviour) then
        vim.notify(("Mdn: 'asset_overwrite_behaviour' value '%s' is invalid. Can only use 'overwrite' or 'error'. Defaulting to 'error'."):format(M.config.asset_overwrite_behaviour), vim.log.levels.ERROR)
        M.config.asset_overwrite_behaviour = "error"
    end

    if not vim.tbl_contains({"buffer", "tab"}, M.config.wikilink_open_behaviour) then
        vim.notify(("Mdn: 'wikilink_open_behaviour' value '%s' is invalid. Can only use 'buffer' or 'tab'. Defaulting to 'buffer'."):format(M.config.wikilink_open_behaviour), vim.log.levels.ERROR)
        M.config.wikilink_open_behaviour = "buffer"
    end

    if not vim.tbl_contains({"**", "__"}, M.config.bold_format) then
        vim.notify(("Mdn: 'bold_format' character '%s' is invalid. Can only use '**' or '__'. Defaulting to '**'."):format(M.config.bold_format), vim.log.levels.ERROR)
        M.config.bold_format = "**"
    end

    if not vim.tbl_contains({"*", "_"}, M.config.italic_format) then
        vim.notify(("Mdn: 'italic_format' character '%s' is invalid. Can only use '*' or '_'. Defaulting to '*'."):format(M.config.italic_format), vim.log.levels.ERROR)
        M.config.italic_format = "*"
    end

    return M.config
end

return M
