---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7neqnh63k1217pb518hb32w
  text: 'Decision from testudoapp-75: images use `FileImageSource` relative to the cwd of the session; nothing outside that folder. Links: a click calls `openURL`, and the host decides. AVK opens no URL itself.'
  timestamp: 2026-11-17T19:11:26.758255+00:00
position_column: todo
position_ordinal: '8580'
title: 'AVK-9.6: Images and links in chat Markdown'
---
D185.
- Links: a click calls the SwiftUI environment `openURL`. Check that `citationScope()` and the host `openURL` get the clicks.
- Images: give `.editorImageSource(_:relativeTo:)` for the session folder (`FileImageSource`), or give no source, so that each image shows its alt text. Decide with testudoapp which one.

Acceptance: unit tests.

#avk-9