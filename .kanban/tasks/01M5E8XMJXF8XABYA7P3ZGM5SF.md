---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ezyvb104bhqavmxt852q0e
  text: |-
    Research done.
    - StateBanner is in the VStack of ConversationView under the list. AgentLoginPrompt is in the VStack of AgentThreadView.content under ConversationView. The bottom bar is `.safeAreaBar(edge: .bottom) { floatingControls }` with one FloatingGlassContainer (pill + composer slot).
    - The Show Error action of the banner is `showItem` in ConversationView: `anchors.noteJump(to:)` then a scroll to the item. In the thread, the same result comes from `anchors.noteJump(to:)` and `anchors.onScroll(.item(id))` (ConversationView sets `onScroll` to its `scroll(to:)`, which also adds pages). The jump commands use the same pair.
    - Decision for the look: the card says the banner and the prompt are content, with no glass. style.md rule 4 says a status bar in `.safeAreaBar` has standard controls. Thus the surfaces stay content (no glass, content edge). Their buttons (StatusBar button, AgentAuthView action buttons) take the style from the existing place mechanism `requestActionStyle(.secondary)` (RequestDeckPlace from `floatingGlassContainerCount`): `.glass` in content, `.bordered` in the bar. NoticeRow already does this. No second mechanism. In the bar, a `.glass` button in the GlassEffectContainer would also join the glass group of the pill and the composer.
    - No EditorKit command exists for Show Error or for Sign In today. The card does not add one. The existing commands (scrollToBottom, focusComposer, send) do not change.
    - Hosted frame test: the scroll view and the banner are inside the thread view, so a test cannot put a preference key on them without test code in the kit. The test reads the accessibility frames of the list and of the banner (`HostedViewHarness.frame(identifier:)`), the reported frames after one layout pass, and compares them with the frame of the hosting view.
  timestamp: 2026-10-21T10:26:23.201175+00:00
- actor: claude-code
  id: 01m5f0peygn9q2eqkcdm34ej1r
  text: |-
    Implementation landed.
    - ConversationView: new internal environment value `conversationShowsStateBanner` (default `true`). The body is a `Group` (empty state or list) with `.safeAreaBar(edge: .bottom)` that holds the `StateBanner` when the value is `true`.
    - AgentThreadView: sets the value to `false`. `floatingControls` holds, from the top, `StateBanner` (Show Error calls a new private `showItem`: `anchors.noteJump(to:)` then `anchors.onScroll(.item(id))`), `AgentLoginPrompt` (when the connection is present), the pill and the composer. `AgentLoginPrompt` lost its own padding, because the bar gives the space.
    - Buttons: `StatusBar` and `AgentAuthView` use `requestActionStyle(.secondary)` in place of `.buttonStyle(.glass)`. Thus `.glass` in content and `.bordered` in the bottom bar (style.md "Bars of a view"). GlassPlacementTests moved the two files from `glassButtonFiles` to `requestCardFiles`. The existing value tests of `RequestDeckPlace.style(of:)` cover the styles.
    - Tests: `Tests/PackageStructureTests/ThreadBottomBarStructureTests.swift` (block of `var floatingControls` and of `.safeAreaBar(edge: .bottom)`, comments and strings blanked, `PreviewCoverageTests.balancedBody`). `Tests/AgentViewKitTests/Thread/ThreadBottomBarHostedTests.swift`: banner and login prompt in the floating controls, VoiceOver order banner < prompt < composer, list reaches the bottom edge under the banner (thread and conversation alone), Show Error in the thread moves to the error entry. ConversationViewHostedTests got two shared helpers (`openSessionWithErrorAtTop`, `pressShowError`) so the thread test does not copy the old test.
    - Discovery: the accessibility frame of a SwiftUI ScrollView leaves out its content insets. With the bar, the AX frame of the list stops at the top of the bar, but the `NSScrollView` (HostingScrollView) frame reaches the bottom edge with `contentInsets.bottom` equal to the bar height. The frame test reads the `NSScrollView` frame (new test support helpers `HostedViewHarness.views(of:)` and `screenFrame(of:)`), not a preference key: the list is inside the kit, so a preference key needs test code in the kit. RED was checked with the old Sources stashed: all four layout and container tests failed; GREEN after.
    - Docs: README (AgentThreadView, ConversationView bullets and the quick start comment), the regenerated snippet `Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift`, plan.md §9, ScrollAnchorManager.noteJump doc. The demo app sources did not change.
    - No EditorKit command exists for Show Error or Sign In. The card does not ask for one.
  timestamp: 2026-10-21T10:39:16.944132+00:00
