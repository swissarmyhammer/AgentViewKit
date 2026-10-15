---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m50fgymzg09kw6v2frk1hpx5
  text: |-
    ### Findings (render check and decisions)
    - Render check (HostedViewHarnessRenderTests, fixed order, no run loop turn): after a change of an @Observable model, `render()` (hostingView.layoutSubtreeIfNeeded + window.displayIfNeeded) alone puts the new text in the accessibility tree. After `accessibilityPerformPress` on a button, the action has run, and `render()` alone shows its result. Key events (sendKey, type), focus (focusFirstEditableTextView, @FocusState onAppear) and the slider increment also pass with `render()` only. The result is in the doc comment of `render()`.
    - A change from asynchronous work (an agent frame) needs the main actor to run other work first. For that, the new `render(when:)` awaits `ObservationWait.until(condition)` on model values, then calls `render()`. No time bound, no poll. Test: renderWhenShowsTheChangeOfATaskThatRunsAfterTheWaitStarts.
    - Deprecation: NOT done. The project rule is that a warning counts as red, and about 600 area calls would give deprecation warnings. The doc comments of `pump(for:)`, `waitUntil` (Polling.swift) and `pump(until:)` (HarnessWaiting.swift) now say "Do not use this function in a new test" and name the replacement (`render()`, `render(when:)`, `ObservationWait.until`).
    - `pump(for:)` keeps its clock wait, so that the area tests keep their behavior. press, increment, type, sendKey, sendKeyDown, focusFirstEditableTextView and frameHeight now call `render()`, not `pump()`.
    - Task.sleep: the search found 3: DemoAgentMessageIdTests (removed), ConfigOptionsSessionModelHostedTests (removed), and Polling.swift `waitUntil` (Sources, stays until T4 removes waitUntil; 39 uses remain in the area folders).
    - To wait on the scripted agent with no clock, ScriptedWireAgent (Sources/DemoSupport) is now `@Observable` and has `isHoldingAnswer`. The hold test now waits for `isHoldingAnswer`, and a lead-in of the marker method records the hold state when the agent reads the marker (expected `[false]`), so the test fails if the hold does not stop the reader.
    - Risk for the full run: press/increment/type/sendKey no longer turn the run loop for 0.05 s. An area test that reads an asynchronous result just after one of these calls, with no wait, can fail now. The filtered run did not cover the area folders.
  timestamp: 2026-10-15T19:09:48.575563+00:00
- actor: claude-code
  id: 01m50fh9c8z9r36449hv9t6aa8
  text: |-
    ### implement — changed
    - evidence: 13 source files. Sources/AgentViewKitTestSupport/HostedViewHarness.swift (render(), render(when:), actions render directly, pump(for:) doc names the replacement), Sources/AgentViewKitTestSupport/HostedViewHarness+TextViews.swift, Sources/AgentViewKitTestSupport/Polling.swift (doc only), Sources/DemoSupport/ScriptedWireAgent.swift (@Observable, isHoldingAnswer), Tests/AgentViewKitTests/Helpers/HarnessWaiting.swift (doc only), Tests/AgentViewKitTests/TestSupport/{HostedViewHarnessTests,HostedViewHarnessTextViewsTests,HarnessProgressIndicatorTests,BodyEvaluationCounterTests,ScriptedSessionTests}.swift, Tests/AgentViewKitTests/ACP/DemoAgentMessageIdTests.swift, Tests/AgentViewKitTests/Config/ConfigOptionsSessionModelHostedTests.swift, Tests/PackageStructureTests/ExampleGateTimeLimitTests.swift.
    - RED: swift build --build-tests failed with "value of type 'HostedViewHarness<CaptionView>' has no member 'render'". GREEN: swift test --filter (15 suites) one run: PackageStructureTests 1 test in 1 suite passed; AgentViewKitTests 83 tests in 14 suites passed, 1 known issue (existing, HostedLayoutExpectationsTests). Only the existing mlx-swift "missing creator" build warning.
    - not done by order: no @available deprecated (a warning counts as red). Polling.swift Task.sleep stays until T4 removes waitUntil.
    - next: /test (full run), then /review.
  timestamp: 2026-10-15T19:09:59.560454+00:00
