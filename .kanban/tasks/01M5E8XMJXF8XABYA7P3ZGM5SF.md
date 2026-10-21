---
assignees:
- claude-code
depends_on:
- 01M5E8WMM146Y611ZQDZM1HM5Q
- 01M5E8X2DC7CT94TQJG2G7W4MZ
position_column: todo
position_ordinal: af80
title: 'AVK-8al Thread bottom bar: put StateBanner and AgentLoginPrompt in the bottom .safeAreaBar with the composer, so the list scrolls under them (D113 answer 7)'
---
## Why

D113 answer 7 and `style.md` "Scroll under the bars": "The list of a view scrolls under its bars. A banner or a prompt next to a bar is in the same bar (`.safeAreaBar(edge:)`), not between the list and the bar."

Today:
- `StateBanner` is under the list in the `VStack` of `ConversationView` (`Sources/AgentViewKit/Thread/ConversationView.swift:195-206`, banner at `:204-205`).
- `AgentLoginPrompt` is under `ConversationView` in the `VStack` of `AgentThreadView.content` (`Sources/AgentViewKit/Thread/AgentThreadView.swift:218-220`).
- The bottom bar is `.safeAreaBar(edge: .bottom) { floatingControls }` (`AgentThreadView.swift:222`, `floatingControls` at `:235-247`).

## What to do

- [ ] Copy the method of the pill (`\.conversationShowsPill`, `AgentThreadView.swift:217`, `ConversationView.swift:259-262`): add an internal environment value (for example `\.conversationShowsStateBanner`, default `true`). When it is `true`, a standalone `ConversationView` puts `StateBanner` in its own `.safeAreaBar(edge: .bottom)` of the list, not in the `VStack`. `AgentThreadView` sets it to `false`.
- [ ] In `AgentThreadView`, put `StateBanner` and then `AgentLoginPrompt` (when a connection is present) in the bottom `.safeAreaBar`, above the pill and the composer. They are content, not glass: do not put glass on them. They can be in the `VStack` of `floatingControls` inside the `FloatingGlassContainer`, because a container with no glass child draws nothing.
- [ ] Keep the accessibility identifiers, the order for VoiceOver (banner, prompt, pill, composer) and the `showItem` action of the banner.
- [ ] Change the doc comments of `ConversationView`, `AgentThreadView` and `floatingControls`.

## Acceptance

- A structure test of `AgentThreadView.swift` (code lines only): `StateBanner(` and `AgentLoginPrompt(` show only inside the bottom bar content (for example: inside `floatingControls`, after its declaration line and before the next `private var` or `func`). `ConversationView.swift` has `StateBanner(` only in the `.safeAreaBar(edge: .bottom)` closure.
- A hosted layout test (off-screen window, the method of `GlassRenderProbeHostedTests`): in an `AgentThreadView` with a transcript and a state banner, the bottom of the scroll view frame is the bottom of the thread view frame, and the banner frame is inside the scroll view frame. Use frames that the view reports with a preference key, read after one layout pass of the window. No wait for time.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8