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
position_column: todo
position_ordinal: a380
title: Move the demo app to ConnectionModel and remove ACPDemoSession
---
## What
The demo app and the README use `ConnectionModel` as the session controller, not `DemoSupport`. Source: update.md §8 items 1 to 3. Owner rule (2026-10-06): the demo views bind directly to the observable model of FoundationModelsACPClient and call its methods. At present `ACPDemoSession` (`Sources/DemoSupport/ACPDemoSession.swift`) keeps copies of model data: a connection state, an `AgentThread`, the session id, `canDeleteSessions`, the auth methods (converted with `SessionUpdateMapping.authMethod`), an `ACPSessionList`, and a mirror of the agent connection in `ConnectionStore`.

- [ ] Change `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift`, `ACPSettingsSheet.swift` and `DemoRootView.swift` to hold a `ConnectionModel` and the selected `SessionModel` only. Each view reads `state`, `sessions`, `authMethods`, `authState`, the capability flags and `openSessions` directly from the model. Subprocess agents start with `AgentProcess` and the `acp` subcommand; the in-memory agent uses the in-process helper when it exists, else `InMemoryTransport.pair()` directly.
- [ ] Remove `Sources/DemoSupport/ACPDemoSession.swift` and `Tests/AgentViewKitTests/ACP/ACPDemoSessionTests.swift` (or the moved path). Keep `ScriptedWireAgent`, `InMemoryDemoAgent` and `DemoLaunchOptions`. No demo code writes the agent connection state into `ConnectionStore`.
- [ ] Selecting a session in the sidebar calls `ConnectionModel.resumeSession(_:)` with `replayFrom: .start` and shows the history from `SessionModel.transcript`.
- [ ] Change `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift` for the new flow.

## Acceptance Criteria
- [ ] No file uses `ACPDemoSession`.
- [ ] No demo type keeps a copy of a `ConnectionModel` or `SessionModel` value (connection state, session id, auth methods, session list, capability flags).
- [ ] The end-to-end test sends a prompt to the in-memory agent and finds the answer row; a second test selects a saved session and finds its replayed message; a third test closes the transport and finds the disconnected banner from `ConnectionModel.state`.
- [ ] `Scripts/test-examples.sh AgentViewKitDemo` passes.

## Tests
- [ ] `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift`: prompt round trip; resume with history; disconnected banner after a transport close.
- [ ] `Scripts/test-examples.sh AgentViewKitDemo` exits with 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.