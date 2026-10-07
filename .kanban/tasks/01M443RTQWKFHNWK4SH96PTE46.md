---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4aczwv83z74qyb6a6p5bpy7
  text: |-
    Research (implement step):
    - `InMemoryDemoAgent` is a wire-level script (`ScriptedWireAgent` on an `InMemoryTransport`). It is not an ACP `Agent`. The helper takes an `Agent` for an `AgentSideConnection`. Thus the test cannot connect the helper to `InMemoryDemoAgent` as it is. Plan: add a typed `Agent` form of the demo agent in `DemoSupport` (`InMemoryDemoACPAgent`). It decodes the same scripted results of `InMemoryDemoAgent` and sends the same turn updates, so the script data stays in one place.
    - `AgentSideConnection` does not close its transport when it closes. `RoutedACPAgent` keeps its connection weakly ("the caller of AgentSideConnection.init keeps the connection"). Thus the helper keeps the agent connection alive with one task that waits for `AgentSideConnection.closed`, and then closes the two transport ends. The client read ends, and `ConnectionModel.state` becomes `.disconnected`.
    - Missing client API: `ConnectionModel` has no public method that closes the connection (its `connection` property is internal, and `connect(over:)` returns the `ClientSideConnection`). A host that has only the `ConnectionModel` cannot close it. The helper returns only the model, as the card says, so a host closes the in-process connection from the agent side (`AgentSideConnection.close()`).
    - `ClientSideConnection.initialize` throws `ProtocolVersionMismatchError` when the versions differ, so the README v1 sentence can name `initialize` only.
    - In the session path, the views call the models directly. The actions get only the terminal sign-in verbs. The snippets pass `LoggingThreadActions`, because `ACPThreadActions` needs an `AgentThread`.
  timestamp: 2026-10-07T05:22:15.016663+00:00
- actor: claude-code
  id: 01m4advpx70a25t770bbf8yn8h
  text: |-
    Implementation landed (TDD):
    - RED 1: `InProcessAgentTests` did not compile (no `InProcessAgent`, no `InMemoryDemoACPAgent`). GREEN: 3 tests pass (connected model, prompt round trip with the reply in `SessionModel.transcript`, `.disconnected` after the agent closes).
    - RED 2: two new `ReadmeCoverageTests` failed (no `InProcessQuickStart` snippet; the old blocks used `ACPThreadSource`, `AgentThread` and `AgentThreadView(thread:`). GREEN after the README rewrite and `Scripts/extract-readme-snippets.sh`.
    - Helper: `InProcessAgent.makeConnection(serving:)` returns only the `ConnectionModel`. It does not import FoundationModelsACPAgent. One task keeps the `AgentSideConnection` until it closes, then closes the two pair ends.
    - Demo agent: `InMemoryDemoACPAgent` (actor, `Agent`) in DemoSupport. It decodes the scripted results of `InMemoryDemoAgent`. `InMemoryDemoAgent.turnFrames` now wraps the new `turnNotifications(for:turn:)`, so both agents send the same turn and the script stays in one place.
    - Test time limit: `ScriptedWireAgent.bounded` now calls the new `ACPTestTimeLimit.run(stopping:_:)`, so the in-process test uses the same 5-second limit with no copy of the watchdog.
    - Snippets: `ACPQuickStart` (models only, `ACPThread` view sets `\.sessionModel` and `\.connectionModel`), `InProcessQuickStart` (on the helper, reuses `ACPQuickStart.openSession`), `HostApp` (holds one `ConnectionModel`, shows its open session through `ACPThread` and the override modifiers). The snippets pass `LoggingThreadActions`, because the session views call the models directly.
    - Missing client API (report only): `ConnectionModel` has no public close (for example `ConnectionModel.disconnect()`), so a host cannot close a connection from the model. The in-process connection closes from the agent side.
    - The README intro prose and the Components list still name `AgentThread`; ^g95wwbs owns them.
  timestamp: 2026-10-07T05:37:26.439451+00:00
