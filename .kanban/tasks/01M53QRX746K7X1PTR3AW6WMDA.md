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
- actor: claude-code
  id: 01m54nz9y4s5rd9zgzr3cpztv1
  text: |-
    ### Research (2026-10-17): a certain way is found (lldb call stacks, one run each)
    - lldb breakpoint on SplitViewCoordinator.updateInspector: the press calls HostedViewHarness.render() (HostedViewHarness.swift:183), then NSHostingView.layout(), SystemSplitView.updateNSViewController(_:context:), SplitViewCoordinator.updateInspector(_:with:animated:), onNextMainRunLoop(do:), -[NSRunLoop performInModes:block:] with the mode kCFRunLoopCommonModes, and CFRunLoopPerformBlock. This is one synchronous call chain inside render().
    - lldb breakpoint on CFRunLoopPerformBlock: between the end of the press and the KVO change of isCollapsed, no other block is added. The block from updateInspector runs in __CFRunLoopDoBlocks and sets isCollapsed to false in the same call (KVO stack). After that block, the name element of the inspector is in the accessibility tree.
    - Order proof: CFRunLoop.c (open source) adds each block of CFRunLoopPerformBlock at the end of the block list, and __CFRunLoopDoBlocks runs the list from the start, for each block whose mode is the current mode or a common mode. Thus a test block that RunLoop.main.perform(inModes: [.common]) adds after render() runs after the SwiftUI block.
    - No wait without end: the main actor of the test runs on the main run loop in the default mode, which is a common mode, so the run loop runs the test block. The test block resumes a continuation, so the test does not poll and has no time limit.
    - Plan: a test support function that adds one common-mode block to the main run loop and waits for it, with a doc that gives this proof. Two hosted tests: (1) chip press with no animation, the fence, render, then require that the inspector item is not collapsed and the name element and the 5 actions show; (2) thread view host selection with no animation, render() (so that the enqueue is inside a render), the fence, render, check. Mutation check: when the binding stays false, the item stays collapsed after the fence and the test fails at once.
    - If SwiftUI changes this chain, the test fails on each run. It does not fail only sometimes, because no step depends on time.
  timestamp: 2026-10-17T10:19:28.068656+00:00
