-- EasyHL Plugin Entry
-- Commands, autocmds, and <Plug> mappings

local highlight = require('easyhl.highlight')

-- Define highlights on load and on colorscheme change
highlight.define_highlights()

vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('EasyHL', { clear = true }),
  callback = function()
    highlight.define_highlights()
  end,
})

--------------------------------------------------------------------------------
-- <Plug> Mappings
--------------------------------------------------------------------------------

-- Word highlight mappings (normal mode)
for i = 1, 4 do
  vim.keymap.set('n', string.format('<Plug>(EasyhlWord%d)', i), function()
    require('easyhl').highlight_word(i)
  end, { desc = 'EasyHL: Highlight word ' .. i })

  -- Range highlight mappings (visual mode)
  vim.keymap.set('v', string.format('<Plug>(EasyhlRange%d)', i), function()
    require('easyhl').highlight_range(i)
  end, { desc = 'EasyHL: Highlight range ' .. i })

  -- Cancel mappings
  vim.keymap.set('n', string.format('<Plug>(EasyhlCancel%d)', i), function()
    require('easyhl').clear(i)
  end, { desc = 'EasyHL: Cancel highlight ' .. i })

  -- Direct pattern highlight commands
  vim.keymap.set('n', string.format('<Plug>(EasyhlHL%d)', i), function()
    local pattern = vim.fn.input('Pattern: ')
    if pattern ~= '' then
      require('easyhl').highlight_text(i, pattern)
    end
  end, { desc = 'EasyHL: Highlight pattern ' .. i })
end

-- Clear all
vim.keymap.set('n', '<Plug>(EasyhlCancelAll)', function()
  require('easyhl').clear_all()
end, { desc = 'EasyHL: Cancel all highlights' })

--------------------------------------------------------------------------------
-- Default Mappings (only if user hasn't disabled them)
--------------------------------------------------------------------------------

if vim.g.easyhl_no_mappings ~= 1 then
  -- Alt-1 to Alt-4: Highlight word (normal mode)
  for i = 1, 4 do
    vim.keymap.set('n', string.format('<M-%d>', i), string.format('<Plug>(EasyhlWord%d)', i), { remap = true })
    vim.keymap.set('v', string.format('<M-%d>', i), string.format('<Plug>(EasyhlRange%d)', i), { remap = true })
  end

  -- Alt-0: Clear all
  vim.keymap.set('n', '<M-0>', '<Plug>(EasyhlCancelAll)', { remap = true })

  -- Leader-0 to Leader-4: Cancel highlights
  vim.keymap.set('n', '<Leader>0', '<Plug>(EasyhlCancelAll)', { remap = true })
  for i = 1, 4 do
    vim.keymap.set('n', string.format('<Leader>%d', i), string.format('<Plug>(EasyhlCancel%d)', i), { remap = true })
  end

  -- Substitute mapping: replace Label1 with Label2
  vim.keymap.set('n', '<Leader>sub', ':%s/<c-r>q/<c-r>w/g<CR><c-o>', { silent = true })
  vim.keymap.set('v', '<Leader>sub', ':s/<c-r>q/<c-r>w/g<CR><c-o>', { silent = true })
end

--------------------------------------------------------------------------------
-- User Commands (subcommand pattern)
--------------------------------------------------------------------------------

-- Completion function for Easyhl command
local function complete_easyhl(_, cmdline, _)
  local args = vim.split(cmdline, '%s+')
  local nargs = #args

  if nargs == 2 then
    -- First argument: subcommand
    return { 'word', 'range', 'cancel', 'hl1', 'hl2', 'hl3', 'hl4' }
  elseif nargs == 3 then
    -- Second argument: label number
    local subcmd = args[2]
    if vim.tbl_contains({ 'word', 'range', 'cancel' }, subcmd) then
      if subcmd == 'cancel' then
        return { '0', '1', '2', '3', '4' }
      else
        return { '1', '2', '3', '4' }
      end
    end
  end

  return {}
end

vim.api.nvim_create_user_command('Easyhl', function(opts)
  local args = opts.fargs
  if #args < 1 then
    vim.notify('EasyHL: Usage: Easyhl {word|range|cancel|hl1-4} [label] [pattern]', vim.log.levels.ERROR)
    return
  end

  local subcmd = args[1]

  if subcmd == 'word' then
    local label = tonumber(args[2]) or 1
    require('easyhl').highlight_word(label)
  elseif subcmd == 'range' then
    local label = tonumber(args[2]) or 1
    require('easyhl').highlight_range(label)
  elseif subcmd == 'cancel' then
    local label = tonumber(args[2]) or 0
    require('easyhl').clear(label)
  elseif subcmd:match('^hl[1-4]$') then
    local label = tonumber(subcmd:sub(3))
    local pattern = args[2] or ''
    require('easyhl').highlight_text(label, pattern)
  else
    vim.notify('EasyHL: Unknown subcommand: ' .. subcmd, vim.log.levels.ERROR)
  end
end, {
  nargs = '+',
  complete = complete_easyhl,
  desc = 'EasyHL: Temporary highlight management',
  range = true,
})

--------------------------------------------------------------------------------
-- Backward-compatible Commands
--------------------------------------------------------------------------------

-- Legacy commands for backward compatibility
vim.api.nvim_create_user_command('EasyhlWord', function(opts)
  local label = tonumber(opts.args) or 1
  require('easyhl').highlight_word(label)
end, { nargs = 1, desc = 'EasyHL: Highlight word under cursor' })

vim.api.nvim_create_user_command('EasyhlCancel', function(opts)
  local label = tonumber(opts.args) or 0
  require('easyhl').clear(label)
end, { nargs = 1, desc = 'EasyHL: Cancel highlight' })

vim.api.nvim_create_user_command('EasyhlRange', function(opts)
  local label = tonumber(opts.args) or 1
  require('easyhl').highlight_range(label)
end, { nargs = 1, range = true, desc = 'EasyHL: Highlight range' })

-- HL1-HL4 commands
for i = 1, 4 do
  vim.api.nvim_create_user_command('HL' .. i, function(opts)
    require('easyhl').highlight_text(i, opts.args)
  end, { nargs = '?', desc = 'EasyHL: Highlight with label ' .. i })
end
