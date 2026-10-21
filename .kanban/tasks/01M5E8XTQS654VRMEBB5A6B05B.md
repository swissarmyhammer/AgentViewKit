---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5f17jrw6kcf41972z9ck07h
  text: |-
    Research:
    - After ^3zgm5sf, `AgentThreadView.content` is a `VStack` with the header, the connection banner (only with a connection), the notice banner, the stream banner and `ConversationView`. The bottom bar is `.safeAreaBar(edge: .bottom) { floatingControls }`.
    - The button style of the notice Dismiss button and of the `StatusBar` buttons comes from `RequestDeckPlace(floatingGlassContainerCount:)`. The top bar has no `FloatingGlassContainer` and the card asks for no background, so the place stays `.content` and these buttons keep their content style (`.glass`). The card does not ask for a change of the button style. Note: style.md step 4 ("Bars of a view ... with standard controls") can ask for bordered buttons in the top bar. That is a possible follow-up, not part of this card.
    - Reuse for tests: `ThreadBottomBarStructureTests.code(of:)` / `block(after:in:)` / `GlassForm.callPattern`, `ThreadBottomBarHostedTests.listFrame(in:)` / `edgeTolerance`, `ConnectionModelViewsHostedTests.openSession()` / `mountThread(_:)`, `CompactionAndNoticeHostedTests.notice(severity:)`, `ConversationViewHostedTests.sendMessages(_:to:)`. The screen y axis goes up, so the top edge is `maxY`.
  timestamp: 2026-10-21T10:48:37.916979+00:00
- actor: claude-code
  id: 01m5f1zqtvn02wsw84th2yb6dy
  text: |-
    Implementation landed:
    - `AgentThreadView.content`: the `VStack` holds only `ConversationView`. The header, the connection banner, the notice banner and the stream banner are in `.safeAreaBar(edge: .top) { VStack(spacing: 0) { ... } }`, in the same order, with no background and no `.scrollEdgeEffectStyle`. The doc comments of the type and of `content` tell about the top bar.
    - Structure test: `Tests/PackageStructureTests/ThreadTopBarStructureTests.swift`. It reuses `ThreadBottomBarStructureTests.expectOnlyInItsBar(_:)` (extracted from the bottom bar test; `BottomBarView` is now `BarView`).
    - Hosted tests: `Tests/AgentViewKitTests/Thread/ThreadTopBarHostedTests.swift`. The scroll view frame reaches the top edge (`maxY`, because the screen y axis goes up), and the header and the notice are inside it. Two VoiceOver order tests: header, notice, list, floating controls; and for a closed thread, header, disconnected banner, closed stream banner, list, floating controls.
    - Discovery: with `.safeAreaBar(edge: .top)`, `accessibilityChildren` lists the list BEFORE the top bar, but `accessibilityChildrenInNavigationOrder` (the order that VoiceOver reads) lists the top bar first. Thus a reading-order test must read the navigation order. I added `HostedViewHarness.accessibilityElementsInNavigationOrder()` (the existing walk takes a child-read function now). The typed Swift getter `accessibilityChildrenInNavigationOrder()` traps on SwiftUI nodes ("NSArray element failed to match"), so the harness sends the selector.
    - What did not work: `.accessibilitySortPriority` on the bar, also with `.accessibilityElement(children: .contain)` around the content, did not change the `accessibilityChildren` order. These two are not necessary, because the navigation order is correct with no change. I removed them.
    - A close of the transport removes the notices of the model (the session closes), so the closed-thread order test checks the stream banner and not the notice.
    - README and plan.md tell about the top bar. `Scripts/check-readme.sh` passes. The demo app has no change.
  timestamp: 2026-10-21T11:01:49.531335+00:00
- actor: claude-code
  id: 01m5f1zt0qdyfbk88xex38zzq2
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKitTestSupport/HostedViewHarness.swift, Tests/PackageStructureTests/ThreadBottomBarStructureTests.swift, Tests/PackageStructureTests/ThreadTopBarStructureTests.swift (new), Tests/AgentViewKitTests/Thread/ThreadTopBarHostedTests.swift (new), README.md, plan.md. `swift test`: 1482 tests in 186 suites passed with 2 known issues, 177 tests in 25 suites passed; only the mlx bundle warning (this warning existed before). `Scripts/check-readme.sh` exit 0.
    - next: /review
  timestamp: 2026-10-21T11:01:51.767015+00:00