- actor: claude-code
  id: 01m54pr3j9af7y1s7vj4mcn9tn
  text: |-
    ### Implementation (2026-10-17)
    - New file Sources/AgentViewKitTestSupport/RunLoopBlockFence.swift: public `RunLoopBlockFence.afterPendingBlocks()`. It adds one block with `RunLoop.main.perform(inModes: [.common])`, calls `CFRunLoopWakeUp` on the main run loop, and waits with a checked continuation inside `withTaskCancellationHandler`. The internal class `RunLoopBlockFence.Release` (a Mutex and a state enum: waiting, armed, released) makes sure that the resume runs only one time, from the fence block or from the cancel handler.
    - Added to the plan, not a change of it: the call to `CFRunLoopWakeUp`. Reason: in CFRunLoop.c (swift-corelibs-foundation, main branch, read on 2026-10-17), the body of `CFRunLoopPerformBlock` adds the item to the list and does not wake the run loop. Without a wake, the block runs only when another source wakes the run loop.
    - Source facts that the doc uses, read in the downloaded sources: `CFRunLoopPerformBlock` sets `_blocks_tail->_next = new_item` under the lock of the run loop; `__CFRunLoopDoBlocks` takes the list from `_blocks_head` and runs a block when its mode equals the current mode, or when its mode is kCFRunLoopCommonModes and the common modes hold the current mode; an array of modes becomes a set with the same test. `__CFRunLoopCreate` adds kCFRunLoopDefaultMode to `_commonModes`. `CFRunLoopRun` calls `CFRunLoopRunSpecific(CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, ...)`. In the swift repository, stdlib/public/Concurrency/CFExecutor.swift: `CFMainExecutor.run()` calls `CoreFoundation.CFRunLoopRun()`.
    - Sample facts that the doc uses (scratchpad lldb1.txt and lldb2.txt): thread 1 (com.apple.main-thread) runs main, swift_task_asyncMainDrainQueue, swift_task_asyncMainDrainQueueImpl, CFMainExecutor.run(), CFRunLoopRun, __CFRunLoopRun, __CFRunLoopDoBlocks, and then the SwiftUI closure of updateInspector that sets isCollapsed to false (KVO stack). `-[NSRunLoop performInModes:block:]` calls `CFRunLoopPerformBlock` (lldb1), and the modes argument is kCFRunLoopCommonModes (lldb2, po $x2).
    - Tests of the fence: Tests/AgentViewKitTests/TestSupport/RunLoopBlockFenceTests.swift. (1) A common-mode block that was added before the fence ran when the fence returns. (2) A release after the arm runs the action one time, also with a second release. (3) An arm after the release runs the action at once. The tests of the release are synchronous and do not wait.
    - Not tested, and why: a test that a cancelled task ends the wait of the fence itself is not certain. The fence block always runs, so such a test passes also when the cancel handler does nothing. A test that blocks the run loop to prevent the block can wait without end when the handler is wrong. Thus the tests check the one-time release directly, and the doc and the code show that the cancel handler calls the same release.
    - Hosted tests in AttachmentInspectorHostedTests: `aPressOnAChipShowsTheInspectorItemOfTheSplitView()` and `theSelectionOfTheHostOfAThreadViewShowsTheInspectorItemOfTheSplitView()`. Each test requires that the inspector item is collapsed at the mount, then makes the change, the fence and render(), and then requires that the item is not collapsed, and expects the name label and the 5 action identifiers. The helper `inspectorItem(in:)` uses only public API: NSSplitView, its delegate as NSSplitViewController, splitViewItems and behavior .inspector.
    - The suite doc, the two gap notes and the doc of withoutAnimation now say only what the code and the tests show. The old claim that the animation does not end in a window that is not on a screen is removed, because no test checks it.
    - RED (stub fence and stub release, one run): the 5 new tests failed for the expected reasons (flag not set, count 0, and `!item.isCollapsed` at the check of both hosted tests). GREEN (one run): `swift test --skip-build --filter "RunLoopBlockFenceTests|AttachmentInspectorHostedTests"` gave 16 tests in 2 suites passed.
    - Build note: each `swift build --build-tests` writes one line "warning: missing creator for mutated node" for .build/out/Products/Debug/mlx-swift_Cmlx.bundle. It comes from the build system for a dependency bundle, also in the first build before the new code was used. It is not a compiler warning of this package.
  timestamp: 2026-10-17T10:33:00.745319+00:00
- actor: claude-code
  id: 01m54prdfcmnby98fcp459q8zp
  text: |-
    ### Mutation check (2026-10-17, one run, not committed)
    - Mutation: in Sources/AgentViewKit/Attachments/AttachmentInspector.swift, the get closure of the binding of AttachmentInspectorModifier was changed from `attachment != nil` to `false`.
    - One build and one run: `swift test --skip-build --filter "ShowsTheInspectorItemOfTheSplitView"`. Result: 2 tests in 1 suite failed with 2 issues. Both tests failed at the require of `!item.isCollapsed` in requireInspectorItem(in:showsTheNameOf:): aPressOnAChipShowsTheInspectorItemOfTheSplitView() after 0.256 seconds, theSelectionOfTheHostOfAThreadViewShowsTheInspectorItemOfTheSplitView() after 0.136 seconds. The fence returned, and no test waited without end.
    - The mutation is undone. `git diff --stat -- Sources/AgentViewKit/Attachments/AttachmentInspector.swift` shows no change. One more `swift build --build-tests` made the build output match the source again (exit 0).
  timestamp: 2026-10-17T10:33:10.892605+00:00
- actor: claude-code
  id: 01m54prk8phrfqp7qhj5jfyxmf
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKitTestSupport/RunLoopBlockFence.swift (new), Tests/AgentViewKitTests/TestSupport/RunLoopBlockFenceTests.swift (new), Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift (2 new hosted tests, 3 helpers, suite doc, 2 gap notes, withoutAnimation doc). `swift build --build-tests` exit 0. `swift test --skip-build --filter "RunLoopBlockFenceTests|AttachmentInspectorHostedTests"`: 16 tests in 2 suites passed. Mutation check: 2 of 2 new hosted tests failed at once, no hang; the mutation is undone, and AttachmentInspector.swift has no diff. All 9 checklist items are checked. No commit and no push.
    - next: /review
  timestamp: 2026-10-17T10:33:16.822333+00:00
