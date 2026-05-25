local util = require 'easyhl.util'

local M = {}

local ns = vim.api.nvim_create_namespace 'easyhl'

---Request a redraw so the decoration provider can refresh ephemeral extmarks.
local function request_redraw()
  if vim.cmd then
    pcall(vim.cmd, 'redraw')
  end
end

---@param winid integer
---@param name string
---@return any
local function get_win_var(winid, name)
  if vim.api.nvim_win_get_var then
    local ok, value = pcall(vim.api.nvim_win_get_var, winid, name)
    if ok then
      return value
    end
    return nil
  end

  return vim.w[name]
end

---@param label number
---@param end_row integer
---@param end_col integer
---@return table
local function extmark_opts(label, end_row, end_col)
  return {
    end_row = end_row,
    end_col = end_col,
    hl_group = util.get_hl_group(label),
    priority = label,
    strict = false,
    ephemeral = true,
  }
end

---@param bufnr integer
---@param label number
---@param row integer
---@param col integer
---@param end_row integer
---@param end_col integer
local function set_range_extmark(bufnr, label, row, col, end_row, end_col)
  if end_row < row or (end_row == row and end_col <= col) then
    return
  end

  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, col, extmark_opts(label, end_row, end_col))
end

---@param bufnr integer
---@param label number
---@param positions integer[][]
---@param topline integer
---@param botline integer
local function render_positions(bufnr, label, positions, topline, botline)
  for _, pos in ipairs(positions) do
    local row = pos[1] - 1
    local col = pos[2] - 1
    local len = pos[3]

    if len > 0 and row >= topline and row < botline then
      set_range_extmark(bufnr, label, row, col, row, col + len)
    end
  end
end

---@param bufnr integer
---@param label number
---@param start_line integer
---@param end_line integer
---@param topline integer
---@param botline integer
local function render_line_range(bufnr, label, start_line, end_line, topline, botline)
  local start_row = math.max(start_line - 1, topline)
  local end_row = math.min(end_line, botline)

  if start_row >= end_row then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  for index, line in ipairs(lines) do
    local row = start_row + index - 1
    local opts = extmark_opts(label, row, #line)
    opts.hl_eol = true
    opts.line_hl_group = util.get_hl_group(label)
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, opts)
  end
end

---@param line string
---@param pattern string
---@param start_col integer
---@return string, integer, integer
local function match_line(line, pattern, start_col)
  local ok, result = pcall(vim.fn.matchstrpos, line, pattern, start_col)
  if not ok or type(result) ~= 'table' then
    return '', -1, -1
  end

  return result[1] or '', result[2] or -1, result[3] or -1
end

---@param bufnr integer
---@param label number
---@param pattern string
---@param topline integer
---@param botline integer
local function render_pattern(bufnr, label, pattern, topline, botline)
  local lines = vim.api.nvim_buf_get_lines(bufnr, topline, botline, false)

  for index, line in ipairs(lines) do
    local row = topline + index - 1
    local start_col = 0

    while start_col <= #line do
      local _, match_start, match_end = match_line(line, pattern, start_col)
      if match_start < 0 or match_end < 0 then
        break
      end

      if match_end > match_start then
        set_range_extmark(bufnr, label, row, match_start, row, match_end)
      end

      if match_end <= start_col then
        start_col = start_col + 1
      else
        start_col = match_end
      end
    end
  end
end

vim.api.nvim_set_decoration_provider(ns, {
  on_win = function(_, winid, bufnr, topline, botline)
    local specs = get_win_var(winid, 'ex_hl_specs')
    if type(specs) ~= 'table' then
      return
    end

    for label = 1, 4 do
      local spec = specs[label]
      if type(spec) == 'table' then
        if spec.type == 'positions' then
          render_positions(bufnr, label, spec.positions or {}, topline, botline)
        elseif spec.type == 'line_range' then
          render_line_range(bufnr, label, spec.start_line, spec.end_line, topline, botline)
        elseif spec.type == 'pattern' then
          render_pattern(bufnr, label, spec.pattern, topline, botline)
        end
      end
    end
  end,
})

-- Window-local state storage
-- Using vim.w for window-local variables

---Initialize window-local highlight state
local function init_win_state()
  if vim.w.ex_hl_specs == nil then
    vim.w.ex_hl_specs = { false, false, false, false, false }
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
---@param redraw? boolean
local function reset_label(label, redraw)
  local specs = vim.w.ex_hl_specs
  specs[label] = false
  vim.w.ex_hl_specs = specs

  local texts = vim.w.ex_hl_text
  texts[label] = ''
  vim.w.ex_hl_text = texts

  local meta = vim.w.ex_hl_meta
  meta[label] = false
  vim.w.ex_hl_meta = meta

  vim.fn.setreg(util.reg_map[label], '')

  if redraw ~= false then
    request_redraw()
  end
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

  reset_label(label, false)

  local specs = vim.w.ex_hl_specs
  specs[label] = {
    type = 'pattern',
    pattern = final_pattern,
  }
  vim.w.ex_hl_specs = specs

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

  request_redraw()
end

---@param label number 1-4
---@param start_line number
---@param end_line number
---@param pattern string
local function apply_line_range_highlight(label, start_line, end_line, pattern)
  reset_label(label, false)

  local final_pattern = util.maybe_add_casefold(pattern)
  local specs = vim.w.ex_hl_specs
  specs[label] = {
    type = 'line_range',
    start_line = start_line,
    end_line = end_line,
  }
  vim.w.ex_hl_specs = specs

  local texts = vim.w.ex_hl_text
  texts[label] = final_pattern
  vim.w.ex_hl_text = texts

  local meta = vim.w.ex_hl_meta
  meta[label] = {
    kind = 'range',
    source = pattern,
  }
  vim.w.ex_hl_meta = meta

  vim.fn.setreg(util.reg_map[label], pattern)
  request_redraw()
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

  reset_label(label, false)

  local specs = vim.w.ex_hl_specs
  specs[label] = {
    type = 'positions',
    positions = positions,
  }
  vim.w.ex_hl_specs = specs

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

  request_redraw()
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
        reset_label(i, false)
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
  local start_pos = vim.fn.getpos 'v'
  local end_pos = vim.fn.getpos '.'
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
    apply_line_range_highlight(label, start_line, end_line, pattern)
  elseif visual_mode == '\022' then
    local positions, text = build_blockwise_positions(start_line, start_col, end_line, end_col)
    apply_pos_highlight(
      label,
      positions,
      { kind = 'range', source = serialize_positions(positions), reg_pattern = text }
    )
  elseif start_line ~= end_line then
    local positions, text =
      build_charwise_multiline_positions(start_line, start_col, end_line, end_col)
    apply_pos_highlight(
      label,
      positions,
      { kind = 'range', source = serialize_positions(positions), reg_pattern = text }
    )
  else
    local ok, chunks =
      pcall(vim.api.nvim_buf_get_text, 0, start_line - 1, start_col - 1, end_line - 1, end_col, {})
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
    vim.api.nvim_input '<Esc>'
  end
end

---Clear highlight for a label
---@param label number 0-4 (0 = clear all)
function M.clear(label)
  init_win_state()

  if label == 0 then
    for i = 1, 4 do
      reset_label(i, false)
    end
    request_redraw()
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