- actor: claude-code
  id: 01m5f2553ka1pbvnr2mfwjpzrx
  text: |-
    ### test - green
    - evidence: swift test, 116 s. Swift Testing: 1482 tests in 186 suites passed, 2 known issues (old). XCTest: 0 tests, 0 failures.
    - PackageStructureTests ran and passed: 177 tests in 25 suites, including ThreadTopBarStructureTests and ThreadBottomBarStructureTests. ReadmeSnippetsTests passed. ThreadTopBarHostedTests passed.
    - Scripts/check-readme.sh: README gate passed, exit 0.
    - Warnings: only the old mlx bundle warning. No new warning. No error.
    - Not committed.
    - next: review
  timestamp: 2026-10-21T11:04:46.963188+00:00
- actor: claude-code
  id: 01m5f25j6yh5ynfqddfwjqy7q6
  text: |-
    ### decision (testudoapp-4c, style.md step 4)
    - The buttons in the top bar stay `.glass`. The top bar has no glass surface, and the list scrolls under it, so these buttons are floating controls (style.md step 3).
    - `.bordered` is only for a button on a glass surface, such as the request card in the bottom bar.
    - No follow-up card is necessary.
  timestamp: 2026-10-21T11:05:00.382964+00:00
- actor: claude-code
  id: 01m5f288a8vdfszcqjw15f9j4z
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 471e0ac). 0 findings, 0 confirmed, 0 refuted. 7 pairs attempted, 0 failed. Not reviewed: 2 .kanban files (ignore rule), README.md and plan.md (no validator).
    - next: The task is in done.
  timestamp: 2026-10-21T11:06:28.552120+00:00
- actor: claude-code
  id: 01m5f28j95pd1ash0t78kd3eb4
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 7 files
    - test: green — swift test, 1482 passed, 2 known issues that were there before; 177 structure tests, the README snippet test and check-readme.sh passed
    - commit: 471e0ac
    - review: clean — 0 findings
  timestamp: 2026-10-21T11:06:38.757449+00:00
depends_on:
- 01M5E8XMJXF8XABYA7P3ZGM5SF
position_column: done
position_ordinal: ffff9c80
title: 'AVK-8am Thread top bar: put AgentInfoHeader and the top banners in a top .safeAreaBar, so the list scrolls under the toolbar with the scroll edge effect (D113 answer 7)'
---
## Why

D113 answer 7 and `style.md` rule 3: "Scroll views go under the toolbar with the scroll edge effect." `style.md` "Scroll under the bars": "The headers and the banners at the top are in a top bar."

Today `AgentInfoHeader`, `AgentConnectionBanner`, `SessionNoticeBanner` and `SessionStreamBanner` are above `ConversationView` in the `VStack` of `AgentThreadView.content` (`Sources/AgentViewKit/Thread/AgentThreadView.swift:207-213`). Thus the list starts under them and does not go under the toolbar.

## What to do

- [x] Move these four views into `.safeAreaBar(edge: .top) { ... }` on the content of `AgentThreadView`, in the same order. The `VStack` then holds only `ConversationView`. Do not add a background to the bar (D112 (e), style.md rule 1).
- [x] Do not set `.scrollEdgeEffectStyle` unless the screenshot check asks for it: the default soft effect is correct for a transcript (`.hard` is for a dense editor, style.md rule 3).
- [x] Keep the accessibility identifiers and the VoiceOver order (header, banners, list, bottom bar).
- [x] Change the doc comment of `content`.

## Acceptance

- A structure test of `AgentThreadView.swift` (code lines only): `AgentInfoHeader(`, `AgentConnectionBanner(`, `SessionNoticeBanner(` and `SessionStreamBanner(` show only inside the `.safeAreaBar(edge: .top)` closure.
- A hosted layout test (the method of AVK-8al): in an `AgentThreadView` with a connection and a notice, the top of the scroll view frame is the top of the thread view frame, and the header frame is inside the scroll view frame.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8