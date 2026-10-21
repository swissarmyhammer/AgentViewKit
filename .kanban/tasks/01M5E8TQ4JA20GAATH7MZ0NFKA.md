---
assignees:
- claude-code
depends_on:
- 01M5E8TFNDT9Q9WE6C2D6YW9PP
position_column: todo
position_ordinal: a480
title: 'AVK-8aa Open question first, then do: does the terminal and command output frame keep the TerminalPalette background fill (EditorBlockChrome.swift:43)?'
---
## Why

D113 answer 1 removes the fills of content cards. D113 answer 8 says that the terminal colors 0 to 15 come from the theme's `TerminalPalette`. The terminal frame fills the block with `palette[.background]` and sets the foreground to `palette[.foreground]` (`Sources/AgentViewKit/Code/EditorBlockChrome.swift:36-44`, users `Terminal/TerminalView.swift` and `Content/CommandOutputView.swift`). The ANSI colors of the output are chosen for that background.

D113 does not say if the terminal background is a "custom fill" (it goes) or terminal data, like the ANSI colors (it stays). If the fill goes and the palette is dark, the light terminal foreground and ANSI colors can have a low contrast on a light window.

## What to do

- [ ] Write a comment on this card with the question to the person, the two choices and the risk above. Do not change code before the person answers.
- [ ] Choice A (no fill): `TerminalBlockFrame` uses `editorBlockFrame()` with no fill. The default foreground of the output is `.primary`, not `palette[.foreground]`. The ANSI colors 0 to 15 still come from the palette.
- [ ] Choice B (keep): the terminal background is terminal data. Keep the fill. Add a code comment that names D113 and the answer, and add the file to the allow list of AVK-8r with that reason.
- [ ] Do the chosen choice. In both choices, the frame calls no `agentContentSurface`.

## Acceptance

- The comment with the answer of the person is on this card.
- Choice A: `EditorThemeViewsTests` (`:66-73`, the terminal test) expects no `Role.terminalBackground` pixel in the block frame. Choice B: the test expects it, as today, and AVK-8r allows it with the reason.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8