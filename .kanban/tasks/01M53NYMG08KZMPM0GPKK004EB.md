---
assignees:
- claude-code
position_column: todo
position_ordinal: a180
title: Add hosted tests that the AppKit split view shows the attachment inspector item after a selection change
---
Found in ^7s6r89d. The tests aPressOnAChipSelectsItsAttachmentForTheInspectorContent and theSelectionOfTheHostOfAThreadViewGivesItsAttachmentToTheInspectorContent in Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift do not prove that the AppKit split view shows the inspector item. They check the selection, and then mount AttachmentInspector in its own harness (mountInspectorContent(of:)). In the off-screen harness window, the split view shows the item only after a run loop turn.

Experiment result in ^7s6r89d (one run, the experiment is removed): after the chip press with no animation (withoutAnimation), harness.render() did not show the element AttachmentInspector.nameIdentifier. After one hop through the main queue (`await withCheckedContinuation { c in DispatchQueue.main.async { c.resume() } }`) and one more harness.render(), the element was there. The test passed after 0.265 s.

The hop is an event that is certain to come: the main queue always runs the block. It has no clock, no poll, no retry and no time limit. If the split view needs more than one turn, the expectation fails, and the test does not hang.

- [ ] Add a helper to the test support for one main queue hop, with a doc that tells why it is an event that is certain to come. Put it where the other wait helpers are (for example near ObservationWait or HostedViewHarness), and follow the test rule in the doc of HostedViewHarness.
- [ ] Add a hosted test: a press on a chip (with no animation), one hop, one render, then the split view of the harness shows the element AttachmentInspector.nameIdentifier with the label of the file, and the five action identifiers.
- [ ] Add a hosted test: AgentThreadView with a host selection, the host selects an attachment (with no animation), one hop, one render, then the harness shows the element AttachmentInspector.nameIdentifier with the label of the file.
- [ ] Remove the gap notes of the two tests above in AttachmentInspectorHostedTests, or change them to name the new tests. Change the doc of the suite if it is not correct after the change.
- [ ] Do not add an XCUITest and do not add waitForExistence. No sleep, no poll, no retry, no timeLimit trait.

Write all text in STE.