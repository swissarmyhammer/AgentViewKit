---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: 'Terminal blocks stay clear: remap ANSI black/white so they contrast with whatever shows through'
---
The user's decision, relayed by testudoapp-2c on 2026-10-23: "Terminal blocks: clear, fix the contrast."

Since EditorKit ^0apj6a2 (in AVK at 3bc9d3e), the default terminal palette background (SGR 49) is clear. So `TerminalBlockFrame` (Sources/AgentViewKit/.../EditorBlockChrome.swift:49-52) draws no fill under the default SystemTheme. But ANSI black (SGR 30) maps to the system text-background color, so black output is nearly invisible on a white or #1E1E1E app background (measured in ^xqday3k). White (37/97) has the same problem in Light.

## What to do
- [ ] Keep TerminalBlockFrame clear under the default theme: no fill (the user's transparent-by-default rule).
- [ ] When the theme does NOT set `terminal.background`, remap the colors that can collide with the background so they always contrast with what shows through: SGR 30/90 (black, bright black) and 37/97 (white, bright white), foreground AND background uses, to label-relative system colors (e.g. `.labelColor` / `.secondaryLabelColor`, and their inverse where an SGR background needs contrast with the text on it). Pick the exact mapping, write it down in the code doc, and keep it dynamic so Light, Dark and Increase Contrast all work.
- [ ] Decide where the remap lives: the AVK terminal palette adapter, or a proposal to EditorKit if the palette is EditorKit's. If it belongs in EditorKit, ask editorkit-28 rather than editing that repo.
- [ ] A theme that sets `terminal.background` keeps its fill AND its palette unchanged.
- [ ] Hosted tests (red first): under the default theme, black and white text each have a measurable contrast against the window background in Light and Dark; the frame has no fill; with a `terminal.background` theme, the fill and the original palette stay.
- [ ] Re-record only the terminal snapshots that change, and list them.

Acceptance: full `swift test` green; the demo builds. #avk-8 #testudo-request