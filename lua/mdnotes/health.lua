---Mdnotes :checkhealth mdnotes
local M = {}

M.check = function()
    local config = require('mdnotes').config
    local config_str = vim.inspect(config)
    local config_ok = true

    vim.health.start("Mdnotes report")

    if not vim.tbl_contains({"copy", "move"}, config.asset_insert_behaviour) then
        vim.health.error(("'asset_insert_behaviour' value '%s' is invalid. Can only use 'copy' or 'move'. Defaulting to 'copy'."):format(M.config.asset_insert_behaviour))
        config_ok = false
    end

    if not vim.tbl_contains({"overwrite", "error"}, config.asset_overwrite_behaviour) then
        vim.health.error(("Mdn: 'asset_overwrite_behaviour' value '%s' is invalid. Can only use 'overwrite' or 'error'. Defaulting to 'error'."):format(M.config.asset_overwrite_behaviour))
        config_ok = false
    end

    if not vim.tbl_contains({"buffer", "tab", "split", "vsplit"}, config.open_behaviour) then
        vim.health.error(("'open_behaviour' value '%s' is invalid. Can only use 'buffer', 'tab', 'split', or 'vsplit'. Defaulting to 'buffer'."):format(M.config.open_behaviour))
        config_ok = false
    end

    if not vim.tbl_contains({"**", "__"}, config.strong_format) then
        vim.health.error(("'strong_format' character '%s' is invalid. Can only use '**' or '__'. Defaulting to '**'."):format(M.config.strong_format))
        config_ok = false
    end

    if not vim.tbl_contains({"*", "_"}, config.emphasis_format) then
        vim.health.error(("'emphasis_format' character '%s' is invalid. Can only use '*' or '_'. Defaulting to '*'."):format(M.config.emphasis_format))
        config_ok = false
    end

    local detected_md_lsps = vim.iter(vim.lsp.get_clients())
    :map(function(client)
        if vim.tbl_contains(client.config.filetypes, "markdown") then
            return client.name
        end
    end):totable()

    if #detected_md_lsps > 0 then
        vim.health.ok(("Detected %s Markdown LSP(s): %s"):format(#detected_md_lsps, table.concat(detected_md_lsps, ",")))
    else
        vim.health.warn("Detected no Markdown LSP(s). If you're using any Markdown LSPs, open a Markdon buffer and run checkhealth again.")
    end

    if not vim.tbl_isempty(config) and config_ok == true then
        vim.health.ok("Setup is correct and all checks have passed. Detected config:\n" .. config_str)
    else
        vim.health.error("Setup is incorrect. See errors")
    end
end

return M
