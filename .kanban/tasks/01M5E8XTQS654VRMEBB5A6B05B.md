---
assignees:
- claude-code
depends_on:
- 01M5E8XMJXF8XABYA7P3ZGM5SF
position_column: todo
position_ordinal: b080
title: 'AVK-8am Thread top bar: put AgentInfoHeader and the top banners in a top .safeAreaBar, so the list scrolls under the toolbar with the scroll edge effect (D113 answer 7)'
---
## Why

D113 answer 7 and `style.md` rule 3: "Scroll views go under the toolbar with the scroll edge effect." `style.md` "Scroll under the bars": "The headers and the banners at the top are in a top bar."

Today `AgentInfoHeader`, `AgentConnectionBanner`, `SessionNoticeBanner` and `SessionStreamBanner` are above `ConversationView` in the `VStack` of `AgentThreadView.content` (`Sources/AgentViewKit/Thread/AgentThreadView.swift:207-213`). Thus the list starts under them and does not go under the toolbar.

## What to do

- [ ] Move these four views into `.safeAreaBar(edge: .top) { ... }` on the content of `AgentThreadView`, in the same order. The `VStack` then holds only `ConversationView`. Do not add a background to the bar (D112 (e), style.md rule 1).
- [ ] Do not set `.scrollEdgeEffectStyle` unless the screenshot check asks for it: the default soft effect is correct for a transcript (`.hard` is for a dense editor, style.md rule 3).
- [ ] Keep the accessibility identifiers and the VoiceOver order (header, banners, list, bottom bar).
- [ ] Change the doc comment of `content`.

## Acceptance

- A structure test of `AgentThreadView.swift` (code lines only): `AgentInfoHeader(`, `AgentConnectionBanner(`, `SessionNoticeBanner(` and `SessionStreamBanner(` show only inside the `.safeAreaBar(edge: .top)` closure.
- A hosted layout test (the method of AVK-8al): in an `AgentThreadView` with a connection and a notice, the top of the scroll view frame is the top of the thread view frame, and the header frame is inside the scroll view frame.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8