- actor: claude-code
  id: 01m4advthhxzbtqgc3drp6v9eh
  text: |-
    ### implement — changed
    - evidence: new Sources/AgentViewKit/ACP/InProcessAgent.swift, Sources/DemoSupport/InMemoryDemoACPAgent.swift, Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift, Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift; changed Sources/DemoSupport/InMemoryDemoAgent.swift, Tests/AgentViewKitTests/ACP/ScriptedWireAgent+Bounded.swift, Tests/PackageStructureTests/ReadmeCoverageTests.swift, README.md, Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift, Examples/ReadmeSnippets/Snippets/HostApp.swift. `swift test`: 1390 tests in 128 suites, 80 tests in 12 suites and 1 test passed, only the mlx-swift `missing creator` warning. `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo`: BUILD SUCCEEDED, TEST SUCCEEDED (2 tests), no Swift warning outside mlx-swift. ^zcktrsh and ^vhp5fv7 did not fail.
    - next: /review
  timestamp: 2026-10-07T05:37:30.161346+00:00
- actor: claude-code
  id: 01m4ae9facabh5whmn01pkbw34
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit a722db6). 0 findings, 0 confirmed, 0 refuted. 9 files reviewed. README.md was not reviewed (no validator matches this file). 4 .kanban files were not reviewed (.reviewignore).
    - next: none. The task is in done.
  timestamp: 2026-10-07T05:44:57.420961+00:00
- actor: claude-code
  id: 01m4ae9gqt4e3v2pd5sxfc9z64
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — InProcessAgent.makeConnection(serving:) returns only the ConnectionModel; InMemoryDemoACPAgent; ACPTestTimeLimit; README quick starts on the session view; InProcessAgentTests (new)
    - test: green — swift test, 1390 passed; README and demo UI gates passed
    - commit: a722db6
    - review: clean — 0 findings
  timestamp: 2026-10-07T05:44:58.874041+00:00
depends_on:
- 01M443NW9A12NWXYHJFYTTTA85
- 01M443P38JZMBRSCEPWCS25T9A
- 01M443P9HZRX2SYRH92DVA3ERH
- 01M443PR0KRA98QJ71SSZMAEF8
- 01M443PX0SR6A8FS2E33HZAMRW
- 01M443Q580KBFG7JE5M6A6X9X9
- 01M443QAWWDY730CX0EDPG4T4Z
- 01M443QG7ASDC8T3C76RDK4W45
- 01M443QS68DG8EJ9NEKCCHG10S
- 01M443QWQ6X9S6KT61DS8SQ0BF
- 01M443R0ZPXK0337AT3CX8JHPP
- 01M49HGF5KFW6185XJATDG13NJ
position_column: done
position_ordinal: ff8280
title: Add the in-process helper and the ACP client and in-process README quick starts
---
## What
Source: update.md §8 items 1 and 4, §7 item 4 (README snippets). This task runs before the adapter removal, so that no snippet uses `ACPThreadSource` or the old `AgentThreadView(thread:actions:)` initializer when they are deleted. Owner rule (2026-10-06): the views bind directly to the observable model of FoundationModelsACPClient. The helper and the snippets show this: they give the views the `ConnectionModel` and the `SessionModel`, and keep no copy of their state.

- [x] Add `Sources/AgentViewKit/ACP/InProcessAgent.swift`: a helper that pairs `InMemoryTransport.pair()`, gives one end to an `AgentSideConnection` with a host-given `Agent`, and connects a `ConnectionModel` over the other end. The helper returns the `ConnectionModel`; it keeps no connection state or session list of its own. The helper must not import FoundationModelsACPAgent; the host gives the `Agent` (for example `RoutedACPAgent`).
- [x] Rewrite `Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift` and `HostApp.swift`, and their README blocks, on `ConnectionModel` and `AgentThreadView(session:actions:)`. The snippets hold the models only; they show no `PromptQueue`, no kit state object and no copy of a model value.
- [x] Add `Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift` and its README block on the helper.
- [x] Run `Scripts/extract-readme-snippets.sh`.

## Acceptance Criteria
- [x] A test connects through the helper to `InMemoryDemoAgent`, opens a session and gets an agent message in `SessionModel.transcript`.
- [x] The test reads the connection state from `ConnectionModel.state` of the returned model (the helper has no state property of its own).
- [x] No snippet and no README block uses `ACPThreadSource`, `AgentThread` or `AgentThreadView(thread:actions:)`.
- [x] `Scripts/check-readme.sh` passes and `ReadmeCoverageTests` cover the two quick starts.

## Tests
- [x] `Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift`: connect, initialize, new session, one prompt round trip; the connection state of the model becomes `.disconnected` after close.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.