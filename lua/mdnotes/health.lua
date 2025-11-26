local M = {}

M.check = function()
    local mdnotes = require('mdnotes')

    vim.health.start("Mdnotes report")

    local detected_md_lsps = vim.iter(vim.lsp.get_clients())
    :map(function(client)
        if vim.tbl_contains(client.config.filetypes, "markdown") then
            return client.name
        end
    end)
    :totable()

    if #detected_md_lsps > 0 then
        vim.health.ok(("Detected %s Markdown LSP(s): %s"):format(#detected_md_lsps, table.concat(detected_md_lsps, ",")))
    else
        vim.health.warn("Detected no Markdown LSP(s). Open a Markdown buffer and try again.")
    end

    if not vim.tbl_isempty(mdnotes.config) then
        vim.health.ok("Setup is correct. Detected config.")
    else
        vim.health.error("Setup is incorrect")
    end
end

return M
