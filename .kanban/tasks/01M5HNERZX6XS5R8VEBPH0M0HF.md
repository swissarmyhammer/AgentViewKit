---
assignees:
- claude-code
position_column: todo
position_ordinal: a080
title: AVK-8 The transcript draws under the thread top bar, with the scroll edge effect
---
Reported by testudoapp-2c (2026-10-22), measured in Testudo on AgentViewKit 20d1de5. The host is a plain `AgentThreadView(session:connection:)` (TestudoApp `Sources/SAHKit/Chat/ChatAreaView.swift`).

Observed, in screen points: the chat area starts at y 367. The text of the top bar (name and state banner) is at y 375–391. The `conversation-list` viewport starts at y 399. With four answers that overflow, rows placed at y 360 and y 388 draw no pixels above y 399. This is a hard clip, with no scroll edge fade. So the transcript does NOT scroll under the thread's own top bar (`.safeAreaBar(edge: .top)` in `Sources/AgentViewKit/Thread/AgentThreadView.swift`). The docs of AgentThreadView say that the list "scrolls under the two bars".

Why the test passes anyway: `ThreadTopBarHostedTests.theListOfTheThreadReachesTheTopEdgeUnderTheHeaderAndTheNotice` (`Tests/AgentViewKitTests/Thread/ThreadTopBarHostedTests.swift`) checks only the frame of the scroll view, not the content that is drawn.

Work:
- Find out what clips the content at the bottom edge of the bar. Candidates: a clip, background or `.scrollClipDisabled` on ConversationView or its list, a content margin or safe-area inset that the list applies, or the list not being the scroll view that the bar attaches to. Make the transcript rows draw under the top bar, with the system scroll edge effect.
- Check the bottom bar (`.safeAreaBar(edge: .bottom)`, the floating composer) for the same defect, and fix it the same way.

Acceptance:
- A hosted test fails before the fix and passes after. It scrolls a transcript that overflows and checks that a row is drawn under the top bar. Check a rendered result, not a frame: render the window and sample pixels in the band of the bar, or check the row's visible rect against the bar. Do the same check for the bottom bar.
- The test does not change system-wide settings and does not drive other apps in the default suite.
- The existing top-bar tests stay green. `swift test` is green.
- Related: ^1ye0jj6 (header glass) changes the same top bar. Do this card first. #avk-8 #testudo-request #bug