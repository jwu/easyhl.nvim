local util = require('easyhl.util')

local M = {}

-- Window-local state storage
-- Using vim.w for window-local variables

---Initialize window-local highlight state
local function init_win_state()
  if vim.w.ex_hl_match_ids == nil then
    vim.w.ex_hl_match_ids = { 0, 0, 0, 0, 0 }
  end
  if vim.w.ex_hl_text == nil then
    vim.w.ex_hl_text = { '', '', '', '', '' }
  end
  if vim.w.ex_hl_meta == nil then
    vim.w.ex_hl_meta = { false, false, false, false, false }
  end
end

---Reset highlight for a label
---@param label number 1-4
local function reset_label(label)
  local match_ids = vim.w.ex_hl_match_ids
  if match_ids and match_ids[label] and match_ids[label] ~= 0 then
    pcall(vim.fn.matchdelete, match_ids[label])
  end
  -- Update match_ids table and write back
  match_ids[label] = 0
  vim.w.ex_hl_match_ids = match_ids
  -- Update text table and write back
  local texts = vim.w.ex_hl_text
  texts[label] = ''
  vim.w.ex_hl_text = texts
  local meta = vim.w.ex_hl_meta
  meta[label] = false
  vim.w.ex_hl_meta = meta
  vim.fn.setreg(util.reg_map[label], '')
end

---Apply a highlight to a label
---@param label number 1-4
---@param pattern string
---@param opts? { kind?: string, source?: string, toggle?: boolean }
local function apply_highlight(label, pattern, opts)
  opts = opts or {}

  if pattern == '' then
    M.clear(label)
    return
  end

  local final_pattern = util.maybe_add_casefold(pattern)
  local texts = vim.w.ex_hl_text

  if opts.toggle ~= false and final_pattern == texts[label] then
    M.clear(label)
    return
  end

  reset_label(label)

  local match_ids = vim.w.ex_hl_match_ids
  match_ids[label] = vim.fn.matchadd(util.get_hl_group(label), final_pattern, label)
  vim.w.ex_hl_match_ids = match_ids

  texts[label] = final_pattern
  vim.w.ex_hl_text = texts

  local meta = vim.w.ex_hl_meta
  meta[label] = {
    kind = opts.kind or 'pattern',
    source = opts.source or pattern,
  }
  vim.w.ex_hl_meta = meta

  local reg_pattern = pattern
  if label == 2 or label == 4 then
    reg_pattern = util.strip_word_boundaries(pattern)
  end
  vim.fn.setreg(util.reg_map[label], reg_pattern)
end

---Define highlight groups
function M.define_highlights()
  local config = require('easyhl.config').config

  local default_highlights = {
    EasyHLLabel1 = { bg = 'LightCyan' },
    EasyHLLabel2 = { bg = 'LightMagenta' },
    EasyHLLabel3 = { bg = 'LightRed' },
    EasyHLLabel4 = { bg = 'LightGreen' },
  }

  -- Apply defaults with default=true (won't override existing)
  for name, opts in pairs(default_highlights) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend('force', opts, { default = true }))
  end

  -- Apply user-defined colors (will always override)
  for name, opts in pairs(config.colors or {}) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

---Highlight word under cursor
---@param label number 1-4
function M.highlight_word(label)
  if not util.is_valid_label(label) then
    vim.notify('EasyHL: Invalid label ' .. label .. '. Must be 1-4.', vim.log.levels.ERROR)
    return
  end

  init_win_state()

  if util.is_blank_cursor() then
    M.clear(label)
    return
  end

  local word = util.get_cword()
  if word == '' then
    M.clear(label)
    return
  end

  local meta = vim.w.ex_hl_meta
  local current = meta[label]
  if current and current.kind == 'word' and current.source == word then
    M.clear(label)
    return
  end

  for i = 1, 4 do
    if i ~= label then
      local other = meta[i]
      if other and other.kind == 'word' and other.source == word then
        reset_label(i)
      end
    end
  end

  local pattern = util.make_word_pattern(word)
  apply_highlight(label, pattern, { kind = 'word', source = word, toggle = false })
end

---Highlight text with pattern
---@param label number 1-4
---@param pattern string
function M.highlight_text(label, pattern)
  if not util.is_valid_label(label) then
    vim.notify('EasyHL: Invalid label ' .. label .. '. Must be 1-4.', vim.log.levels.ERROR)
    return
  end

  init_win_state()
  apply_highlight(label, pattern, { kind = 'pattern', source = pattern })
end

---Highlight visual selection range
---@param label number 1-4
function M.highlight_range(label)
  if not util.is_valid_label(label) then
    vim.notify('EasyHL: Invalid label ' .. label .. '. Must be 1-4.', vim.log.levels.ERROR)
    return
  end

  init_win_state()

  local visual_mode = vim.fn.visualmode()
  local start_pos = vim.fn.getpos('v')
  local end_pos = vim.fn.getpos('.')
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local start_col = start_pos[3]
  local end_col = end_pos[3]

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_pos, end_pos = end_pos, start_pos
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  local pattern
  if visual_mode == 'V' or start_line ~= end_line then
    -- Linewise or multi-line visual selection: use line-based pattern
    pattern = string.format('\\%%>%dl\\%%<%dl', start_line - 1, end_line + 1)
  else
    -- Same-line character/block selection: read the current selection directly.
    local ok, chunks = pcall(vim.api.nvim_buf_get_text, 0, start_line - 1, start_col - 1, end_line - 1, end_col, {})
    local text = ok and table.concat(chunks, '\n') or ''

    if text ~= '' then
      pattern = text
    else
      -- Fallback to column-based pattern
      pattern = string.format(
        '\\%%>%dl\\%%>%dv\\%%<%dl\\%%<%dv',
        start_line - 1,
        start_col - 1,
        end_line + 1,
        end_col + 1
      )
    end
  end

  apply_highlight(label, pattern, { kind = 'range', source = pattern, toggle = false })

  if vim.api and vim.api.nvim_input then
    vim.api.nvim_input('<Esc>')
  end
end

---Clear highlight for a label
---@param label number 0-4 (0 = clear all)
function M.clear(label)
  init_win_state()

  if label == 0 then
    for i = 1, 4 do
      reset_label(i)
    end
  else
    if not util.is_valid_label(label) then
      vim.notify('EasyHL: Invalid label ' .. label .. '. Must be 0-4.', vim.log.levels.ERROR)
      return
    end
    reset_label(label)
  end
end

---Clear all highlights
function M.clear_all()
  M.clear(0)
end

---Get current highlight text for a label
---@param label number 1-4
---@return string|nil
function M.get_hl_text(label)
  init_win_state()
  return vim.w.ex_hl_text[label]
end

return M
