local M = {}

local default_config = {
    index_file = "",
    journal_file = "",
    assets_path = "",
    insert_file_behaviour = "copy", -- "copy" or "move" files when inserting from clipboard
    asset_overwrite_behaviour = "error",  -- "overwrite" or "error" when finding assset file conflicts
    wikilink_open_behaviour = "buffer",      -- "buffer" or "tab" to open when following links
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
  M.config.index_file = vim.fs.normalize(M.config.index_file)
  M.config.journal_file = vim.fs.normalize(M.config.journal_file)
  M.config.assets_path = vim.fs.normalize(M.config.assets_path)
  return M.config
end

return M
