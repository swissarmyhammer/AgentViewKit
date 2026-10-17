---
assignees:
- claude-code
position_column: todo
position_ordinal: '9e80'
title: Find a certain way to test that the AppKit split view shows the attachment inspector item
---
Found in ^kk004eb. No hosted test proves that the AppKit split view shows the attachment inspector item after a chip press or after a host selection of a thread view. The state tests in Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift check only the input to the split view: the selection, and the selection that AgentThreadView gives to its inspector.

Facts:
- In ^kk004eb, one main-queue hop and one render showed the item in the runs. But the code does not prove the order. The work that shows the item is in SwiftUI and AppKit. It can be a run loop observer, a run loop perform, a timer with zero delay, or a Core Animation transaction commit. These do not have a FIFO order with the blocks of the main dispatch queue. Thus such a test can fail only sometimes. The step owner removed those tests and the MainQueueHop helper (decision option C).
- A wait on an event that the inspector content sets in onAppear can wait without end when the split view does not show the item. A hosted test holds HostedTestLock and a wait has no time limit, so this breaks the test rule in the doc of HostedViewHarness.
- The rules do not permit an XCUITest or waitForExistence. No sleep, no poll, no retry, no time limit and no timeLimit trait.

- [ ] Find a way to test the item in the split view that is certain on each run: a fixed order that the code proves, and no wait that can wait without end.
- [ ] Do this card only when such a way is found. If no way is found, record the reason on this card.

Write all text in STE.