---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m53q391xybewvzckrkpp3ex1
  text: |-
    Research done.
    - InspectorSelection.select(_:) sets the attachment at once, on the main actor. Thus after the host select, a synchronous require of the selection is correct.
    - AgentThreadView applies attachmentInspector(selection:) with the host selection of the environment (hostInspectorSelection ?? ownInspectorSelection).
    - The test rule in the doc of HostedViewHarness lists the allowed waits: render(when:) and ObservationWait.until(_:). The new hop must go in that list.
    - Plan: a new public enum MainQueueHop in Sources/AgentViewKitTestSupport/MainQueueHop.swift, next to ObservationWait.swift, with one function run(). Two new tests in AttachmentInspectorHostedTests. The gap notes of the two old tests change to name the new tests.
  timestamp: 2026-10-17T01:19:52.381252+00:00
- actor: claude-code
  id: 01m53qc44p3kt1jctyh7bwj6r6
  text: |-
    ### implement — changed
    - evidence: 3 files. New: Sources/AgentViewKitTestSupport/MainQueueHop.swift (public enum MainQueueHop, func run(): one DispatchQueue.main.async block in a checked continuation). Changed: Sources/AgentViewKitTestSupport/HostedViewHarness.swift (the test rule now lists the one hop as an allowed wait). Changed: Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift (two new tests aPressOnAChipShowsTheInspectorItemInTheSplitView and theSelectionOfTheHostOfAThreadViewShowsTheInspectorItemInTheSplitView; the gap notes of the two old tests now name the new tests; the suite doc and the withoutAnimation doc now tell about the main queue turn; new helpers mountChip(of:selection:), mountThreadView(of:selection:) and pressChip(in:selecting:in:), which the old and the new tests use, so that the new tests do not copy the setup).
    - RED: swift build --build-tests failed with only "cannot find 'MainQueueHop' in scope" (2 errors), before the helper existed.
    - swift build --build-tests: Build complete. No warning in Sources/ or Tests/. One build system warning: "missing creator for mutated node: .../mlx-swift_Cmlx.bundle/Contents/MacOS".
    - swift test --skip-build --filter AttachmentInspectorHostedTests: "Test run with 11 tests in 1 suite passed after 0.425 seconds." Both new tests passed after one hop (0.049 s and 0.057 s). The thread view case shows the item after one hop, as the chip case does.
    - swift test --skip-build (full): "Executed 0 tests, with 0 failures (0 unexpected)" (3 times); "Test run with 1 test in 1 suite passed after 0.001 seconds."; "Test run with 127 tests in 16 suites passed after 18.260 seconds."; "Test run with 1314 tests in 153 suites passed after 66.835 seconds with 2 known issues." The 2 known issues are the tests aWrappedTextWithAFixedVerticalSizeFails (HostedLayoutExpectationsTests) and aViewThatIgnoresTheThemeFails (ThemeHeightExpectationsTests), which record a known issue on purpose. This change did not touch them.
    - No XCUITest, no waitForExistence, no sleep, no poll, no retry, no timeLimit trait. Not committed. Task stays in doing.
    - next: review
  timestamp: 2026-10-17T01:24:42.262816+00:00
- actor: claude-code
  id: 01m53qczdqqqwv31269td9p4z1
  text: |-
    ### test — green
    - evidence: the implement step ran one full swift test --skip-build after the change: 1314 tests in 153 suites passed with 2 known issues, 127 tests in 16 suites passed, 1 test in 1 suite passed, XCTest 0 tests. AttachmentInspectorHostedTests: 11 tests passed. swift build --build-tests: no warning in Sources/ or Tests/. It was not run again (no repeat runs).
    - next: commit (local), review.
  timestamp: 2026-10-17T01:25:10.199408+00:00
position_column: doing
position_ordinal: '80'
title: Add hosted tests that the AppKit split view shows the attachment inspector item after a selection change
---
Found in ^7s6r89d. The tests aPressOnAChipSelectsItsAttachmentForTheInspectorContent and theSelectionOfTheHostOfAThreadViewGivesItsAttachmentToTheInspectorContent in Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift do not prove that the AppKit split view shows the inspector item. They check the selection, and then mount AttachmentInspector in its own harness (mountInspectorContent(of:)). In the off-screen harness window, the split view shows the item only after a run loop turn.

Experiment result in ^7s6r89d (one run, the experiment is removed): after the chip press with no animation (withoutAnimation), harness.render() did not show the element AttachmentInspector.nameIdentifier. After one hop through the main queue (`await withCheckedContinuation { c in DispatchQueue.main.async { c.resume() } }`) and one more harness.render(), the element was there. The test passed after 0.265 s.

The hop is an event that is certain to come: the main queue always runs the block. It has no clock, no poll, no retry and no time limit. If the split view needs more than one turn, the expectation fails, and the test does not hang.

- [x] Add a helper to the test support for one main queue hop, with a doc that tells why it is an event that is certain to come. Put it where the other wait helpers are (for example near ObservationWait or HostedViewHarness), and follow the test rule in the doc of HostedViewHarness.
- [x] Add a hosted test: a press on a chip (with no animation), one hop, one render, then the split view of the harness shows the element AttachmentInspector.nameIdentifier with the label of the file, and the five action identifiers.
- [x] Add a hosted test: AgentThreadView with a host selection, the host selects an attachment (with no animation), one hop, one render, then the harness shows the element AttachmentInspector.nameIdentifier with the label of the file.
- [x] Remove the gap notes of the two tests above in AttachmentInspectorHostedTests, or change them to name the new tests. Change the doc of the suite if it is not correct after the change.
- [x] Do not add an XCUITest and do not add waitForExistence. No sleep, no poll, no retry, no timeLimit trait.

Write all text in STE.