---
assignees:
- claude-code
position_column: todo
position_ordinal: a180
title: 'AVK-8 status labels: draw the text of "Sent" and "Exit code" in a readable color, and keep the status color on the symbol (finding of ^8q34yt8)'
---
Found by the review gallery of ^8q34yt8 (2026-10-27).
- Screens: `sign-in`, `banners`, `scrolled` (the "Sent" label of each user message) and `thread`, `inspector` (the "Exit code 0" label of the terminal output). Variant: light. PNGs: `~/Library/Caches/AgentViewKit/screenshot-check/sign-in--light.png`, `banners--light.png`, `scrolled--light.png`, `thread--light.png`.
- Views: `UserMessageView.SendStateLabel` and `OutputExitLabel` (used by `TerminalView` and `CommandOutputView`).

What the image shows: the whole label, the caption text included, is drawn in `statusSucceeded`: RGB 34c759 on the light window background, a contrast of 2.2:1. That is far below the system secondary label color (RGB 808080, 3.9:1), which the kit uses for other secondary text. In dark the color is RGB 30d158, 8.2:1, so only the light variant is hard to read.

Files: `Sources/AgentViewKit/Items/UserMessageView.swift` (`SendStateLabel`), `Sources/AgentViewKit/Content/OutputChrome.swift` (`OutputExitLabel`).

What to change: put the status color on the symbol only, and draw the title in `.secondary`. Remove the cause in each of the two files: no `Label` that tints its text with a status role (`statusColor(for:)`).

Deterministic test: hosted tests render `SendStateLabel(state: .sent)` and the `OutputExitLabel` of exit code 0 with `ViewSnapshot.hostedPixels` in the light variant. In the accessibility frame of the text, with the frame of the symbol left out, no pixel is close to `statusSucceeded`; the frame of the symbol has such a pixel. No clock and no wait.
#avk-8