local M = {}

local default_config = {
    index_file = "",
    diary_file = "",
    assets_path = "",
    insert_image_behaviour = "copy",
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
  return M.config
end

return M
