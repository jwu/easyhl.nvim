package.path = table.concat({
  './lua/?.lua',
  './lua/?/init.lua',
  './tests/?.lua',
  './tests/?/init.lua',
  package.path,
}, ';')

local mock_vim = require('tests.helpers.mock_vim')

describe('easyhl.highlight', function()
  local highlight
  local env

  local function reload_modules()
    package.loaded['easyhl.highlight'] = nil
    package.loaded['easyhl.util'] = nil
    highlight = require('easyhl.highlight')
  end

  before_each(function()
    env = mock_vim.new()
    _G.vim = env.vim
    reload_modules()
  end)

  after_each(function()
    _G.vim = nil
  end)

  it('toggles off the same word on the same label', function()
    env.state.current_word = 'foo'
    env.state.buffer_text = { 'foo' }
    env.state.positions.dot = { 0, 1, 1, 0 }

    highlight.highlight_word(1)
    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(1))
    assert.are.equal('\\<\\Cfoo\\>', env.state.registers.q)

    highlight.highlight_word(1)
    assert.are.equal('', highlight.get_hl_text(1))
    assert.are.equal('', env.state.registers.q)
  end)

  it('moves a word highlight from another label', function()
    env.state.current_word = 'foo'
    env.state.buffer_text = { 'foo' }
    env.state.positions.dot = { 0, 1, 1, 0 }

    highlight.highlight_word(2)
    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(2))
    assert.are.equal('foo', env.state.registers.w)

    highlight.highlight_word(1)
    assert.are.equal('', highlight.get_hl_text(2))
    assert.are.equal('', env.state.registers.w)
    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(1))
    assert.are.equal('\\<\\Cfoo\\>', env.state.registers.q)
  end)

  it('does not clear a range highlight when toggling a word on the same label', function()
    env.state.buffer_text = { 'foo' }
    env.state.positions.v = { 0, 1, 1, 0 }
    env.state.positions.dot = { 0, 1, 3, 0 }

    highlight.highlight_range(1)
    assert.are.equal('\\Vfoo', highlight.get_hl_text(1))

    env.state.current_word = 'foo'
    highlight.highlight_word(1)

    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(1))
    assert.are.equal('\\<\\Cfoo\\>', env.state.registers.q)
  end)

  it('reapplies the same range instead of toggling it off', function()
    env.state.buffer_text = { 'foo' }
    env.state.positions.v = { 0, 1, 1, 0 }
    env.state.positions.dot = { 0, 1, 3, 0 }

    highlight.highlight_range(1)
    local first_pattern = highlight.get_hl_text(1)
    assert.are.equal('\\Vfoo', first_pattern)

    highlight.highlight_range(1)
    assert.are.equal(first_pattern, highlight.get_hl_text(1))
  end)

  it('exits visual mode after applying a range highlight', function()
    env.state.buffer_text = { 'foo' }
    env.state.positions.v = { 0, 1, 1, 0 }
    env.state.positions.dot = { 0, 1, 3, 0 }

    highlight.highlight_range(1)

    assert.are.same({ '<Esc>' }, env.state.inputs)
  end)

  it('uses line-based pattern for visual line mode', function()
    env.state.visual_mode = 'V'
    env.state.positions.v = { 0, 2, 1, 0 }
    env.state.positions.dot = { 0, 4, 1, 0 }

    highlight.highlight_range(1)

    assert.are.equal('\\c\\%>1l\\%<5l', highlight.get_hl_text(1))
  end)

  it('reads the current visual selection instead of reusing the previous one', function()
    env.state.buffer_text = { 'alpha beta gamma' }
    env.state.positions.v = { 0, 1, 1, 0 }
    env.state.positions.dot = { 0, 1, 5, 0 }

    highlight.highlight_range(1)
    assert.are.equal('\\Valpha', highlight.get_hl_text(1))

    env.state.positions.v = { 0, 1, 7, 0 }
    env.state.positions.dot = { 0, 1, 10, 0 }
    highlight.highlight_range(1)

    assert.are.equal('\\Vbeta', highlight.get_hl_text(1))
  end)

  it('clears the label when the cursor is on whitespace', function()
    env.state.current_word = 'foo'
    env.state.buffer_text = { 'foo bar' }
    env.state.positions.dot = { 0, 1, 1, 0 }

    highlight.highlight_word(1)
    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(1))

    env.state.current_word = ''
    env.state.positions.dot = { 0, 1, 4, 0 }
    highlight.highlight_word(1)

    assert.are.equal('', highlight.get_hl_text(1))
    assert.are.equal('', env.state.registers.q)
  end)

  it('clears the label when the cursor is on an empty line', function()
    env.state.current_word = 'foo'
    env.state.buffer_text = { 'foo' }
    env.state.positions.dot = { 0, 1, 1, 0 }

    highlight.highlight_word(1)
    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(1))

    env.state.current_word = ''
    env.state.buffer_text = { '' }
    env.state.positions.dot = { 0, 1, 1, 0 }
    highlight.highlight_word(1)

    assert.are.equal('', highlight.get_hl_text(1))
    assert.are.equal('', env.state.registers.q)
  end)

  it('treats single-line visual selections as literal patterns', function()
    env.state.buffer_text = { 'a.b' }
    env.state.positions.v = { 0, 1, 1, 0 }
    env.state.positions.dot = { 0, 1, 3, 0 }

    highlight.highlight_range(1)

    assert.are.equal('\\Va.b', highlight.get_hl_text(1))
    assert.are.equal('\\Va.b', env.state.registers.q)
  end)

  it('escapes backslashes in single-line visual selections', function()
    env.state.buffer_text = { 'a\\b' }
    env.state.positions.v = { 0, 1, 1, 0 }
    env.state.positions.dot = { 0, 1, 3, 0 }

    highlight.highlight_range(1)

    assert.are.equal('\\Va\\\\b', highlight.get_hl_text(1))
    assert.are.equal('\\Va\\\\b', env.state.registers.q)
  end)

  it('keeps pattern highlighting toggle behavior', function()
    highlight.highlight_text(1, 'TODO')
    assert.are.equal('TODO', highlight.get_hl_text(1))
    assert.are.equal('TODO', env.state.registers.q)

    highlight.highlight_text(1, 'TODO')
    assert.are.equal('', highlight.get_hl_text(1))
    assert.are.equal('', env.state.registers.q)
  end)
end)
