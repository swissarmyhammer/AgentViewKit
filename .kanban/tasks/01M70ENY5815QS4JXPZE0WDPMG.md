---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: 'The host pads the bars: AVK bars read \.barInsets'
---
The user rule (request from editorkit-9f, 2026-11-09): the kanban and the chat are not padded. The host pads them where it mounts them. The bar inset is a theme setting (EditorKit `EditorStyle.bar`, `\.barInsets`, `.barInsets()`).

## What to do
- AgentThreadView: the top bar is one VStack(spacing: tile.margin) with the header and the banners, padded as a whole by `\.barInsets`. The bottom bar (floating controls) is padded by `\.barInsets`. Remove `barEdgeInset`.
- ConversationView (standalone): the bottom bar (StateBanner) is padded by `\.barInsets`.
- Do not change content paddings: the list rows (`rowPadding`), `headerInset` and the pill padding.
- Hosts in AVK (the demo app, the screenshot tests, the gallery) write `.barInsets()` where they mount a thread.
- Add a test that fails before the change: with no `.barInsets()` the bar has no inset; with `.barInsets()` the bar content stands at `style.bar` from the edges.

## Accepted changes of the look (editorkit-9f)
- The bottom bar of AgentThreadView gets spacing.s above and below the composer (it was spacing.m).
- The standalone ConversationView bottom bar gets spacing.m at the sides (it was spacing.s).
- The gap between the header and the first banner is tile.margin (it was 16 pt).

## Acceptance
- [ ] The new test passes, and it fails before the change.
- [ ] Unit, integration and screenshot suites pass.