- actor: claude-code
  id: 01m54q0effsjvvcdmdekyek6t3
  text: |-
    ### test - green
    - evidence: swift build --build-tests complete. One full swift test --skip-build: 1319 tests in 154 suites passed, 0 failed, 0 skipped. The 2 known issues are the planned negative tests aWrappedTextWithAFixedVerticalSizeFails and aViewThatIgnoresTheThemeFails, and both tests passed. The two new split view tests passed: aPressOnAChipShowsTheInspectorItemOfTheSplitView and theSelectionOfTheHostOfAThreadViewShowsTheInspectorItemOfTheSplitView. The demo gate was not run (no Examples change).
    - next: review
  timestamp: 2026-10-17T10:37:34.063918+00:00
position_column: doing
position_ordinal: '80'
title: Find a certain way to test that the AppKit split view shows the attachment inspector item
---
Found in ^kk004eb. No hosted test proves that the AppKit split view shows the attachment inspector item after a chip press or after a host selection of a thread view. The state tests in Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift check only the input to the split view: the selection, and the selection that AgentThreadView gives to its inspector.

Facts:
- In ^kk004eb, one main-queue hop and one render showed the item in the runs. But the code does not prove the order. The work that shows the item is in SwiftUI and AppKit. It can be a run loop observer, a run loop perform, a timer with zero delay, or a Core Animation transaction commit. These do not have a FIFO order with the blocks of the main dispatch queue. Thus such a test can fail only sometimes. The step owner removed those tests and the MainQueueHop helper (decision option C).
- A wait on an event that the inspector content sets in onAppear can wait without end when the split view does not show the item. A hosted test holds HostedTestLock and a wait has no time limit, so this breaks the test rule in the doc of HostedViewHarness.
- The rules do not permit an XCUITest or waitForExistence. No sleep, no poll, no retry, no time limit and no timeLimit trait.

- [x] Find a way to test the item in the split view that is certain on each run: a fixed order that the code proves, and no wait that can wait without end. Found on 2026-10-17: a run loop block fence (see the research comments).
- [x] Do this card only when such a way is found. If no way is found, record the reason on this card. A way is found, and the step owner accepted it with the conditions below.

## Accepted plan (step owner, 2026-10-17)
- [x] Test support: one public fence function (for example `RunLoopBlockFence.afterPendingBlocks()` in Sources/AgentViewKitTestSupport). It adds one block to the main run loop with `RunLoop.main.perform(inModes: [.common])` and waits for it with a continuation. The wait ends at once when the test task is cancelled (withTaskCancellationHandler, with a resume that runs only one time).
- [x] The doc of the fence gives the two proofs: (a) CFRunLoop.c adds each block of CFRunLoopPerformBlock at the end of the list, and __CFRunLoopDoBlocks runs the list from the start, so the fence block runs after each common-mode block that was added before it; (b) the block always runs in the test process: the sampled stacks show main, swift_task_asyncMainDrainQueue, CFMainExecutor.run() and CFRunLoopRun, so the main run loop turns in the default mode (a common mode) while the test awaits. Name the source of each proof.
- [x] The doc limits the claim: the order is proven only for the sampled chain (HostedViewHarness.render(), NSHostingView.layout(), SplitViewCoordinator.updateInspector, onNextMainRunLoop, -[NSRunLoop performInModes:block:] with kCFRunLoopCommonModes, CFRunLoopPerformBlock). If a later SwiftUI moves that work to the main dispatch queue or to a Core Animation commit, the order to the fence is not fixed, and the test can then fail only sometimes.
- [x] Hosted test 1: a chip press with no animation; require the selection at once; the fence; render(); then require that the inspector split view item (NSSplitViewItem with behavior .inspector in the window) is not collapsed, and that the name element (label of the file) and the 5 action identifiers show.
- [x] Hosted test 2: AgentThreadView with a host selection; select with no animation; require the selection at once; render() (so that the enqueue is inside a render); the fence; render(); the same checks.
- [x] Mutation check (one run, not committed): when the binding stays false, the item stays collapsed after the fence and the test fails at once with no hang. Record the result on this card.
- [x] Keep all state tests that exist. The new hosted tests are in addition to them. Update the suite doc, the two gap notes and the withoutAnimation doc so that they say only what the code and the tests show.

## Rule for these tests
A failure of these tests is treated as a SwiftUI change. Investigate it with a new sample (an lldb call stack of the enqueue). Do not run the tests again to find the cause, and do not add a retry.

Write all text in STE.