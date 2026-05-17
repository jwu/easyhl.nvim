local M = {}

function M.check()
  vim.health.start 'easyhl'

  -- Check Neovim version
  local v = vim.version()
  vim.health.ok('Neovim version: ' .. v.major .. '.' .. v.minor .. '.' .. v.patch)

  -- Check if version meets minimum requirement (0.11)
  if vim.version.lt(v, { 0, 11, 0 }) then
    vim.health.warn 'EasyHL requires Neovim 0.11+. Some features may not work correctly.'
  else
    vim.health.ok 'Neovim version requirement satisfied (0.11+)'
  end

  -- Check highlight groups
  local hl_groups = { 'EasyHLLabel1', 'EasyHLLabel2', 'EasyHLLabel3', 'EasyHLLabel4' }
  for _, name in ipairs(hl_groups) do
    local hl = vim.api.nvim_get_hl(0, { name = name })
    if hl and (hl.bg or hl.fg or hl.reverse) then
      vim.health.ok('Highlight group ' .. name .. ' is defined')
    else
      vim.health.warn('Highlight group ' .. name .. ' is not defined')
    end
  end
end

return M
