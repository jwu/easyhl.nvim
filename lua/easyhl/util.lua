local M = {}

-- Register map for labels 1-4 (q, w, e, r)
-- Use explicit 0-index to match Vim script behavior
M.reg_map = { [0] = '', 'q', 'w', 'e', 'r' }

---Check if label number is valid (1-4)
---@param label number
---@return boolean
function M.is_valid_label(label)
  return label >= 1 and label <= 4
end

---Get word under cursor
---@return string
function M.get_cword()
  return vim.fn.expand('<cword>')
end

---Check whether cursor is on a blank character or beyond end of line
---@return boolean
function M.is_blank_cursor()
  local line = vim.fn.getline('.')
  local col = vim.fn.col('.')

  if line == '' or col <= 0 or col > #line then
    return true
  end

  local char = line:sub(col, col)
  return char:match('%s') ~= nil
end

---Create word pattern (with word boundaries)
---@param word string
---@return string
function M.make_word_pattern(word)
  return '\\<\\C' .. word .. '\\>'
end

---Create a literal Vim pattern from plain text
---@param text string
---@return string
function M.make_literal_pattern(text)
  return '\\V' .. text:gsub('\\', '\\\\')
end

---Check if pattern has uppercase characters
---@param pattern string
---@return boolean
function M.has_uppercase(pattern)
  return pattern:match('%u') ~= nil
end

---Add case-insensitive prefix if no uppercase
---@param pattern string
---@return string
function M.maybe_add_casefold(pattern)
  if not M.has_uppercase(pattern) then
    return '\\c' .. pattern
  end
  return pattern
end

---Strip word boundary markers from pattern
---@param pattern string
---@return string
function M.strip_word_boundaries(pattern)
  if pattern:match('^\\<\\C.*\\>$') then
    return pattern:sub(5, -3)
  end
  return pattern
end

---Get highlight group name for label
---@param label number
---@return string
function M.get_hl_group(label)
  return 'EasyHLLabel' .. label
end

return M
