---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5hwdrgksgvgpy11t9yczxbk
  text: |-
    Research (2026-10-22, EditorKit 44d8a28, HEAD d7f7dab). Still fails at HEAD: `Scripts/test-examples.sh` -> testASendOfHelloShowsTheReplyOfTheAgent "Unable to find hit point for ScrollView {{1110,957},{580,36}}"; the other 4 UI tests pass.

    Findings:
    - The demo editor is `StockPromptEditor` (SwiftUI `TextEditor`, an `AttributedPlatformTextView` in a `TextEditorScrollView`). It is NOT an EditorKit view.
    - "Disabled" is a red herring: in a hosted harness a BARE SwiftUI `TextEditor` (no kit code) also reports `isAccessibilityEnabled() == false` (NSTextView + its scroll view). XCUI marks many AppKit-backed elements Disabled (Window, sidebar ScrollView). The transcript HostingScrollView is Disabled AND XCUI-hittable, so Disabled does not block the hit point.
    - The real cause is the bottom `.safeAreaBar(edge: .bottom)` of `AgentThreadView`: XCUI `isHittable` is false for EVERY element in the floating controls (prompt-editor, its ScrollView, prompt-field-surface, prompt-submit, permission-mode radio buttons, agent-auth-sign-out), while sidebar elements are hittable. In-process `NSApp.accessibilityHitTest` in the real on-screen demo window at the center of prompt-submit / agent-auth-sign-out returns the conversation `HostingScrollView` (under `conversation-empty-state`), not the button. The top bar header hit-tests to itself.
    - Experiment (reverted): floating controls moved out of `.safeAreaBar(edge: .bottom)` into the VStack under the conversation -> every bottom control becomes XCUI-hittable (editor still Disabled) and the test passes. So the bisect to 471e0ac was right.
    - Side finding: macOS 27 shows a "Siri Waveform Orb" `NSCampoLightweightUIHostWindow` (280x168) next to the editor caret; it is in front of the left part of the composer but is not the cause (controls far from it are also unhittable).
    - The UI test runner and the shell are not AX-trusted, so `AXUIElementCopyElementAtPosition` from outside returns -25211; probing must be in-process.
  timestamp: 2026-10-22T13:22:20.819452+00:00
- actor: claude-code
  id: 01m5hwv3c22x408pmf9vasvspg
  text: |-
    BLOCKER: the root cause is a SwiftUI/AppKit AX hit-test behavior on this OS, and each kit fix found conflicts with a documented design decision. A human must choose.

    Root cause (proven with a minimal repro, no kit code): in a hosted `NSHostingView`, `window.accessibilityHitTest(center of a SwiftUI Button)` returns the ScrollView row UNDER the button whenever the button is layered over a `ScrollView` with `.overlay`, `.safeAreaBar(edge: .bottom)`, `.safeAreaInset(edge: .bottom)` or a `ZStack`. Only `VStack { list; bar }` (no overlap) returns the button. These do NOT help: `.glassEffect()`, `GlassEffectContainer`, `.background(.regularMaterial)`, a plain `NSViewRepresentable` background, `.compositingGroup()`, `.drawingGroup()`, `.accessibilityElement(children: .contain)`, `.contentShape(.rect)`, and swapping the order of the top and bottom `safeAreaBar` modifiers.

    In the kit (hosted `AgentThreadView` with connection + notice): the hit at prompt-submit and agent-auth-sign-out returns an `AccessibilityLazyLayoutNode` row of `conversation-list`, and the top-bar notice banner returns the `HostingScrollView`. The prompt-editor (an AppKit platform view) and the glass header hit themselves in-process, but XCUI still reports the editor unhittable. Moving the floating controls out of the bar makes every bottom control XCUI-hittable and the demo test passes. A plain `.overlay` for the top bar does not help either.

    "Disabled" is not the cause: a plain `NSTextView()` and a bare SwiftUI `TextEditor` both report `isAccessibilityEnabled() == false`, and a Disabled transcript ScrollView is XCUI-hittable. So no "enabled state" test applies: the kit cannot change AppKit's NSTextView AXEnabled, and it does not cause the failure. EditorKit is not involved (the demo editor is StockPromptEditor = SwiftUI TextEditor).

    Workarounds that work in the minimal repro (each needs a decision):
    1. VStack(spacing: 0) { list.scrollClipDisabled(); bar }: rows still draw under the bar, but the bar is no longer a `safeAreaBar` (no scroll edge effect), and the list frame no longer reaches the bottom edge. This conflicts with D113 answer 7 / TestudoApp style "Scroll under the bars" and with ThreadBottomBarHostedTests.theListOfTheThreadReachesTheBottomEdgeUnderTheBanner and ThreadTopBarHostedTests.theListOfTheThreadReachesTheTopEdgeUnderTheHeaderAndTheNotice.
    2. Host the bar content in its own `NSHostingView` (an NSViewRepresentable) inside `.safeAreaBar`: this keeps the bar and the edge effect, but cuts the environment, preferences (PromptEditorMenuKey stays inside, OK), the one glass container of D110 (c), agentCommandScope, accessibilityFocusScope/readingScope and the theme. It is an architecture change (ARCHITECTURE.md would need an update).
    3. File a Feedback with Apple (minimal repro below) and keep the UI test red or quarantined until then. This weakens the gate, so it needs a human decision.
    The top bar has the same bug (notice dismiss / Reload buttons), so whichever fix is chosen should cover both bars.

    Minimal repro (hosted harness):
    ```swift
    struct Minimal: View {
      var body: some View {
        ScrollView { LazyVStack { ForEach(0..<80, id: \.self) { Text("Row \($0)").frame(maxWidth: .infinity) } } }
          .safeAreaBar(edge: .bottom) { Button("Bar") {}.accessibilityIdentifier("bar-button") }
      }
    }
    // harness.window.accessibilityHitTest(center of harness.frame(identifier: "bar-button")) -> AXStaticText "Row n", not the button
    ```
    Nothing changed in the tree; all diagnostic edits were reverted.
  timestamp: 2026-10-22T13:29:37.922709+00:00
