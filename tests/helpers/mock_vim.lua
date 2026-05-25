local M = {}

---@param opts? table
---@return { vim: table, state: table, render: function }
function M.new(opts)
  opts = opts or {}

  local next_extmark_id = 0
  local state = {
    current_word = opts.current_word or '',
    visual_text = opts.visual_text or '',
    visual_mode = opts.visual_mode or 'v',
    positions = opts.positions or {
      v = { 0, 1, 1, 0 },
      dot = { 0, 1, 1, 0 },
      ["'<"] = { 0, 1, 1, 0 },
      ["'>"] = { 0, 1, 1, 0 },
    },
    buffer_text = opts.buffer_text or { '' },
    cols = opts.cols or {
      ["'<"] = 1,
      ["'>"] = 1,
    },
    registers = {},
    register_types = {},
    extmarks = {},
    decoration_providers = {},
    notifications = {},
    commands = {},
    inputs = {},
  }

  local vim = {
    w = {},
    fn = {},
    api = {},
    log = {
      levels = {
        ERROR = 'ERROR',
      },
    },
    notify = function(msg, level)
      table.insert(state.notifications, { msg = msg, level = level })
    end,
  }

  local function render()
    state.extmarks = {}
    next_extmark_id = 0

    for ns, provider in pairs(state.decoration_providers) do
      if provider.on_win then
        provider.on_win(ns, 0, 0, 0, #state.buffer_text)
      end
    end
  end

  vim.cmd = function(cmd)
    table.insert(state.commands, cmd)
    if cmd == 'silent normal! gv"ay' then
      state.registers.a = state.visual_text
      state.register_types.a = 'v'
    elseif cmd == 'redraw' then
      render()
    end
  end

  function vim.fn.expand(expr)
    if expr == '<cword>' then
      return state.current_word
    end
    return ''
  end

  function vim.fn.getline(expr)
    if expr == '.' then
      local row = (state.positions.dot or { 0, 1, 1, 0 })[2]
      return state.buffer_text[row] or ''
    end
    return ''
  end

  local function unescape_very_magic_literal(text)
    return text:gsub('\\\\', '\\')
  end

  local function find_with_case(line, needle, start_col, ignorecase)
    if ignorecase then
      local haystack = line:lower()
      local lowered = needle:lower()
      return haystack:find(lowered, start_col + 1, true)
    end

    return line:find(needle, start_col + 1, true)
  end

  function vim.fn.matchstrpos(line, pattern, start_col)
    start_col = start_col or 0

    local ignorecase = false
    if pattern:sub(1, 2) == '\\c' then
      ignorecase = true
      pattern = pattern:sub(3)
    end

    if pattern:sub(1, 2) == '\\V' then
      local needle = unescape_very_magic_literal(pattern:sub(3))
      local start_idx, end_idx = find_with_case(line, needle, start_col, ignorecase)
      if not start_idx then
        return { '', -1, -1 }
      end
      return { line:sub(start_idx, end_idx), start_idx - 1, end_idx }
    end

    local word = pattern:match '^\\<\\C(.*)\\>$' or pattern:match '^\\<(.*)\\>$'
    if word then
      local search_start = start_col
      while search_start <= #line do
        local start_idx, end_idx = find_with_case(line, word, search_start, ignorecase)
        if not start_idx then
          return { '', -1, -1 }
        end

        local before = start_idx == 1 and '' or line:sub(start_idx - 1, start_idx - 1)
        local after = end_idx == #line and '' or line:sub(end_idx + 1, end_idx + 1)
        local left_ok = before == '' or not before:match '[%w_]'
        local right_ok = after == '' or not after:match '[%w_]'
        if left_ok and right_ok then
          return { line:sub(start_idx, end_idx), start_idx - 1, end_idx }
        end

        search_start = end_idx
      end
    end

    local start_idx, end_idx = find_with_case(line, pattern, start_col, ignorecase)
    if not start_idx then
      return { '', -1, -1 }
    end
    return { line:sub(start_idx, end_idx), start_idx - 1, end_idx }
  end

  function vim.fn.setreg(reg, value, regtype)
    state.registers[reg] = value
    if regtype ~= nil then
      state.register_types[reg] = regtype
    end
  end

  function vim.fn.getreg(reg)
    return state.registers[reg] or ''
  end

  function vim.fn.getregtype(reg)
    return state.register_types[reg] or 'v'
  end

  function vim.fn.getpos(mark)
    if mark == '.' then
      return state.positions.dot or { 0, 1, 1, 0 }
    end
    if mark == 'v' then
      return state.positions.v or { 0, 1, 1, 0 }
    end
    if state.positions[mark] then
      return state.positions[mark]
    end
    return { 0, 1, 1, 0 }
  end

  function vim.fn.col(mark)
    if mark == '.' then
      return (state.positions.dot or { 0, 1, 1, 0 })[3] or 1
    end
    return state.cols[mark] or 1
  end

  function vim.fn.visualmode()
    return state.visual_mode
  end

  function vim.fn.mode()
    return state.mode or state.visual_mode
  end

  function vim.api.nvim_create_namespace(name)
    state.namespace = name
    return 1
  end

  function vim.api.nvim_set_decoration_provider(ns, provider)
    state.decoration_providers[ns] = provider
  end

  function vim.api.nvim_win_get_var(_, name)
    local value = vim.w[name]
    if value == nil then
      error('Key not found: ' .. name)
    end
    return value
  end

  function vim.api.nvim_buf_set_extmark(_, ns, row, col, extmark_opts)
    next_extmark_id = next_extmark_id + 1
    state.extmarks[next_extmark_id] = {
      ns = ns,
      row = row,
      col = col,
      opts = extmark_opts,
    }
    return next_extmark_id
  end

  function vim.api.nvim_input(keys)
    table.insert(state.inputs, keys)
  end

  function vim.api.nvim_buf_get_text(_, start_row, start_col, end_row, end_col, _)
    local chunks = {}

    for row = start_row + 1, end_row + 1 do
      local line = state.buffer_text[row] or ''
      if start_row == end_row then
        table.insert(chunks, line:sub(start_col + 1, end_col))
      elseif row == start_row + 1 then
        table.insert(chunks, line:sub(start_col + 1))
      elseif row == end_row + 1 then
        table.insert(chunks, line:sub(1, end_col))
      else
        table.insert(chunks, line)
      end
    end

    return chunks
  end

  function vim.api.nvim_buf_get_lines(_, start_row, end_row, _)
    local lines = {}
    for row = start_row + 1, end_row do
      lines[#lines + 1] = state.buffer_text[row] or ''
    end
    return lines
  end

  return {
    vim = vim,
    state = state,
    render = render,
  }
end

return M
