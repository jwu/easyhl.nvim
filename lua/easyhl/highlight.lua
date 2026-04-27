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
  match_ids[label] = 0
  vim.w.ex_hl_match_ids = match_ids

  local texts = vim.w.ex_hl_text
  texts[label] = ''
  vim.w.ex_hl_text = texts

  local meta = vim.w.ex_hl_meta
  meta[label] = false
  vim.w.ex_hl_meta = meta

  vim.fn.setreg(util.reg_map[label], '')
end

---@param start_line number
---@param end_line number
---@return string[]
local function get_buffer_lines(start_line, end_line)
  return vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
end

---@param positions integer[][]
---@return string
local function serialize_positions(positions)
  local parts = {}
  for _, pos in ipairs(positions) do
    parts[#parts + 1] = string.format('%d:%d:%d', pos[1], pos[2], pos[3])
  end
  return table.concat(parts, '|')
end

---@param label number 1-4
---@param pattern string
---@param opts? { kind?: string, source?: string, toggle?: boolean, reg_pattern?: string }
local function apply_pattern_highlight(label, pattern, opts)
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

  local reg_pattern = opts.reg_pattern or pattern
  if label == 2 or label == 4 then
    reg_pattern = util.strip_word_boundaries(reg_pattern)
  end
  vim.fn.setreg(util.reg_map[label], reg_pattern)
end

---@param label number 1-4
---@param positions integer[][]
---@param opts? { kind?: string, source?: string, reg_pattern?: string }
local function apply_pos_highlight(label, positions, opts)
  opts = opts or {}

  if #positions == 0 then
    M.clear(label)
    return
  end

  reset_label(label)

  local match_ids = vim.w.ex_hl_match_ids
  match_ids[label] = vim.fn.matchaddpos(util.get_hl_group(label), positions, label)
  vim.w.ex_hl_match_ids = match_ids

  local texts = vim.w.ex_hl_text
  texts[label] = opts.source or serialize_positions(positions)
  vim.w.ex_hl_text = texts

  local meta = vim.w.ex_hl_meta
  meta[label] = {
    kind = opts.kind or 'range',
    source = opts.source or texts[label],
  }
  vim.w.ex_hl_meta = meta

  local reg_pattern = opts.reg_pattern or ''
  vim.fn.setreg(util.reg_map[label], reg_pattern)
end

---@param start_line number
---@param start_col number
---@param end_line number
---@param end_col number
---@return integer[][], string
local function build_charwise_multiline_positions(start_line, start_col, end_line, end_col)
  local lines = get_buffer_lines(start_line, end_line)
  local positions = {}
  local chunks = {}

  local first_line = lines[1] or ''
  if #first_line >= start_col then
    local len = #first_line - start_col + 1
    positions[#positions + 1] = { start_line, start_col, len }
    chunks[#chunks + 1] = first_line:sub(start_col)
  else
    chunks[#chunks + 1] = ''
  end

  for lnum = start_line + 1, end_line - 1 do
    local line = lines[lnum - start_line + 1] or ''
    if #line > 0 then
      positions[#positions + 1] = { lnum, 1, #line }
    end
    chunks[#chunks + 1] = line
  end

  local last_line = lines[#lines] or ''
  local last_col = math.min(end_col, #last_line)
  if last_col > 0 then
    positions[#positions + 1] = { end_line, 1, last_col }
    chunks[#chunks + 1] = last_line:sub(1, last_col)
  else
    chunks[#chunks + 1] = ''
  end

  return positions, table.concat(chunks, '\n')
end

---@param start_line number
---@param start_col number
---@param end_line number
---@param end_col number
---@return integer[][], string
local function build_blockwise_positions(start_line, start_col, end_line, end_col)
  local left_col = math.min(start_col, end_col)
  local right_col = math.max(start_col, end_col)
  local lines = get_buffer_lines(start_line, end_line)
  local positions = {}
  local chunks = {}

  for idx, line in ipairs(lines) do
    local lnum = start_line + idx - 1
    if #line >= left_col then
      local clipped_right = math.min(right_col, #line)
      if clipped_right >= left_col then
        positions[#positions + 1] = { lnum, left_col, clipped_right - left_col + 1 }
        chunks[#chunks + 1] = line:sub(left_col, clipped_right)
      else
        chunks[#chunks + 1] = ''
      end
    else
      chunks[#chunks + 1] = ''
    end
  end

  return positions, table.concat(chunks, '\n')
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

  for name, opts in pairs(default_highlights) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend('force', opts, { default = true }))
  end

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
  apply_pattern_highlight(label, pattern, { kind = 'word', source = word, toggle = false })
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
  apply_pattern_highlight(label, pattern, { kind = 'pattern', source = pattern })
end

---Highlight visual selection range
---@param label number 1-4
function M.highlight_range(label)
  if not util.is_valid_label(label) then
    vim.notify('EasyHL: Invalid label ' .. label .. '. Must be 1-4.', vim.log.levels.ERROR)
    return
  end

  init_win_state()

  local visual_mode = vim.fn.mode()
  if visual_mode:sub(1, 1) == 'n' then
    visual_mode = vim.fn.visualmode()
  end
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

  if visual_mode == 'V' then
    local pattern = string.format('\\%%>%dl\\%%<%dl', start_line - 1, end_line + 1)
    apply_pattern_highlight(label, pattern, { kind = 'range', source = pattern, toggle = false })
  elseif visual_mode == '\022' then
    local positions, text = build_blockwise_positions(start_line, start_col, end_line, end_col)
    apply_pos_highlight(label, positions, { kind = 'range', source = serialize_positions(positions), reg_pattern = text })
  elseif start_line ~= end_line then
    local positions, text = build_charwise_multiline_positions(start_line, start_col, end_line, end_col)
    apply_pos_highlight(label, positions, { kind = 'range', source = serialize_positions(positions), reg_pattern = text })
  else
    local ok, chunks = pcall(vim.api.nvim_buf_get_text, 0, start_line - 1, start_col - 1, end_line - 1, end_col, {})
    local text = ok and table.concat(chunks, '\n') or ''

    if text ~= '' then
      local pattern = util.make_literal_pattern(text)
      apply_pattern_highlight(label, pattern, {
        kind = 'range',
        source = pattern,
        toggle = false,
        reg_pattern = pattern,
      })
    else
      local positions = { { start_line, start_col, math.max(end_col - start_col + 1, 1) } }
      apply_pos_highlight(label, positions, {
        kind = 'range',
        source = serialize_positions(positions),
      })
    end
  end

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
