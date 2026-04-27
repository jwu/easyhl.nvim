local M = {}

---@param opts? table
---@return { vim: table, state: table }
function M.new(opts)
  opts = opts or {}

  local next_match_id = 0
  local state = {
    current_word = opts.current_word or '',
    visual_text = opts.visual_text or '',
    positions = opts.positions or {
      v = { 0, 1, 1, 0 },
      dot = { 0, 1, 1, 0 },
    },
    cols = opts.cols or {
      ["'<"] = 1,
      ["'>"] = 1,
    },
    registers = {},
    register_types = {},
    matches = {},
    deleted_matches = {},
    notifications = {},
    commands = {},
  }

  local vim = {
    w = {},
    fn = {},
    log = {
      levels = {
        ERROR = 'ERROR',
      },
    },
    notify = function(msg, level)
      table.insert(state.notifications, { msg = msg, level = level })
    end,
    cmd = function(cmd)
      table.insert(state.commands, cmd)
      if cmd == 'silent normal! gv"ay' then
        state.registers.a = state.visual_text
        state.register_types.a = 'v'
      end
    end,
  }

  function vim.fn.expand(expr)
    if expr == '<cword>' then
      return state.current_word
    end
    return ''
  end

  function vim.fn.matchadd(group, pattern, priority)
    next_match_id = next_match_id + 1
    state.matches[next_match_id] = {
      group = group,
      pattern = pattern,
      priority = priority,
    }
    return next_match_id
  end

  function vim.fn.matchdelete(id)
    state.deleted_matches[id] = true
    state.matches[id] = nil
    return 1
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
    if mark == 'v' then
      return state.positions.v
    end
    if mark == '.' then
      return state.positions.dot
    end
    return { 0, 1, 1, 0 }
  end

  function vim.fn.col(mark)
    return state.cols[mark] or 1
  end

  return {
    vim = vim,
    state = state,
  }
end

return M