- actor: claude-code
  id: 01m5hwva52vt1gjqkhvf5hdvjg
  text: |-
    ### implement — stuck
    - evidence: no files changed. Baseline `Scripts/test-examples.sh`: testASendOfHelloShowsTheReplyOfTheAgent fails, "Unable to find hit point for ScrollView {{1110,957},{580,36}}". The other 4 UI tests pass. Cause: a SwiftUI/AppKit AX hit test returns the ScrollView content under any SwiftUI view layered over it (`.safeAreaBar` / `.overlay` / `.safeAreaInset` / `ZStack`); minimal repro in the comment above. The kit's floating controls sit in `.safeAreaBar(edge: .bottom)` over the conversation list (D113), so every bottom control (editor, Send, Sign out, mode picker) is XCUI-unhittable. Experiment: moving the controls out of the bar makes the test pass. "Disabled" comes from AppKit (a plain NSTextView reports AXEnabled false) and does not cause the failure. Not an EditorKit issue.
    - next: a human chooses among (1) VStack + `scrollClipDisabled` (drops the bottom safeAreaBar/edge effect; conflicts with D113 and the bar-edge hosted tests), (2) hosting the bar content in its own NSHostingView (architecture change), or (3) filing Apple Feedback and deciding what to do with the UI test. The chosen fix should also cover the top bar.
  timestamp: 2026-10-22T13:29:44.866448+00:00
- actor: claude-code
  id: 01m5hww6tc2dgt9063tk4npyyk
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — no files changed. Cause: an SwiftUI/AppKit accessibility hit test returns the ScrollView row under any view laid over it (overlay, safeAreaBar, safeAreaInset or ZStack). A minimal repro with no kit code shows it. Every bottom-bar control is unhittable for AX/XCUI, and the top-bar notice is too. Earlier evidence shows a real coordinate click does reach the editor, so mouse input works and the AX hit test is what fails. With the controls moved out of the bar, the test passed (1 run, reverted). "Disabled" comes from AppKit and is not the cause. Not EditorKit.
    - test, commit, review: not run
    - next: a person decides. (1) Controls below the list: VStack + .scrollClipDisabled(); conflicts with D113 "scroll under the bars". (2) The bar content in its own NSHostingView inside .safeAreaBar; an architecture change. (3) Apple Feedback with the repro, and decide what the UI test does until then. The decision must cover the top bar too.
  timestamp: 2026-10-22T13:30:14.220734+00:00
position_column: doing
position_ordinal: '8280'
title: 'Demo UI test: XCUI finds no hit point for the composer editor (testASendOfHelloShowsTheReplyOfTheAgent)'
---
Found by the test step of ^32a58sq (2026-10-22). The test fails at HEAD without that card's change too.

`Scripts/test-examples.sh` fails `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift` `testASendOfHelloShowsTheReplyOfTheAgent` with "Unable to find hit point for ScrollView" on the composer editor. The other three tests in that class and the Gallery test pass.

What the tester saw:
- XCUI reports the editor as disabled. Still, a coordinate click and then `app.typeText("hello")` puts "hello" in it and enables Send. So the app takes input, but the accessibility state or the hit point of the editor is wrong.
- A rough bisect, one run per commit, points to `471e0ac` (header and banners moved into `.safeAreaBar(edge: .top)`). This evidence is weak: the machine was under heavy load (load average about 9, and another project's UI tests ran), and some runs flipped between pass and fail on the same sources.
- The composer now sits in `.safeAreaBar(edge: .bottom)` in `Sources/AgentViewKit/Thread/AgentThreadView.swift`. ^ph0m0hf works on the same bars, so check this test when you work on that card.

Fix the cause in the kit, so that the editor reports itself as enabled and hittable. Do not weaken the UI test with a coordinate click.

Acceptance:
- `Scripts/test-examples.sh` passes, with `testASendOfHelloShowsTheReplyOfTheAgent` green on 3 runs in a row.
- If the cause is in the kit's accessibility, a hosted or headless test checks the editor's accessibility enabled state.
- `swift test` is green. #bug #avk-8