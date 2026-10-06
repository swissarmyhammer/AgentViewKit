---
assignees:
- claude-code
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
position_column: todo
position_ordinal: a280
title: Add the in-process helper and the ACP client and in-process README quick starts
---
## What
Source: update.md §8 items 1 and 4, §7 item 4 (README snippets). This task runs before the adapter removal, so that no snippet uses `ACPThreadSource` or the old `AgentThreadView(thread:actions:)` initializer when they are deleted. Owner rule (2026-10-06): the views bind directly to the observable model of FoundationModelsACPClient. The helper and the snippets show this: they give the views the `ConnectionModel` and the `SessionModel`, and keep no copy of their state.

- [ ] Add `Sources/AgentViewKit/ACP/InProcessAgent.swift`: a helper that pairs `InMemoryTransport.pair()`, gives one end to an `AgentSideConnection` with a host-given `Agent`, and connects a `ConnectionModel` over the other end. The helper returns the `ConnectionModel`; it keeps no connection state or session list of its own. The helper must not import FoundationModelsACPAgent; the host gives the `Agent` (for example `RoutedACPAgent`).
- [ ] Rewrite `Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift` and `HostApp.swift`, and their README blocks, on `ConnectionModel` and `AgentThreadView(session:actions:)`. The snippets hold the models only; they show no `PromptQueue`, no kit state object and no copy of a model value.
- [ ] Add `Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift` and its README block on the helper.
- [ ] Run `Scripts/extract-readme-snippets.sh`.

## Acceptance Criteria
- [ ] A test connects through the helper to `InMemoryDemoAgent`, opens a session and gets an agent message in `SessionModel.transcript`.
- [ ] The test reads the connection state from `ConnectionModel.state` of the returned model (the helper has no state property of its own).
- [ ] No snippet and no README block uses `ACPThreadSource`, `AgentThread` or `AgentThreadView(thread:actions:)`.
- [ ] `Scripts/check-readme.sh` passes and `ReadmeCoverageTests` cover the two quick starts.

## Tests
- [ ] `Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift`: connect, initialize, new session, one prompt round trip; the connection state of the model becomes `.disconnected` after close.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.