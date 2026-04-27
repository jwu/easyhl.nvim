# EasyHL

A Neovim plugin for temporary highlighting of words and text ranges.

## Features

- Highlight words under cursor with 4 distinct color labels
- Highlight visual selections
- Pattern-based highlighting
- Auto cursor highlight (optional)
- Register integration for search/replace workflows
- Full Lua API with type annotations
- `<Plug>` mappings for custom keybindings

## Requirements

- Neovim 0.11 or higher

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

### Highlight Words

Move your cursor to a word and press:
- `<Leader>1` through `<Leader>4` to highlight with different colors
- Press the same mapping again on the same word to toggle that label off
- Press a different label on the same word to move the word highlight to that label

### Highlight Visual Selection

Select text in visual mode and press:
- `<Leader>1` through `<Leader>4` to highlight the selection
- Single-line visual selections are highlighted as literal text patterns
- Multi-line and visual-line selections are highlighted as ranges
- Visual highlights always overwrite the target label and do not toggle

### Cancel Highlights

- `<Leader>0` to cancel all highlights
- Use `:Easyhl cancel {label}` or `<Plug>(EasyhlCancel1-4)` for individual cancellation

### Replace Words

When you have Label 1 and Label 2 highlighted:
- Press `<Leader>sub` to replace all Label 1 words with Label 2

## Configuration

```lua
require('easyhl').setup({
  auto_cursorhl = false,  -- Auto-highlight word under cursor
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

## Custom Keybindings

Use `<Plug>` mappings to create your own keybindings:

```lua
vim.keymap.set('n', '<leader>h1', '<Plug>(EasyhlWord1)')
vim.keymap.set('n', '<leader>h2', '<Plug>(EasyhlWord2)')
vim.keymap.set('v', '<leader>h1', '<Plug>(EasyhlRange1)')
vim.keymap.set('n', '<leader>c1', '<Plug>(EasyhlCancel1)')
vim.keymap.set('n', '<leader>cc', '<Plug>(EasyhlCancelAll)')
```

Available `<Plug>` mappings:

| Mapping | Mode | Description |
|---------|------|-------------|
| `<Plug>(EasyhlWord1-4)` | Normal | Highlight/toggle word |
| `<Plug>(EasyhlRange1-4)` | Visual | Highlight selection |
| `<Plug>(EasyhlCancel1-4)` | Normal | Cancel label |
| `<Plug>(EasyhlCancelAll)` | Normal | Cancel all |

## Commands

```vim
" New subcommand pattern
:Easyhl word 1          " Highlight word with label 1
:Easyhl range 2         " Highlight selection with label 2
:Easyhl cancel 0        " Clear all highlights
:Easyhl hl1 TODO        " Highlight pattern with label 1

" Legacy commands (backward compatible)
:EasyhlWord 1
:EasyhlCancel 1
:EasyhlRange 1
:HL1 pattern
```

## Lua API

```lua
local easyhl = require('easyhl')

-- Highlight word under cursor
easyhl.highlight_word(1)

-- Highlight pattern
easyhl.highlight_text(1, 'TODO')

-- Highlight visual selection
easyhl.highlight_range(1)

-- Clear highlights
easyhl.clear(1)     -- Clear label 1
easyhl.clear(0)     -- Clear all
easyhl.clear_all()  -- Clear all

-- Get current pattern
local pattern = easyhl.get_hl_text(1)
```

## Development

### Tests

This project includes `busted` specs under `tests/`.

If you have `busted` installed, run:

```sh
busted tests
```

## Health Check

Run `:checkhealth easyhl` to diagnose issues.

## Documentation

See `:help easyhl` for full documentation.
