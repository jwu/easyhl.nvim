# EasyHL

A Neovim plugin for temporary, window-local highlighting of words, visual selections, and patterns.

## Features

- Highlight words under cursor with 4 distinct color labels
- Toggle a word highlight off by pressing the same label again
- Move a word highlight to another label by pressing a different label on the same word
- Highlight visual selections, including multi-line, blockwise, and linewise selections
- Highlight arbitrary Vim patterns with commands, `<Plug>` mappings, or the Lua API
- Register integration for quick substitute workflows
- `<Plug>` mappings for custom keybindings
- `:checkhealth easyhl` support

## Requirements

- Neovim 0.11+

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'jwu/easyhl.nvim',
  event = 'VeryLazy',
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use { 'jwu/easyhl.nvim' }
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'jwu/easyhl.nvim'
```

## Usage

### Highlight words

Move your cursor to a word and press:

- `<Leader>1` through `<Leader>4` to highlight with different labels
- Press the same label again on the same word to toggle that word highlight off
- Press a different label on the same word to move the word highlight to that label

Word highlighting is window-local.

### Highlight a visual selection

Select text in visual mode and press `<Leader>1` through `<Leader>4`.

Behavior depends on the selection type:

- Single-line characterwise selections are highlighted as literal text patterns
- Multi-line characterwise selections are highlighted as exact positions
- Blockwise selections are highlighted as exact positions per line
- Linewise selections are highlighted as whole-line ranges

Visual highlights always overwrite the target label and do not toggle.

### Highlight a pattern

Use commands, `<Plug>` mappings, or the Lua API to highlight a Vim pattern.

- Applying the same pattern to the same label toggles it off
- Patterns without uppercase letters are matched case-insensitively
- Patterns containing uppercase letters keep Vim's case-sensitive behavior

### Clear highlights

- `<Leader>0` clears all highlights
- `:Easyhl cancel {label}` clears one label
- `:Easyhl cancel 0` clears all labels
- `<Plug>(EasyhlCancel1-4)` clears one label
- `<Plug>(EasyhlCancelAll)` clears all labels

### Replace label 1 with label 2

When default mappings are enabled:

- `<Leader>sub` runs a substitute using register `q` as the search text and register `w` as the replacement text
- By default, label 1 writes to register `q` and label 2 writes to register `w`

Label/register mapping:

- Label 1 -> `q`
- Label 2 -> `w`
- Label 3 -> `e`
- Label 4 -> `r`

## Configuration

```lua
require('easyhl').setup({
  colors = {
    EasyHLLabel1 = { bg = 'LightCyan' },
    EasyHLLabel2 = { bg = 'LightMagenta' },
    EasyHLLabel3 = { bg = 'LightRed' },
    EasyHLLabel4 = { bg = 'LightGreen' },
  },
})
```

To disable default mappings:

```vim
let g:easyhl_no_mappings = 1
```

## Custom keybindings

Use `<Plug>` mappings to define your own keys:

```lua
vim.keymap.set('n', '<leader>h1', '<Plug>(EasyhlWord1)')
vim.keymap.set('v', '<leader>h1', '<Plug>(EasyhlRange1)')
vim.keymap.set('n', '<leader>c1', '<Plug>(EasyhlCancel1)')
vim.keymap.set('n', '<leader>p1', '<Plug>(EasyhlHL1)')
vim.keymap.set('n', '<leader>cc', '<Plug>(EasyhlCancelAll)')
```

Available `<Plug>` mappings:

| Mapping | Mode | Description |
|---------|------|-------------|
| `<Plug>(EasyhlWord1-4)` | Normal | Highlight/toggle word |
| `<Plug>(EasyhlRange1-4)` | Visual | Highlight selection |
| `<Plug>(EasyhlCancel1-4)` | Normal | Clear one label |
| `<Plug>(EasyhlCancelAll)` | Normal | Clear all labels |
| `<Plug>(EasyhlHL1-4)` | Normal | Prompt for a pattern and highlight it |

## Commands

Main command:

```vim
:Easyhl word 1
:Easyhl range 2
:Easyhl cancel 0
:Easyhl hl1 TODO
:Easyhl hl1
```

Subcommands:

- `word {label}`: highlight word under cursor
- `range {label}`: highlight the current visual selection
- `cancel {label}`: clear one label, or `0` for all labels
- `hl1 {pattern}` ... `hl4 {pattern}`: highlight a pattern for the matching label; omitting `{pattern}` clears that label

Legacy commands remain available:

```vim
:EasyhlWord 1
:EasyhlCancel 1
:EasyhlRange 1
:HL1 TODO
:HL1
```

## Lua API

```lua
local easyhl = require('easyhl')

-- Configure highlight groups
easyhl.setup({
  colors = {
    EasyHLLabel1 = { bg = 'Yellow' },
  },
})

-- Highlight word under cursor
easyhl.highlight_word(1)

-- Highlight a pattern
easyhl.highlight_text(1, 'TODO')

-- Highlight current visual selection
easyhl.highlight_range(1)

-- Clear one label or all labels
easyhl.clear(1)
easyhl.clear(0)
easyhl.clear_all()

-- Read the stored text/pattern for a label
local value = easyhl.get_hl_text(1)
```

API notes:

- `highlight_text(label, '')` clears that label
- `get_hl_text(label)` returns the stored match string for that label
- for position-based visual highlights, that stored value is an internal serialized position string rather than plain selected text

## Health check

Run:

```vim
:checkhealth easyhl
```

## Development

Tests live under `tests/` and use `busted`.

```sh
busted tests
```

## Documentation

See `:help easyhl` for full vimdoc.
