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
- actor: claude-code
  id: 01m5sm2ph09yas27tcrcaa2zam
  text: |-
    Re-check at HEAD c1395e2 (2026-10-25, load average about 8-11). The visible failure is gone. The cause from the 2026-10-22 blocker is still there.

    What passes now:
    - `Scripts/test-examples.sh AgentViewKitDemo` (it takes the UI-test lock itself): PASS, 10/10 UI tests, testASendOfHelloShowsTheReplyOfTheAgent passed (13.1 s).
    - The single test, under the shared UI-test lock (scratch script that sources Scripts/ui-test-lock.sh; `-only-testing:...testASendOfHelloShowsTheReplyOfTheAgent -test-iterations 5 -run-tests-until-failure test-without-building`): 5/5 passed, 0 failures. With the gate run, that is 6 passes in a row.
    - The test is not weakened: it still calls `editor.click()`, `editor.typeText("hello")` and `submit.click()` on the elements. Every launch goes through `XCUIApplication.launch(arguments:)` in DemoTestValues.swift, which always adds `--primary-screen` (added by 32e6856, ^7dn35sm).
    - Displays on this machine (NSScreen frames): 0: (0,0) 2560x1440 (main), 1: (-1440,320), 2: (2560,320), 3: (0,1440) above the main display. So the negative-coordinate setup that `--primary-screen` works around is present here.

    What still fails (XCUI log, every run): XCUI finds NO accessibility hit point for the bottom-bar controls. It reaches them only through its center-point fallback:
    - `Click "prompt-editor"` -> `Synthesize event` -> `Falling back to element center point: {670, 840}`
    - `Click "prompt-submit"` -> `Falling back to element center point: {1061.5, 890}`
    Controls outside the bars hit-test normally, with no fallback: `session-row-demo-session`, `demo-acp-stop-agent`, `demo-acp-settings`, `demo-settings-done`, `session-row-gallery-permission`, `permission-title` and the menu bar items.

    Conclusion: `--primary-screen` keeps the window on a display where XCUI's center-point fallback works, so the test goes green. Most likely the old "Unable to find hit point" message was that fallback failing on a display at negative coordinates. The kit defect that the card orders fixed ("so that the editor reports itself as enabled and hittable") remains. The bottom `.safeAreaBar` controls of `AgentThreadView` are not AX-hittable (the AX hit test returns the conversation content under the bar; repro in the 2026-10-22 blocker comment). `AgentThreadView` still puts the floating controls in `.safeAreaBar(edge: .bottom)` and the header and notices in `.safeAreaBar(edge: .top)`, and `ConversationView` puts its state banner in `.safeAreaBar(edge: .bottom)`. "Disabled" is still AppKit-owned (a plain NSTextView reports AXEnabled false), so the kit's accessibility does not cause it, and the card's conditional "enabled state" hosted test does not apply.

    Not added: a UI-test guard `XCTAssertTrue(editor.isHittable)`. It would be red at HEAD until a kit fix lands. It is the natural regression guard once one of the fixes below is chosen.
  timestamp: 2026-10-25T13:30:25.184864+00:00
- actor: claude-code
  id: 01m5sm2w3w1qp9hhbdpqbkq4mm
  text: |-
    ### implement — stuck
    - evidence: no repo files changed (the only file written is a scratch lock-runner script outside the repo). `Scripts/test-examples.sh AgentViewKitDemo`: PASS, 10/10. Single test under the UI-test lock, 5 iterations, run until failure: 5/5 passed. `swift test`: 1828 tests in 225 suites passed, 7 known issues. Demo xcodeproj regenerated, then `xcodebuild ... -onlyUsePackageVersionsFromResolvedFile build`: BUILD SUCCEEDED, 0 repo warnings (only the appintentsmetadataprocessor note). The XCUI log still shows `Falling back to element center point` for prompt-editor and prompt-submit on every run, and for no control outside the bars. So the editor is still not AX-hittable, and the card's "fix the cause in the kit" is not met.
    - blocker: unchanged from 2026-10-22. A person decides: (0) accept that the acceptance runs are green and the center-point fallback is enough, and close the card as fixed by ^7dn35sm's `--primary-screen`; or choose a kit fix that covers both bars: (1) VStack + `.scrollClipDisabled()` (conflicts with D113 "scroll under the bars" and the bar-edge hosted tests), (2) host the bar content in its own NSHostingView inside `.safeAreaBar` (architecture change), or (3) file Apple Feedback with the minimal repro. With 1 or 2, add an `editor.isHittable` / `submit.isHittable` UI-test guard.
    - next: a person picks 0-3. The task stays in doing.
  timestamp: 2026-10-25T13:30:30.908475+00:00
- actor: claude-code
  id: 01m5sm3jxkc59k0nb0qqv4qhby
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the test passes (test-examples 10/10; single test 5/5 under lock), but XCUI still logs "Falling back to element center point" for prompt-editor and prompt-submit. Bottom/top .safeAreaBar controls are not AX-hittable; --primary-screen only keeps the fallback working. The card's kit fix is not met.
    - test/commit/review: not run (no repo change)
    - needs a person to pick an option (on the card): 0 close as fixed by --primary-screen; 1 put the controls below the list (conflicts with D113 scroll-under); 2 host the bar content in its own NSHostingView; 3 file Apple Feedback
  timestamp: 2026-10-25T13:30:54.259005+00:00
- actor: claude-code
  id: 01m62a7nmscyy0rax64mwtfrkn
  text: '2026-10-28: fixed upstream by EditorKit ^vdkg268. EditorKit c5e13cf fixed the composer hit test but broke clicks on the sidebar rows. EditorKit 112f24d fixes both. The cause was EditorKit''s AccessibilityHitTestCorrection stopping at conversation-empty-state, an ancestor whose AX frame covers the whole detail column. AVK main 2a5c7fd with Package.resolved on EditorKit 112f24d: Scripts/test-examples.sh is green 3 runs in a row (10/10 tests each, no "Falling back to element center point"). swift test is green: 1907 + 288 + 37 + 1. The cause was in EditorKit''s accessibility, not AVK''s, so EditorKit''s Composer UI tests (including the `--split-thread` layout) cover it.'
  timestamp: 2026-10-28T22:31:32.249739+00:00
depends_on:
- 01M5SXGMKSE6G758EP3J4VNH1R
position_column: done
position_ordinal: fffffb80
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