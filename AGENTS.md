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

## Behavior rules

Current intended default behavior:

- Normal mode:
  - `<Leader>1`..`<Leader>4` highlight the current word
  - pressing the same label on the same word toggles that word highlight off
  - pressing a different label on the same word moves that word highlight to the new label
- Visual mode:
  - `<Leader>1`..`<Leader>4` highlight the visual selection
  - visual highlights overwrite the target label and do **not** toggle
- `<Leader>0` clears all highlights
- Pattern highlighting via commands/API keeps same-pattern toggle behavior

Important implementation detail:

- Word toggle/move logic only compares against other highlights with `kind == 'word'`
- Word highlighting does **not** try to reason about overlap with visual or pattern highlights
- Highlight state is window-local (`vim.w`)

Current label/register mapping in `lua/easyhl/util.lua`:

- label 1 -> register `q`
- label 2 -> register `w`
- label 3 -> register `e`
- label 4 -> register `r`

## Working rules

- Use 2 spaces for indentation.
- Keep edits minimal and targeted.
- Prefer preserving existing API/command compatibility unless the user explicitly asks to break it.
- Do not remove existing `<Plug>` mappings unless there is a strong reason and the user asked for it.
- If changing user-visible behavior, update both:
  - `README.md`
  - `doc/easyhl.txt`
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

## When stuck

If behavior around word vs visual vs pattern interaction is ambiguous, do not guess. Write down the exact interaction matrix and confirm it with the user before changing semantics.