- actor: claude-code
  id: 01m50fpwfq6rt1ecaf1pv3g28s
  text: |-
    ### Decision from the step owner: scope of A0 before the push
    Keep A0 to the harness and to the sites that the two bad-test fixes need (MathEngineDecisionTests, ParagraphReuseTests), so that the push comes soon. The folder groups A1 to A6 come after the push. The main tree moves onto the rebased branch step7-push first.
  timestamp: 2026-10-15T19:13:02.967565+00:00
- actor: claude-code
  id: 01m50gwqpjsy3rvzh9dtkxc6aa
  text: |-
    ### test - green
    - evidence: One run of swift test. Exit 0. Swift Testing: 1201 tests in 138 suites passed with 2 known issues. Earlier suite: 125 tests in 16 suites passed. Earlier suite: 1 test in 1 suite passed. 0 XCTest tests ran. 0 failures. 0 skipped.
    - known issues: The 2 known issues are expected failures in tests that check the failure path. They are HostedLayoutExpectationsTests.swift:23:60 (aWrappedTextWithAFixedVerticalSizeFails, "minimumSize.height <= sizeAtWidth.height") and ThemeHeightExpectationsTests.swift:35:61 (aViewThatIgnoresTheThemeFails, "themed > unthemed"). Both tests passed.
    - warnings: 0 from project sources. Only the mlx-swift "missing creator for mutated node" warning from a dependency.
    - readme gate: Scripts/check-readme.sh passed. Each snippet is in its file and compiles.
    - resolved revisions: FoundationModelsACPClient 9cedcb9cf6b5e21f01ed2d3ef469f99d6666cd5a; FoundationModelsACP fb55b2fe90c124863dc3e5e907cd0ff070f61885; FoundationModelsACPAgent 180333bac6d48bc87ddd2cdd3522e95e7cb96599; FoundationModelsRouter fa9bf08885099ad4397772750eb98ad9323ce04e; FoundationModelsExtras dbd91deb34062d9e25655ed64bd41f0d7493cc0d.
    - log: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/swift-test-7.log
    - code: HEAD 6beceed with the 4 uncommitted changes. No code changed in this step.
    - next: Push is decided by this green result.
  timestamp: 2026-10-15T19:33:43.250969+00:00
position_column: doing
position_ordinal: '8180'
title: 'Mail step 7 T4-A0: Give the test harness a direct render pass and remove the clock from pump, press, click and increment'
---
Part of T4 (^m7q9e97). Decisions of the step owner: no .timeLimit, sleep, clock wait, poll or retry in the tests; for a render wait, first make the render happen directly (layoutSubtreeIfNeeded on the hosting view, a display pass of the window), then check; where that is not enough, wait on an event (ObservationWait.until on a value that is certain to change), with no time bound; a hosted test holds HostedTestLock, so a wait with no bound must be for a certain event.

Work:
1. HostedViewHarness (Sources/AgentViewKitTestSupport/HostedViewHarness.swift): add a direct render pass (for example `render()`: layoutSubtreeIfNeeded on the hosting view, then displayIfNeeded on the window, with no clock). Change `pump()` / `press` / `increment` and the click helpers so that they use the render pass, not `RunLoop.main.run(before: deadline)`. Find out (with a small fixed-order test) whether a model change shows in the accessibility tree after the render pass only; record the result in the doc of `render()`. If some updates need a run loop turn, give a way that waits on an event, not on time (for example an async render that awaits ObservationWait on the model value, then renders).
2. Plan the removal of `pump(for:)` (fixed time), `waitUntil` (Sources/AgentViewKitTestSupport/Polling.swift) and `pump(until:)` (Tests/AgentViewKitTests/Helpers/HarnessWaiting.swift): mark them deprecated in this task (so that the area tasks find each use), and remove them in T4 when no use is left.
3. Remove the `.timeLimit` trait in ExampleGateTimeLimitTests.swift:53 (if the subject is the CI example time limit, check that value as data, with no trait).
4. Remove the 3 `Task.sleep` calls in the tests (find them), each with an event wait or a fixed order.
5. Update the tests of the harness (Tests/AgentViewKitTests/TestSupport/HostedViewHarnessTests.swift and others in TestSupport) to the new primitives.
One full run. Write all text in STE. #mail-step-7