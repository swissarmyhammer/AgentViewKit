---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m48rjexnqcrjzxpyzqcsa5q8
  text: 'Note from ^rdk4w45: `ACPDemoSession` now has a public `connectionModel`, `sessionID: SessionId?` and `open(_ session: SessionModel)`. `selectSession(_:)`, `sessionList` and `canDeleteSessions` are removed. `ACPTabView` shows `SessionListView(connection:cwd:onOpen:onNewSession:)`. The detail still uses the deprecated `AgentThreadView(thread:actions:)`, so the demo sends no `session/close`. When this card moves the detail to `AgentThreadView(session:connection:actions:)`, the close works.'
  timestamp: 2026-10-06T14:06:08.821325+00:00
- actor: claude-code
  id: 01m4aeprjb4ztfkmens7r7v2t3
  text: |-
    Research (implement, 2026-10-07):
    - Pins in .build/checkouts: FoundationModelsACP fe0d82d, FoundationModelsACPClient be7e615. ConnectionModel has no disconnect(); ClientSideConnection.close() exists but InProcessAgent.makeConnection hides the client end. To close the transport, the demo closes the agent side: AgentSideConnection.close() for the in-process agent (the helper then closes both ends), AgentProcess.shutdown() for a subprocess. Both give ConnectionModel.state == .disconnected.
    - AgentProcess keeps no state that the demo must hold: the transport keeps the process state alive.
    - SessionListView already resumes with replayFrom: .start and gives the SessionModel to onOpen.
    - InMemoryDemoACPAgent.resumeSession replays nothing at present, so the resume test has no history to find. Plan: the agent sends a saved user message and a saved agent message before the resume result when replayFrom is .start.
    - Session rows have the identifier item-row-<rowKey>, for example item-row-agent-message-demo-reply-1 (TranscriptRowKey.swift).
    - SessionModel.appendError(reporting:) is internal to the kit, so the demo cannot use it.
    - AgentConnectionBox (private in InProcessAgentTests) is the same box the demo needs. Plan: move it to DemoSupport and use it from both places.
    - update.md names ACPDemoSession in its plan text only (sections 8 and 9.1). That text describes the old state; ^scefp8 rewrites the documents.
  timestamp: 2026-10-07T05:52:12.875464+00:00
- actor: claude-code
  id: 01m4afpms674v2k3552z9r3wk5
  text: |-
    Implementation landed (not committed):
    - New `Sources/DemoSupport/DemoAgent.swift`: `makeConnected(options:)` starts the agent (in-memory: `InProcessAgent.makeConnection` with `InMemoryDemoACPAgent`; else `AgentProcess` with `agentArguments(for:)`), connects a `ConnectionModel`, sends `initialize` with `DemoAgent.initializeRequest`, and stops the agent when `initialize` fails. `openSession()` sends `session/new` in the working directory. `stop()` closes the agent side (in-process) or shuts down the process. It keeps no model value: only the `ConnectionModel`, the working directory of the launch options and the runner.
    - `AgentConnectionBox` moved from InProcessAgentTests to `Sources/DemoSupport/AgentConnectionBox.swift` (public). The test uses it.
    - `InMemoryDemoACPAgent.resumeSession` with `replayFrom: .start` sends the saved history (`InMemoryDemoAgent.historyNotifications(sessionId:)`: one user message and one agent message) before the result. The shared `openConnection()` helper keeps the assertionFailure plus log.
    - ACPTabView holds `Phase { starting, failed(Error), running(DemoAgent, SessionModel) }`, a New Session failure, the draft and the sheet flag. It shows `SessionListView`, `AgentThreadView(session:connection:workingDirectory:actions:)` with `.messageFooter { MessageActions(entry:) }`, `ContextUsageView`, `PromptInputView`, `ConfigOptionsView`, a Stop Agent button (identifier demo-acp-stop-agent) and Settings. ACPSettingsSheet takes the two models and shows `AgentInfoHeader`, `AgentAuthView(connection:)`, `ConfigOptionsView(.form)` and `ConnectionsView` with no store (empty state). DemoRootView needed no change: it holds only the options and the tab.
    - Removed ACPDemoSession.swift and ACPDemoSessionTests.swift. The launch option tests moved to DemoLaunchOptionsTests; the chunk and prompt-text tests moved to InMemoryDemoAgentTests. KitInitializeRequestTests reads `DemoAgent.initializeRequest`.
    - RemovedVocabularyTests: new test `theDemoAppAndItsTestsUseNoRemovedDemoSymbol` scans Sources, Tests/AgentViewKitTests and Examples for `ACPDemoSession` and `agentConnectionID`. A shared `uses(of:below:)` helper replaces two copies of the scan loop.
    - Shared test helper `SessionModel.agentMessageText(id:)` (Tests/AgentViewKitTests/ACP/SessionModel+AgentMessageText.swift) replaces the private copy in InProcessAgentTests.
    TDD: unit RED was a compile failure for the missing symbols, then GREEN (18 tests). UI RED: with the old demo views (ACPDemoSession restored for one run), all 4 new UI tests failed for the expected reasons (no agent-message row id, no replay, no stop button, connection chip present). GREEN after the rewrite.
    Missing client API (reported, not built): `ConnectionModel.disconnect()` (planned in qjgmscm). The demo stops the agent instead, which gives `.disconnected` through the model.
    update.md still names ACPDemoSession in its plan text (sections 8 and 9.1); that text records the old state, and ^scefp8 rewrites the documents.
  timestamp: 2026-10-07T06:09:37.574684+00:00
