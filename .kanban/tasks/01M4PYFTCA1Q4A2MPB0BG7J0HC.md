---
assignees:
- claude-code
position_column: todo
position_ordinal: 8d80
title: 'Move to EditorKit 95ef6c4: prose font, diff text, editor font, terminal palette and color runs'
---
## What
EditorKit pushed the theme gaps to main at 95ef6c4292f8a7941e1a95702acc1bc01980e437 (2026-10-11). The kit must use the new roles, so that the EditorKit theme is the only theme (owner decision, ^3c1k7g8).

New and changed EditorKit API (module EditorTheme unless stated):
- `Theme.proseFont: Font` (default `Font.body`).
- `Theme.diffAddedText` / `Theme.diffRemovedText: Color` (systemGreen / systemRed, full opacity).
- The TextKit editor draws in `Theme.editorFont`. New `EditorTextFont`. BREAKING: the `lineHeight` parameter of `EditorView`, `EditorContributor`, `SingleLineField`, `TokenField` and `EditorSearchField` is now `CGFloat?`; `nil` means the row of the theme font. `defaultEditorLineHeight` is now 16 pt on macOS (was 18).
- ANSI: `EditorColorRun(range:foreground:background:)`, `EditorColorRun.runs(in: AttributedString, startingAt:)`; `EditorModel.colorRuns`, `setColorRuns(_:)`, `addColorRuns(_:)` (macOS only; replacing the whole text clears the runs). `Theme.terminalPalette: TerminalPalette` with `ansiColor(_:)` for SGR 0-15 and `palette[.foreground]` / `palette[.background]`.
- `Theme.severityHint: Color`.
- SystemTheme syntax palette changed; VS Code accent order changed; `Color.accentColor` stays the accent (on macOS it does not follow `.tint(_:)`).

## Work
- [ ] Move the EditorKit pin to 95ef6c4 (or later main). Fix the breaking `lineHeight` changes. Check the hosted layout tests that depend on the 18 pt row.
- [ ] Remove `AgentTheme.proseFont`; prose reads `editorTheme.proseFont`.
- [ ] The diff `+N/−N` counts read `diffAddedText` / `diffRemovedText` (remove the kit `Theme+DiffText` workaround if it becomes dead).
- [ ] Remove any kit code font override that the editor now takes from `editorFont`.
- [ ] `Terminal/ANSIText.swift`: map SGR 0-15 through `theme.terminalPalette.ansiColor(_:)` (remove the fixed hex palette), keep the 256-color and RGB codes, and give the runs to the terminal and command output editors with `EditorColorRun.runs(in:startingAt:)` and `setColorRuns` / `addColorRuns`, so terminal colors show (today SGR colors are dropped in the editor). Use the terminal palette foreground and background for the terminal frame.
- [ ] Use `severityHint` where the kit shows a hint severity, if any.
- [ ] Tests for each change (pixel tests with a custom theme where useful). Update `comparison.md` and the docs that mention the kit prose font, the ANSI palette or the row height.