- actor: claude-code
  id: 01m5f0pjk418zss5drph6zmp29
  text: |-
    ### implement — changed
    - evidence: `swift test` exit 0: 1479 tests in 185 suites passed with 2 known issues (existing), 176 tests in 24 suites passed, 1 test passed; only the existing mlx bundle warning. Files: Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Connections/AgentLoginPrompt.swift, Sources/AgentViewKit/Connections/AgentAuthView.swift, Sources/AgentViewKit/Status/StatusBar.swift, Sources/AgentViewKit/HumanInTheLoop/RequestActionStyle.swift, Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift, Sources/AgentViewKitTestSupport/HostedViewHarness+TextViews.swift, Tests/AgentViewKitTests/Thread/ThreadBottomBarHostedTests.swift (new), Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift, Tests/PackageStructureTests/ThreadBottomBarStructureTests.swift (new), Tests/PackageStructureTests/GlassPlacementTests.swift, README.md, Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift, plan.md
    - next: /review
  timestamp: 2026-10-21T10:39:20.676109+00:00
- actor: claude-code
  id: 01m5f0wqvj6yx5p7ra0zr4a0fa
  text: |-
    ### test — green
    - evidence: swift test, 80.3 s, 1479 tests in 185 suites passed, 0 failures, 2 known issues (before this work). The only warning is the mlx bundle build warning (before this work).
    - PackageStructureTests ran and passed, with GlassPlacementTests and ThreadBottomBarStructureTests. ReadmeSnippetsTests ran and passed. ThreadBottomBarHostedTests passed.
    - Scripts/check-readme.sh: README gate passed, exit 0.
    - No code change was necessary. No commit.
    - next: review
  timestamp: 2026-10-21T10:42:42.674002+00:00
depends_on:
- 01M5E8WMM146Y611ZQDZM1HM5Q
- 01M5E8X2DC7CT94TQJG2G7W4MZ
position_column: doing
position_ordinal: '80'
title: 'AVK-8al Thread bottom bar: put StateBanner and AgentLoginPrompt in the bottom .safeAreaBar with the composer, so the list scrolls under them (D113 answer 7)'
---
## Why

D113 answer 7 and `style.md` "Scroll under the bars": "The list of a view scrolls under its bars. A banner or a prompt next to a bar is in the same bar (`.safeAreaBar(edge:)`), not between the list and the bar."

Today:
- `StateBanner` is under the list in the `VStack` of `ConversationView` (`Sources/AgentViewKit/Thread/ConversationView.swift:195-206`, banner at `:204-205`).
- `AgentLoginPrompt` is under `ConversationView` in the `VStack` of `AgentThreadView.content` (`Sources/AgentViewKit/Thread/AgentThreadView.swift:218-220`).
- The bottom bar is `.safeAreaBar(edge: .bottom) { floatingControls }` (`AgentThreadView.swift:222`, `floatingControls` at `:235-247`).

## What to do

- [x] Copy the method of the pill (`\.conversationShowsPill`, `AgentThreadView.swift:217`, `ConversationView.swift:259-262`): add an internal environment value (for example `\.conversationShowsStateBanner`, default `true`). When it is `true`, a standalone `ConversationView` puts `StateBanner` in its own `.safeAreaBar(edge: .bottom)` of the list, not in the `VStack`. `AgentThreadView` sets it to `false`.
- [x] In `AgentThreadView`, put `StateBanner` and then `AgentLoginPrompt` (when a connection is present) in the bottom `.safeAreaBar`, above the pill and the composer. They are content, not glass: do not put glass on them. They can be in the `VStack` of `floatingControls` inside the `FloatingGlassContainer`, because a container with no glass child draws nothing.
- [x] Keep the accessibility identifiers, the order for VoiceOver (banner, prompt, pill, composer) and the `showItem` action of the banner.
- [x] Change the doc comments of `ConversationView`, `AgentThreadView` and `floatingControls`.

## Acceptance

- A structure test of `AgentThreadView.swift` (code lines only): `StateBanner(` and `AgentLoginPrompt(` show only inside the bottom bar content (for example: inside `floatingControls`, after its declaration line and before the next `private var` or `func`). `ConversationView.swift` has `StateBanner(` only in the `.safeAreaBar(edge: .bottom)` closure.
- A hosted layout test (off-screen window, the method of `GlassRenderProbeHostedTests`): in an `AgentThreadView` with a transcript and a state banner, the bottom of the scroll view frame is the bottom of the thread view frame, and the banner frame is inside the scroll view frame. Use frames that the view reports with a preference key, read after one layout pass of the window. No wait for time.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8