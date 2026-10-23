---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5n0ex88m3x6vs2cwy1jpbxe
  text: |-
    Research (implement step). Reproduced: `Scripts/test-examples.sh` fails only testASendOfHelloShowsTheReplyOfTheAgent at ACPTabEndToEndTests.swift:100 (the other 4 UI tests pass).

    Probe: temporary NSLog in ConversationView `onScrollGeometryChange` / `noteVisible` / `scroll(to:)`, read back with `log show` after a `-only-testing` xcodebuild run. Findings:
    - Cause is a feedback loop of the pin state through the bottom inset. The scroll-to-bottom pill sits in the VStack of the floating controls of AgentThreadView, so each show/hide of the pill changes the height of the bottom bar by the pill height + one small spacing (32 pt), and so `contentInsets.bottom` of the list. Each inset change makes SwiftUI report a transient scroll geometry (contentOffset.x == 8, offset past the end) whose visibility report is `[]`. `ScrollAnchorManager.noteVisible([])` unpins -> pill shows -> inset changes -> list reports the real rows -> pins -> pill hides -> inset changes -> transient `[]` again.
    - One run logged 53,000 lines of this oscillation in 20 s; the main actor was so busy that the reply never reached the list (content height stayed at the one user row). Another run settled after the oscillation with no row in the AX tree (only the 0x0 `Other`). Both fail the test.
    - In a hosted harness (660x567, demo-like slot with ContextUsageView, RequestDeck, PromptInputView, login prompt) the same updates leave the rows in the AX tree but still show the pill after the state banner appears: the unpin is reproducible deterministically there.
    - Experiment: the pill moved out of the VStack into an `.overlay(alignment: .top)` of the floating-controls stack (still inside the one FloatingGlassContainer, D110 (c)). Then the inset no longer depends on the pin state, there is no loop, and the UI test passed (22 s). Experiment reverted; now doing it test-first.
    - The 96/128 pt list frame alone is not the cause: in the passing run the list is the same 128.5 pt tall.
  timestamp: 2026-10-23T18:30:36.040788+00:00
- actor: claude-code
  id: 01m5n2xcmfh1xrx1ap0v34hp5y
  text: |-
    Progress + second cause.
    - Landed (test-first): the pill is an overlay of the floating controls, not in their VStack. New hosted test ThreadFloatingControlsHostedTests.theShowOfThePillKeepsTheBottomInsetOfTheList (red before: inset grew by pill + spacing; green after). HostedSnapshotTests bottom-bar-buttons-* re-recorded (the bar is 32 pt shorter, the pill floats above it).
    - With only that change `Scripts/test-examples.sh` passed 2 of 3 runs; one run failed the same way. Probe of a failing single-test run: the list settles at the right offset but the last visibility report is `[]`, the lazy stack keeps no row, and the AX tree has no row.
    - Second cause, reproduced in a hosted harness (deterministic): after `ScrollPosition.scrollTo(edge: .bottom)` the position stays `.edge(.bottom)`, and SwiftUI re-applies it on later layout passes from the frame of the `scrollTargetLayout()` stack: contentOffset.x = 8 (the row padding) and y = the right bottom offset + the bottom inset (past the end of the content). The `[]` visibility report of that transient geometry unpins the manager.
    - Bisect (count of geometries past the end, or with x != 0, in a demo-like hosted thread): base 15; without `.defaultScrollAnchor(.bottom, for: .alignment)` 20; without ConversationFollowAnchor 18; without `.defaultScrollAnchor(.bottom, for: .initialOffset)` 14; without `.padding(rowPadding)` 19 (x becomes 0, y stays wrong); without `.scrollTargetLayout()` 0 (but then no visibility reports); without `.scrollPosition` 0 (but then no programmatic scroll).
    - Did not work: resetting `position` to an empty ScrollPosition once the list reports the bottom (the wrong re-application is in the same pass as the scroll); `ScrollPosition()` with no id type (same 6 bad geometries).
    - Works in the probe: scroll to a zero-height bottom sentinel view at the end of the content by id (`scrollTo(id:anchor: .bottom)`): 0 bad geometries, the manager stays pinned for the whole turn. Next: red hosted test for "a streamed turn never unpins the thread", then that change.
  timestamp: 2026-10-23T19:13:27.695633+00:00
