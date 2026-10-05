---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m46yd6e7cs8nk8egyrtbdpg3
  text: |-
    Research and measurement (all runs on an idle machine, limit 5 seconds, JSON event stream of swift-testing):

    - HEAD (17a7900), full `swift test`: 4 runs passed. The direct swiftpm-testing-helper run of AgentViewKitTests: 5 runs passed. The slowest ACP test (ACPDemoSessionTests.eachTurnGivesANewReply, 3 bounded operations) took 1.5 to 2.5 seconds. In the first 12 seconds of each run, the largest time between two test ends was 0.65 seconds.
    - HEAD~1 (ecb960e) in a scratch worktree, full `swift test`: 3 runs. The slowest ACP test took 1.8 to 2.4 seconds. Thus ^repfza1 did not add a stall. (MathEngineDecisionTests fails in a worktree only, because of the path. It is not related.)
    - One run failed: 8 ACP tests passed the 5-second limit. In that run, `sample` attached to the test process at launch with a 1 ms interval. The log has 3.4 seconds with no test end, and the first hosted test took 5 seconds. The sample shows no main-thread work for that time. The sampler stopped the process. This is a measurement artifact, not a stall in the code.
    - Why ACP tests wait for the main actor: the AgentViewKitTests target has `.defaultIsolation(MainActor.self)`, so each test runs on the main actor. HostedViewHarness.pump runs a nested run loop inside a main-actor job. The nested run loop does not drain the main dispatch queue (the sample shows `__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__` only in the top-level run loop). Hosted tests used about 92% of the main-thread samples. Thus each ACP step that goes to the main actor waits up to one pump (50 ms). This is not a stall, and it was the same before ^repfza1.
    - Result: no cause of a 9-second stall is in the code of this repository. The probable cause of the 9-second stall in the ^repfza1 test step is load from other processes on the machine at that time. This is not proved.
  timestamp: 2026-10-05T21:09:38.887046+00:00
- actor: claude-code
  id: 01m46ydhvj41tdkw61g4zds01c
  text: |-
    ### implement — changed
    - Correction to the comment above: in the failed run, the sampler got 5074 samples in 14 seconds at a 1 ms interval, so it stopped the process for most of the time. The samples of the first hosted test are about 0.6 seconds, not 5 seconds. Thus the 3.4-second gap is from the sampler, not from the code.
    - TDD: new test ScriptedWireAgentBoundedTests.theOperationLimitIsAtMostFiveSeconds failed with the limit 60 (RED), and passed with the limit 5 (GREEN).
    - Files: Tests/AgentViewKitTests/ACP/ScriptedWireAgent+Bounded.swift (limit 60 to 5, new doc comment with the cause of the wait and the rule not to make the limit larger), Tests/AgentViewKitTests/ACP/ScriptedWireAgentBoundedTests.swift (new guard test).
    - evidence: full `swift test` 2 runs after the change: 1295 tests in 114 suites passed each time, 0 warnings in the test output. The slowest ACP test took 1.9 and 1.5 seconds.
    - next: /review
  timestamp: 2026-10-05T21:09:50.578710+00:00
position_column: doing
position_ordinal: '80'
title: Find the main-actor stall at the start of the full swift test run
---
## What
In the full `swift test` run after ^repfza1, ACP tests that use `bounded(_:)` passed the 5-second limit, because the main actor was busy for about 9 seconds at the start of the run. Run alone, these tests pass. The test step raised `operationLimitSeconds` in `Tests/AgentViewKitTests/ACP/ScriptedWireAgent+Bounded.swift` from 5 to 60. That hides the stall. Find what blocks the main actor (for example a hosted view test, a SessionModel test or a test helper from ^repfza1), remove the cause, and put the limit back to a small value.

- [x] Measure the main-actor stall in the full run and find its source.
- [x] Remove the cause. (No cause is in the code of this repository. See the comments for the evidence.)
- [x] Put `operationLimitSeconds` back to 5 seconds or less.

## Acceptance Criteria
- [x] The full `swift test` passes two times with the small limit.

## Tests
- [x] `swift test` passes two times.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.