- actor: claude-code
  id: 01m4afpv90gkbcj679ehbeg4kk
  text: |-
    ### implement — changed
    - evidence: added Sources/DemoSupport/DemoAgent.swift, Sources/DemoSupport/AgentConnectionBox.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift, Tests/AgentViewKitTests/ACP/InMemoryDemoAgentTests.swift, Tests/AgentViewKitTests/ACP/SessionModel+AgentMessageText.swift; changed Sources/DemoSupport/InMemoryDemoACPAgent.swift, Sources/DemoSupport/InMemoryDemoAgent.swift, Sources/DemoSupport/DemoLaunchOptions.swift (doc), Package.swift (comment), Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, ACPSettingsSheet.swift, Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift, Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb (comment), Tests/AgentViewKitTests/ACP/DemoLaunchOptionsTests.swift, InProcessAgentTests.swift, KitInitializeRequestTests.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift; deleted Sources/DemoSupport/ACPDemoSession.swift, Tests/AgentViewKitTests/ACP/ACPDemoSessionTests.swift. Gates: `swift test` 1386 tests in 129 suites passed plus 81 PackageStructureTests passed (only the mlx missing-creator warning); `Scripts/check-readme.sh` passed; `Scripts/test-examples.sh AgentViewKitDemo` passed (4 UI tests). The known unstable tests ^zcktrsh and ^vhp5fv7 passed in this run.
    - next: /review
  timestamp: 2026-10-07T06:09:44.224504+00:00
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
position_column: doing
position_ordinal: '80'
title: Move the demo app to ConnectionModel and remove ACPDemoSession
---
## What
The demo app and the README use `ConnectionModel` as the session controller, not `DemoSupport`. Source: update.md §8 items 1 to 3. Owner rule (2026-10-06): the demo views bind directly to the observable model of FoundationModelsACPClient and call its methods. At present `ACPDemoSession` (`Sources/DemoSupport/ACPDemoSession.swift`) keeps copies of model data: a connection state, an `AgentThread`, the session id, `canDeleteSessions`, the auth methods (converted with `SessionUpdateMapping.authMethod`), an `ACPSessionList`, and a mirror of the agent connection in `ConnectionStore`.

- [x] Change `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift`, `ACPSettingsSheet.swift` and `DemoRootView.swift` to hold a `ConnectionModel` and the selected `SessionModel` only. Each view reads `state`, `sessions`, `authMethods`, `authState`, the capability flags and `openSessions` directly from the model. Subprocess agents start with `AgentProcess` and the `acp` subcommand; the in-memory agent uses the in-process helper when it exists, else `InMemoryTransport.pair()` directly.
- [x] Remove `Sources/DemoSupport/ACPDemoSession.swift` and `Tests/AgentViewKitTests/ACP/ACPDemoSessionTests.swift` (or the moved path). Keep `ScriptedWireAgent`, `InMemoryDemoAgent` and `DemoLaunchOptions`. No demo code writes the agent connection state into `ConnectionStore`.
- [x] Selecting a session in the sidebar calls `ConnectionModel.resumeSession(_:)` with `replayFrom: .start` and shows the history from `SessionModel.transcript`.
- [x] Change `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift` for the new flow.

## Acceptance Criteria
- [x] No file uses `ACPDemoSession`.
- [x] No demo type keeps a copy of a `ConnectionModel` or `SessionModel` value (connection state, session id, auth methods, session list, capability flags).
- [x] The end-to-end test sends a prompt to the in-memory agent and finds the answer row; a second test selects a saved session and finds its replayed message; a third test closes the transport and finds the disconnected banner from `ConnectionModel.state`.
- [x] `Scripts/test-examples.sh AgentViewKitDemo` passes.

## Tests
- [x] `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift`: prompt round trip; resume with history; disconnected banner after a transport close.
- [x] `Scripts/test-examples.sh AgentViewKitDemo` exits with 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.