- actor: claude-code
  id: 01m5n83023nxkn69ptrg05z187
  text: |-
    Implementation landed (test-first), two kit causes:
    1. AgentThreadView: the scroll-to-bottom pill is an overlay of the floating-controls stack (alignment guide one small spacing above the stack, still inside the one FloatingGlassContainer). Its show/hide no longer changes the bottom inset of the list. Test: ThreadFloatingControlsHostedTests.theShowOfThePillKeepsTheBottomInsetOfTheList (red: inset grew with the pill; green after). VoiceOver order in the controls is now pill, banner, login prompt, composer (measured in a hosted harness); the docs say so.
    2. ConversationView: an append scroll near the end goes to a zero-height view `ConversationLayout.bottomIdentifier` at the end of the content via `scrollTo(id:anchor: .bottom)`. A far scroll (pill press) still uses `scrollTo(edge: .bottom)`, because a by-id scroll from far up stops short on estimated lazy heights (^92k32m0). The next near scroll replaces a kept edge. Test: ThreadFloatingControlsHostedTests.aStreamedTurnKeepsTheThreadPinnedToTheBottom (tall slot so the bottom inset > the visible list, as in the demo; red: "the thread unpinned during the turn", 49 empty visibility reports; green after).
    - Did not work: id-scroll for every bottom scroll (aPressOnThePill tests failed); converting the kept edge to the id once at the bottom (aPressOnThePillOfTheThreadShowsAllOfTheLastRow flaky, 1 in 5); resetting the position after landing (aPressOnThePillScrollsTheListToTheLastRow failed 4/4).
    - Docs: AgentThreadView doc comments, README component entry, plan.md §9 and "Scroll under the bars".
    - HostedSnapshotTests bottom-bar-buttons-* (4 variants) re-recorded: the bar is 32 pt shorter and the pill floats above it. The diff images were not checked by eye (the agent cannot view PNGs); a person should look at them before the commit.
    - UI-lock note: three ungated `Scripts/test-examples.sh` runs ran 20:05:56–20:13:06Z, before the shared-lock rule arrived. The third (20:10:43–20:13:06Z) is the demo launch that came up over Testudo at 20:12Z. The first of those runs failed with "Neither element nor any descendant has keyboard focus" while overlapping Testudo, so all three are treated as unreliable.

    ### implement — changed
    - evidence: `swift test` EXIT=0 (1720 tests in 212 suites with 3 known issues, plus 227 tests in 30 suites; no warnings beyond the SwiftPM "missing creator for mutated node" build note). Each `Scripts/test-examples.sh` run under the shared lock (lgate1–3, 20:37–20:43Z) passed with 5/5 UI tests; testASendOfHelloShowsTheReplyOfTheAgent passed 3 runs in a row (14.4 s, 15.3 s, 14.8 s). Files: Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/ThreadFloatingControlsHostedTests.swift, 4 HostedSnapshotTests bottom-bar-buttons PNGs, README.md, plan.md
    - next: /review
  timestamp: 2026-10-23T20:43:54.307259+00:00
position_column: doing
position_ordinal: '8380'
title: 'Demo UI test: after a send of "hello" the reply row is not in the AX tree (testASendOfHelloShowsTheReplyOfTheAgent)'
---
Found by the implement step of ^69g4a69 (2026-10-23), with EditorKit 37325a2 and the EditorKit composer (EditorKitPromptEditor with `.editorTextAccessibilityIdentifier("prompt-editor")`).

`Scripts/test-examples.sh`: `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` now gets past the composer: XCUI finds "prompt-editor" (a TextView), clicks it, types "hello", and clicks "prompt-submit". It then fails at ACPTabEndToEndTests.swift:100, "The transcript shows no reply.": `item-row-agent-message-demo-reply-1` never exists within 20 s.

The failure-time AX snapshot in `.build/examples/AgentViewKitDemo/AgentViewKitDemo-test.xcresult` shows the send worked:
- `state-banner`: "The response is complete"; `context-usage`: 1%.
- `conversation-list` ScrollView: value "3 of 3 items", frame height 96.6 pt in a 900x619 window, with no row children exposed (one 0x0 `Other`).
- `scroll-to-bottom-pill` shows, so the list is not pinned to the bottom.
- Above the composer, the floating controls hold the end-turn banner (60 pt) and the `agent-auth` panel (139.5 pt), which leave the list little room.
- "prompt-editor" TextView {580x16}, Keyboard Focused, Disabled; Send Disabled (empty after the send). XCUI still logs "Falling back to element center point" for both clicks. That is the ^bc6fapz hit-point symptom, but it no longer fails the test.
- Measured in a hosted probe: AppKit reports `isAccessibilityEnabled() == false` for every NSTextView, even an editable one (plain NSTextView, SwiftUI TextEditor, and EditorKit EditorInputTextView all report false). So the "Disabled" on the editor is AppKit's default and not a kit bug.

To do: find why the reply row is not in the AX tree. Candidates are a list that isn't pinned after the send (the pill shows) and lazy rows outside a 96 pt viewport. Fix it in the kit, or make the demo layout leave the list room, without weakening the UI test.

Acceptance: `Scripts/test-examples.sh` passes, with this test green on 3 runs in a row; `swift test` green. #bug #avk-8