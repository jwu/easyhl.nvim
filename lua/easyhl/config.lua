---@class easyhl.Config
---@field colors? table<string, table> Custom highlight colors

---@type easyhl.Config
local default_config = {
  colors = {},
}

local M = {}
M.config = default_config

---Setup configuration
---@param opts? easyhl.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', default_config, opts or {})
  -- Re-define highlights after user config is merged
  require('easyhl.highlight').define_highlights()
end

return M
