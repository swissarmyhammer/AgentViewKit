---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7ty00e64xrtdxec6pwrh1wa
  text: 'API approved by testudoapp-9a (2026-11-19): `View.threadHeader { }` and `View.threadUnavailable(_ message: String?)`, both environment values that chain with sideCards and transcriptSearchHits. (a) In the unavailable state, the read verbs (Copy Thread, Export as Markdown…, Find Next Hit, Find Previous Hit, Clear Search Hits) are not available, with the reason "The session is not available.". (b) A String is enough; the actions there (for example Remove from Shared with Me) are app commands in the palette and the menus (D108), not buttons in the message. Still waits for the ACPClient D208 sha (through the read-only task).'
  timestamp: 2026-11-19T22:14:20.870537+00:00
depends_on:
- 01M7TXYBHYBWSSF13012HB20S8
position_column: todo
position_ordinal: '8180'
title: Thread header slot and the unavailable state for a shared session (D208 i)
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/share/avk-brief.md, items 2 and 3. Do this after the task "Read-only thread for a shared session".

Do:
- A header slot above the thread that the host fills, for "Shared by <name> · Updated <date>". AVK gives the slot, not the text: the app gives the text and the strings. API (proposed): `View.threadHeader { ... }`, an environment value that the thread reads, so it chains with `sideCards(_:)` and `transcriptSearchHits(_:)`.
- An unavailable state: the host sets a message, and the thread shows the text in place of the transcript (for "The owner stopped sharing this session."). API (proposed): `View.threadUnavailable(_ message: String?)`; nil shows the transcript. The header stays.
- D110: no glass in the content. Accessibility: the header is a group with the host label; the unavailable text is a static text.

Tests (unit, no window): the header slot shows the host view; the unavailable state shows its text and hides the transcript; nil shows the transcript. A screenshot test of the read-only chat with the header, in light and dark (ScreenshotTests: compile only, do not run; give the PNG paths).

Push when `swift test` is green, and send the sha to testudoapp-9a.