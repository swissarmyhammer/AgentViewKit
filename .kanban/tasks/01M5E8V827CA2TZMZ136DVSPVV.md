---
assignees:
- claude-code
depends_on:
- 01M5E8TFNDT9Q9WE6C2D6YW9PP
position_column: todo
position_ordinal: a680
title: 'AVK-8ac Header rows of code blocks, terminal and command output: remove the statusBarBackground fill (EditorBlockChrome.swift:54) and put a .separator line under the header (D113 answer 4)'
---
## Why

D113 answer 4 and `style.md` "How the steps apply": "A header row inside content (the header of a code block, a terminal or command output) is content, not a bar. It has no fill. A `.separator` line under it marks it."

Today `EditorBlockBar` fills the header row with `editorTheme.statusBarBackground` (`Sources/AgentViewKit/Code/EditorBlockChrome.swift:47-56`, `:74-79`).

## Files and lines

- `Sources/AgentViewKit/Code/EditorBlockChrome.swift:47-56` (`EditorBlockBar`), `:74-79` (`editorBlockBar()`).
- Users: `Sources/AgentViewKit/Code/CodeBlockView.swift:113`, `Sources/AgentViewKit/Terminal/TerminalView.swift:220`, `Sources/AgentViewKit/Content/CommandOutputView.swift:230`.
- Test: `Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift:55`, `:63`, `:72` (they expect or forbid `Role.statusBarBackground`).

## What to do

- [ ] Change the modifier so that it draws no background. It draws a `.separator` line under the row (for example `.overlay(alignment: .bottom) { Divider() }`, or a 1-point `Rectangle().fill(.separator)` with the height of the display scale). Use a system `Divider` if it gives the separator color.
- [ ] Rename the modifier and the function so that the name does not say "bar" (for example `EditorBlockHeader` and `editorBlockHeader()`). Change the three users.
- [ ] Change the DocC comment: the header row is content, not a bar; it has no fill; a separator line marks it (D113).
- [ ] Change `EditorThemeViewsTests`: the code block, the terminal and the command output show no `Role.statusBarBackground` pixel. Add one check that a row of pixels under the header is not the color of the content above it (the separator line).

## Acceptance

- No `statusBarBackground` in `Sources/AgentViewKit`.
- The changed `EditorThemeViewsTests` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8