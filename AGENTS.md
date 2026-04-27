# AGENTS.md

## Project

This repository is `easyhl.nvim`, a Neovim plugin written in Lua for temporary highlighting of words, visual selections, and patterns.

The project targets:

- Neovim `0.11+`
- Lua plugin conventions for Neovim
- small, focused changes that preserve backward-compatible commands and `<Plug>` mappings

## Key structure

- `plugin/easyhl.lua`
  - auto-loaded plugin entry
  - defines highlight groups on startup/colorscheme change
  - registers `<Plug>` mappings
  - registers default mappings
  - registers user commands
- `lua/easyhl/init.lua`
  - public Lua API surface
- `lua/easyhl/highlight.lua`
  - core highlight behavior and window-local state
- `lua/easyhl/util.lua`
  - helper utilities and label/register mapping
- `lua/easyhl/config.lua`
  - user config merge logic
- `lua/easyhl/health.lua`
  - `:checkhealth easyhl`
- `doc/easyhl.txt`
  - vim help doc; keep in sync with user-visible behavior
- `README.md`
  - user-facing overview and examples
- `tests/`
  - busted tests

## Current behavior snapshot

Current intended default behavior:

- Normal mode:
  - `<Leader>1`..`<Leader>4` highlight the current word
  - pressing the same label on the same word toggles that word highlight off
  - pressing a different label on the same word moves that word highlight to the new label
- Visual mode:
  - `<Leader>1`..`<Leader>4` highlight the visual selection
  - single-line characterwise selections use a literal pattern highlight
  - multi-line characterwise selections use position-based highlights
  - blockwise selections use position-based highlights per line
  - linewise selections use a whole-line pattern range
  - visual highlights overwrite the target label and do **not** toggle
- Pattern highlighting:
  - available via `:Easyhl hl1`..`hl4`, legacy `:HL1`..`:HL4`, `<Plug>(EasyhlHL1-4)`, and Lua API
  - applying the same pattern to the same label toggles it off
  - empty pattern clears the label
  - patterns without uppercase are prefixed with `\c`
- Clearing:
  - `<Leader>0` clears all highlights
  - `:Easyhl cancel {label}` and `:EasyhlCancel {label}` clear one label
  - label `0` clears all highlights
- Replace workflow:
  - `<Leader>sub` uses registers from label 1 and label 2 in substitute commands
  - default mapping is normal `:%s/<c-r>q/<c-r>w/g<CR><c-o>` and visual `:s/<c-r>q/<c-r>w/g<CR><c-o>`

Important implementation detail:

- Highlight state is window-local (`vim.w`)
- Word toggle/move logic only compares against other highlights with `kind == 'word'`
- Word highlighting does **not** try to reason about overlap with visual or pattern highlights
- Position-based visual highlights store serialized positions in `vim.w.ex_hl_text[label]`
- Label 2 and label 4 strip `\<\C` / `\>` word boundaries before writing to registers

Current label/register mapping in `lua/easyhl/util.lua`:

- label 1 -> register `q`
- label 2 -> register `w`
- label 3 -> register `e`
- label 4 -> register `r`

## Public surface

Commands:

- `:Easyhl word {label}`
- `:Easyhl range {label}`
- `:Easyhl cancel {label}`
- `:Easyhl hl1 [{pattern}]`
- `:Easyhl hl2 [{pattern}]`
- `:Easyhl hl3 [{pattern}]`
- `:Easyhl hl4 [{pattern}]`
- legacy: `:EasyhlWord`, `:EasyhlCancel`, `:EasyhlRange`, `:HL1`..`:HL4`

`<Plug>` mappings:

- normal: `<Plug>(EasyhlWord1-4)`
- visual: `<Plug>(EasyhlRange1-4)`
- normal clear: `<Plug>(EasyhlCancel1-4)`, `<Plug>(EasyhlCancelAll)`
- normal pattern prompt: `<Plug>(EasyhlHL1-4)`

Lua API in `lua/easyhl/init.lua`:

- `setup(opts)`
- `highlight_word(label)`
- `highlight_text(label, pattern)`
- `highlight_range(label)`
- `clear(label)`
- `clear_all()`
- `get_hl_text(label)`

Config in `lua/easyhl/config.lua`:

- `setup({ colors = { ... } })`
- currently only `colors` is supported

## Working rules

- Use 2 spaces for indentation.
- Keep edits minimal and targeted.
- Prefer preserving existing API/command compatibility unless the user explicitly asks to break it.
- Do not remove existing `<Plug>` mappings unless there is a strong reason and the user asked for it.
- If changing user-visible behavior, update both:
  - `README.md`
  - `doc/easyhl.txt`
- If changing agent-facing behavior snapshot or public surface, update `AGENTS.md` too.
- If changing core logic in `lua/easyhl/highlight.lua`, add or update busted tests.

## Commands

Useful validation commands:

```sh
busted tests
lua -e "assert(loadfile('lua/easyhl/highlight.lua')); assert(loadfile('plugin/easyhl.lua'))"
```

If `stylua` is installed, format changed Lua files:

```sh
stylua lua plugin tests
```

## Testing notes

- Tests use `busted`.
- Current tests use a lightweight mocked `vim` object in `tests/helpers/mock_vim.lua`.
- Prefer unit tests for core behavior in `lua/easyhl/highlight.lua` instead of requiring a full Neovim instance unless necessary.

When adding tests for new behavior, prioritize:

- word toggle
- word move between labels
- visual overwrite behavior
- pattern toggle behavior
- clear/reset behavior
- multiline, blockwise, and linewise range handling

## Safety / ask first

Ask before doing any of the following:

- changing public command names or removing legacy commands
- removing backward-compatible behavior
- changing register semantics (`q/w/e/r`)
- changing default mappings beyond what the user requested
- introducing new runtime dependencies
- large refactors unrelated to the requested task

## Preferred patterns

- Keep plugin startup light.
- Reuse helper functions and shared state transitions instead of duplicating logic.
- Store explicit metadata when behavior depends on highlight origin/type.
- Favor predictable behavior over overly clever cross-mode inference.
- Keep README and vimdoc aligned with actual command and mapping behavior.

## When stuck

If behavior around word vs visual vs pattern interaction is ambiguous, do not guess. Write down the exact interaction matrix and confirm it with the user before changing semantics.
