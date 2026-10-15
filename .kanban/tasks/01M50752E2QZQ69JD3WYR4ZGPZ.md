---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m50fs352n907jrcsbzdahq2c
  text: |-
    Implementation done. In `aChangeOfTheAgentStateSendsNoFrame`, the test now keeps `let model = session.model`. After it sends `idle`, it waits with `ObservationWait.until { CancelAvailabilityTests.isIdle(model.agentState) }`, then calls `harness.render()` (from T4-A0, ^gq8h07p), then counts the frames. The `harness.pump(until:)` wait on the Send button is removed. No other test changed. The helper `startRunning` still uses `pump(until:)`; the card did not include it, so it stays as is.

    Note: the build output has one warning from the build system: "missing creator for mutated node: .../mlx-swift_Cmlx.bundle/Contents/MacOS". It comes from the mlx-swift dependency bundle, not from this change.

    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift; `swift test --filter 'ComposerSessionModelHostedTests'` exit 0, 10 tests in 1 suite passed, 0 failed.
    - next: test, review
  timestamp: 2026-10-15T19:14:15.330616+00:00
- actor: claude-code
  id: 01m50gwwa2vvwq769xywfkm5n4
  text: |-
    ### test - green
    - evidence: One run of swift test. Exit 0. Swift Testing: 1201 tests in 138 suites passed with 2 known issues. 0 failures. 0 skipped. The 2 known issues are expected failures in tests that check the failure path (HostedLayoutExpectationsTests.swift:23:60 and ThemeHeightExpectationsTests.swift:35:61). Both tests passed.
    - warnings: 0 from project sources. Only the mlx-swift "missing creator for mutated node" warning from a dependency.
    - readme gate: Scripts/check-readme.sh passed.
    - resolved revisions: FoundationModelsACPClient 9cedcb9cf6b5e21f01ed2d3ef469f99d6666cd5a; FoundationModelsACP fb55b2fe90c124863dc3e5e907cd0ff070f61885; FoundationModelsACPAgent 180333bac6d48bc87ddd2cdd3522e95e7cb96599; FoundationModelsRouter fa9bf08885099ad4397772750eb98ad9323ce04e; FoundationModelsExtras dbd91deb34062d9e25655ed64bd41f0d7493cc0d.
    - log: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/swift-test-7.log
    - next: Push is decided by this green result.
  timestamp: 2026-10-15T19:33:47.970280+00:00
- actor: claude-code
  id: 01m50hddvc8w125gxgxt7tpasp
  text: |-
    ### review — clean
    - evidence: review sha ee43eb9~1..ee43eb9 — 0 findings (0 confirmed, 1 refuted, 7 attempted, 0 failed). 1 file reviewed.
    - next: none. The task moved to done.
  timestamp: 2026-10-15T19:42:50.220568+00:00
- actor: claude-code
  id: 01m50hv3ysj3hw2cc2n4zczvnv
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — ComposerSessionModelHostedTests.swift
    - test: green — swift test, 1201 passed in 138 suites (1 run)
    - commit: ee43eb9 (pushed in 277f657)
    - review: clean — 0 findings
  timestamp: 2026-10-15T19:50:18.841129+00:00
position_column: done
position_ordinal: ffc280
title: 'Test: aChangeOfTheAgentStateSendsNoFrame waits for a Send button that now shows at all times'
---
`Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift` `aChangeOfTheAgentStateSendsNoFrame` sends `running`, then `idle`, and waits with `harness.pump(until:)` until the Send button shows. After G4 of ^pvje3w3, the Send button shows at all times, also while the agent runs. Thus the wait ends at once, before the client reads the `idle` update, and the test can count the frames before the idle is folded.

Change: wait for the event that the model has the idle state (`ObservationWait.until { CancelAvailabilityTests.isIdle(model.agentState) }`), then count the frames. Remove the `pump(until:)` wait. Fixed-order test, no clock wait. #mail-step-7