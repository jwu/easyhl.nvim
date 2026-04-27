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

    highlight.highlight_word(1)
    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(1))
    assert.are.equal('\\<\\Cfoo\\>', env.state.registers.q)

    highlight.highlight_word(1)
    assert.are.equal('', highlight.get_hl_text(1))
    assert.are.equal('', env.state.registers.q)
  end)

  it('moves a word highlight from another label', function()
    env.state.current_word = 'foo'

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
    env.state.visual_text = 'foo'

    highlight.highlight_range(1)
    assert.are.equal('\\cfoo', highlight.get_hl_text(1))

    env.state.current_word = 'foo'
    highlight.highlight_word(1)

    assert.are.equal('\\<\\Cfoo\\>', highlight.get_hl_text(1))
    assert.are.equal('\\<\\Cfoo\\>', env.state.registers.q)
  end)

  it('reapplies the same range instead of toggling it off', function()
    env.state.visual_text = 'foo'

    highlight.highlight_range(1)
    local first_pattern = highlight.get_hl_text(1)
    assert.are.equal('\\cfoo', first_pattern)

    highlight.highlight_range(1)
    assert.are.equal(first_pattern, highlight.get_hl_text(1))
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
