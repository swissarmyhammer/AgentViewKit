---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m49jbfqr834p633z67mf3xej
  text: |-
    Research done.
    - The kit has no "waiting for background work" state, no "current turn" and no "last text time" in Sources/AgentViewKit. The "waiting" in ElicitationURLConsentView is the URL elicitation consent phase, not a run state. "current turn" occurs only in doc comments.
    - The transcript view (ConversationView, session source) shows `ForEach(session.transcript, id: \.id)`. A new `messageId` makes a new AgentMessageEntry in the client model, so two message rows come from the model with no kit code.
    - ToolCallView label is `ToolCallView.accessibilityLabel(title:status:)`; for a ToolCallEntry the kit uses `title ?? ""` and `status ?? .pending` (ToolCallSource).
    - StateBanner(session:) shows `StateBanner.message(for: agentState).title` under `StateBanner.bannerIdentifier`.
    - Plan: add the background-run frames as a public scripted sequence in ScriptedSession (AgentViewKitTestSupport). The new hosted test sends each frame through the scripted agent and checks the view against SessionModel after each frame. No kit source change.
  timestamp: 2026-10-06T21:36:43.256490+00:00
- actor: claude-code
  id: 01m49jwze5186dkwyf0z783776
  text: |-
    Implementation done. No change in Sources/AgentViewKit.
    - New `BackgroundRunScript` in Sources/AgentViewKitTestSupport: the steps `running`, two streamed chunks of one message, five `tool_call_update` values for two tool calls (Build: pending, in_progress, completed; Test: pending, completed), one full chunk with a new `messageId`, `idle`. Each step holds a typed `SessionUpdate` and the change that the model must report after it.
    - New `ScriptedSession.send(update:)`: encodes a typed `SessionUpdate` with JSONEncoder and sends it through the scripted agent. The script does not write JSON by hand.
    - New `Tests/AgentViewKitTests/Thread/BackgroundRunsHostedTests.swift` with three tests: (1) after each step the view shows the model (row order, assistant rows, tool row label from title and status, banner from agentState) and the running banner shows until idle; (2) after the script there are two agent message rows in model order with the two tool rows between them; (3) a source scan: no kit source declares `currentTurn*`, `lastText*`, `isWaiting*`, `waitingFor*` or `backgroundWork*`.
    - TDD: RED was the compile failure (no `BackgroundRunScript`, no `send(update:)`). After the helper, the tests passed with no kit change, as the card requires: the client model makes a new AgentMessageEntry for the new `messageId`, and StateBanner(session:) already reads agentState.
    - ToolCallEntry has no `toolCallId` property at be7e615. The test finds a tool call entry by its title, so the script gives each tool call a distinct title.
    - Gates: `swift test`: 1331 tests in 124 suites pass. Only warning: mlx-swift `missing creator for mutated node`. README and demo did not change.
  timestamp: 2026-10-06T21:46:16.389279+00:00
- actor: claude-code
  id: 01m49jx2nk2hc3mg0vmtzdqxfv
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKitTestSupport/BackgroundRunScript.swift (new), Sources/AgentViewKitTestSupport/ScriptedSession.swift (send(update:), import Foundation), Tests/AgentViewKitTests/Thread/BackgroundRunsHostedTests.swift (new); `swift test --filter BackgroundRunsHostedTests` (RED: compile failure; GREEN: 3 pass); `swift test` (1331 tests in 124 suites pass, only the mlx-swift warning)
    - next: /review
  timestamp: 2026-10-06T21:46:19.699333+00:00
depends_on:
- 01M443QAWWDY730CX0EDPG4T4Z
- 01M443NW9A12NWXYHJFYTTTA85
- 01M48MQDWDPN98ZSWQ4N7S44FW
position_column: doing
position_ordinal: '80'
title: 'Show background runs as SessionModel reports them: two agent message rows, tool rows that update, running until idle'
---
## What
After the streamed answer ends, the agent keeps the prompt `running` until all background runs end. In this time the client can get more `tool_call_update` messages and a full `agent_message_chunk` with a new `messageId`. Then `idle` comes. Source: update.md §9.3.

Owner rule (2026-10-06): the views bind directly to the observable model of FoundationModelsACPClient, and the kit does no turn tracking ("i don't really want you to worry about turns"). Thus this task adds no kit logic for the order. The old step "show Waiting for background work when no text streamed for the current turn after the last agent message" is removed: it needs kit turn tracking (the current turn, the time of the last text) that the model does not hold. The kit shows only what `SessionModel` reports: the entries of `transcript` in their order, and `agentState`.

- [x] Add a scripted sequence to `ScriptedWireAgent` (or the test helper) for this order: `running`, streamed text, tool updates, a full chunk with a new `messageId`, `idle`.
- [x] Do not add kit code for this order. The transcript view shows the entries of `SessionModel.transcript`; the state banner shows `agentState` (`.running` until `.idle`), as the state banner task binds it.

## Acceptance Criteria
- [x] The thread shows two agent message rows, in transcript order (two `AgentMessageEntry` objects in the model), and the tool rows between them show each `tool_call_update` of the model.
- [x] The running state shows while the model reports `agentState` `.running`, also after the first message ends, and goes away when the model reports `.idle`.
- [x] No source in `Sources/AgentViewKit/` keeps a "current turn", a "last text time" or a "waiting" state of its own.

## Tests
- [x] `Tests/AgentViewKitTests/Thread/BackgroundRunsHostedTests.swift`: the order above through the scripted agent; assert the two agent message rows and their order against `SessionModel.transcript`, the tool row status after each update, and the running banner until `idle`.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.