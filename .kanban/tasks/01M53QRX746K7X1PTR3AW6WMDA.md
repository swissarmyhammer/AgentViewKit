---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m54nhvgg5f89ae6a0ebfy15x
  text: |-
    ### Research (2026-10-17): diagnostic samples (scratchpad test, not committed)
    - The user wants this card done here, with the coordination of the step owner. The step owner and the other sessions know no proven way.
    - Fact 1: the SwiftUI inspector is an NSSplitView whose delegate is SwiftUI.SplitViewController. It has 2 items. The inspector item has behavior 3 (inspector). It is collapsed at the mount.
    - Fact 2: after the chip press (in a transaction with disablesAnimations) and 2 more harness.render() calls, the item stays collapsed (isCollapsed true, view not in the window). No KVO change of isCollapsed comes in a render. Thus layoutSubtreeIfNeeded does not show the item, and a test with no wait cannot see it.
    - Fact 3: the KVO change of isCollapsed to false comes from a CFRunLoop block (__CFRunLoopDoBlocks), in a SwiftUI closure (symbol near Transaction.addAnimationListener(allFinished:)). It is not a block of the main dispatch queue. Thus the old hop test passed only because of the order of the run loop work.
    - Fact 4: the public Transaction.addAnimationCompletion(criteria:) completion runs from a dispatch source of the main queue (Transaction.dispatchPending, AllFinishedListener.finalizeTransaction). It is not the same mechanism as fact 3, so no document gives the order between them. The completion is not a correct fence.
    - Candidate: CoreFoundation is open source, and __CFRunLoopDoBlocks runs the blocks in FIFO order. If SwiftUI enqueues its block (CFRunLoopPerformBlock) inside render(), a test block that is enqueued after render() runs after it. Next step: read the call stack of the enqueue with an lldb breakpoint on CFRunLoopPerformBlock (this reads the stack, it measures no time).
  timestamp: 2026-10-17T10:12:07.312338+00:00
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