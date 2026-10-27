---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5zawaxwq7n9v2r86s6g73pg
  text: |-
    ### Decision by the user, 2026-10-27: keep the colours; they must be theme-settable
    The user, verbatim: "the colors i've seen look great, but they should be theme settable".
    - The EditorKit default `statusPending` stays as it is. No EditorKit default change.
    - It is already theme-settable: `statusPending` is an `EditorTheme` role (EditorKit `Sources/EditorTheme/Theme.swift:90`), and AVK reads status colours through `editorTheme.statusColor(for:)`.
    - Archived: nothing left to do.
  timestamp: 2026-10-27T18:45:06.108383+00:00
position_column: todo
position_ordinal: a380
title: 'AVK-8 status symbol: give the pending status symbol at least 3:1 contrast in light and dark (finding of ^8q34yt8)'
---
Found by the review gallery of ^8q34yt8 (2026-10-27).
- Screen: `request-deck` (the pending tool call "Run swift test", trailing status symbol). Variants: light and dark. PNGs: `~/Library/Caches/AgentViewKit/screenshot-check/request-deck--light.png`, `request-deck--dark.png`.
- View: the status symbol of a pending tool call (`ToolCallView`, color from `statusColor(for: ToolCallStatus)` in `Theme+StatusRoles.swift`).

What the image shows: the pending symbol is the gray RGB bdbdbd on the light window background (1.9:1) and RGB 565656 on the dark one (2.3:1). A symbol that tells a state needs at least 3:1, and the chevron beside it reaches 3.9:1 and 5.9:1. The kit maps `.pending` to the theme role `statusPending`, whose EditorKit default (`ThemeRoleDefaults.pending`) is the tertiary label color.

Files: `Sources/AgentViewKit/Theme/Theme+StatusRoles.swift`; the EditorKit default lives in EditorKit `Sources/EditorTheme/Theme.swift` (`ThemeRoleDefaults.pending`).

What to change: make the pending symbol reach 3:1 in both variants. The proposed change is in EditorKit: the default of `statusPending` becomes the secondary label color; then update the EditorKit pin of AVK. `statusPending` is a theme role that a host can set, so do not hard-code a color in AVK. Ask the user to confirm the EditorKit change before it is made.

Deterministic test: a hosted test renders a pending `ToolCallView` with the default theme in the light and the dark variant (`ViewSnapshot.hostedPixels`), and requires that the strongest color in the frame of the status symbol has a contrast of at least 3:1 with the window background (`RenderedPixels`). No clock and no wait.
#avk-8