local M = {}

local default_config = {
    index_file = "",
    diary_file = "",
    assets_path = "",
    insert_file_behaviour = "copy", -- "copy" or "move"
    overwrite_behaviour = "error",  -- "overwrite" or "error"
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
  M.config.assets_path = vim.fs.normalize(M.config.assets_path)
  return M.config
end

return M
