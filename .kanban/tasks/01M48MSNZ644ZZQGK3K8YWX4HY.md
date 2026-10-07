---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4a16ma8s3kj4n5t6ef09s9m
  text: |-
    Research (picked up, moved to doing):
    - Client model at be7e615: `SessionModel.agentState: StateUpdate?` (Hashable), `transcript: [TranscriptEntry]`, `pendingPermissions`, `pendingElicitations`, `isReplaying` (true while a `session/resume` request runs). `ConnectionModel.pendingElicitations`. `ToolCallEntry.id: TranscriptEntry.ID`, `title: String?`, `status: ToolCallStatus?` (ACP). No public toolCallId (client task x6p3vh0); the row key `entry.id.rowKey` is the identity to use.
    - `ToolCallSource` already unifies a kit record and a `ToolCallEntry` (id as String, title, ACP status). Plan: `ThreadAccessibility.ToolCallProgress` takes the ACP status, and both the old item list and the new transcript map through `ToolCallSource`, so one diff function serves both paths. The kit status `.lost` gives ACP `unknown("_lost")`; that value still counts as a result.
    - `AgentCommandTarget.isActive(_:)` already tells `.running` / `.requiresAction`; the turn announcement reuses it.
    - `StateBanner.message(for: StateUpdate)` gives the banner titles; the turn announcement of a stop reason with a banner uses that title (also the `_` extension reasons through `message(forUnknownStopReason:)`).
    - `PendingRequestsHost` filters the elicitations with `ElicitationCard.hasCard(for:)`; the action-required list uses the same filter so it names only requests that show a card.
    - Old thread path: `ThreadAnnouncementObserver(thread:)`, `turnAnnouncement(old: ThreadState, new: ThreadState)`, `toolCallProgress(in: [ThreadItem])`, `pendingRequests(of: AgentThread)` and `ActivityState(thread:)` stay for the deprecated `AgentThreadView(thread:actions:)` until ^h1116ab / ^443rkgv remove that path.
    - Test plan: hosted tests in ThreadAccessibilityHostedTests over ScriptedSession (turn end, tool status completed, pending permission, replay silent); pure tests in ThreadAccessibilityTests over `StateUpdate?` and transcript tool call entries; ActivityIndicator(session:) hosted test beside the other indicator tests.
  timestamp: 2026-10-07T01:56:12.744179+00:00
- actor: claude-code
  id: 01m4a21vs8v8y02tjjjvqstxvh
  text: |-
    Implementation landed (TDD: the new tests failed first on the missing API; the replay test failed with the replay guard removed, and passes with it).

    What changed:
    - `ThreadAccessibility.swift`: new `turnAnnouncement(old: StateUpdate?, new: StateUpdate?)` (uses `AgentCommandTarget.isActive`, the `StateBanner` title for each other stop reason), new `toolCallProgress(in: [TranscriptEntry])`, new `pendingRequests(of: SessionModel, connection: ConnectionModel?)` (same `ElicitationCard.hasCard` filter as the cards), new `SessionAnnouncementObserver` (session + optional connection; tool results are silent while `isReplaying`). `ToolCallProgress.status` is now the ACP `ToolCallStatus` and both paths map through `ToolCallSource`, so one diff function serves both. The kit status `_lost` still counts as a result. One private `announcing(changesOf:to:priority:texts:)` modifier serves both observers.
    - `ActivityIndicator.swift`: `ActivityState(session:)` and `ActivityIndicator(session:)`; the body reads the model at each evaluation (no stored state).
    - `TranscriptEntryKind.swift`: `TranscriptEntry.toolCall` accessor, shared by the two new readers.
    - `AgentThreadView.swift`: the session path adds `SessionAnnouncementObserver(session:connection:)` in the background; doc updated.
    - Tests: new hosted tests (turn end once, tool completed, pending permission high priority, login elicitation of the connection, replay silent), new pure tests (StateUpdate? turn texts, transcript progress, session+connection request order), `ActivityIndicator(session:)` hosted test. Shared helpers moved to `Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift` (`resumeMethod`, `replayFromStartRequest`, `endTurnState`, login elicitation helpers, `sendToolCallUpdate`); `SessionStateBannersHostedTests` and `PendingRequestsSessionModelHostedTests` now use them instead of their own copies.

    Discoveries / notes for the next agent:
    - `import FoundationModelsACP` in `ThreadAccessibility.swift` breaks the `ViewModifier`s of that file: the ACP module has a public `Content` struct that hides `ViewModifier.Content`. The file uses scoped imports (`import enum FoundationModelsACP.StateUpdate`, `import enum FoundationModelsACP.ToolCallStatus`) for this reason.
    - An `agent_message_chunk` with no `messageId` gives no transcript entry in the scripted session; the test sends a `messageId`.
    - Old thread path kept on purpose (only for the deprecated `AgentThreadView(thread:actions:)`): `ThreadAnnouncementObserver`, `turnAnnouncement(old: ThreadState, new: ThreadState)`, `toolCallProgress(in: [ThreadItem])`, `pendingRequests(of: AgentThread)`, `ActivityState(thread:)`. ^h1116ab / ^gzj5cye remove them.
    - Not in scope of this card, noted only: the turn announcement is not muted while `isReplaying`. If a replay sends `running` then `idle`, VoiceOver says "Response complete". The card asks the replay guard only for tool results.
    - `swift test`: 1395 tests in 127 suites and 78 tests in 12 suites pass; only the expected mlx-swift `missing creator for mutated node` warning. No README, snippet or demo change, so `check-readme.sh` and `test-examples.sh` do not apply.
  timestamp: 2026-10-07T02:11:05.128746+00:00
- actor: claude-code
  id: 01m4a220bnn96yv06kzqqhfycf
  text: |-
    ### implement — changed
    - evidence: 10 files — Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift, Sources/AgentViewKit/Activity/ActivityIndicator.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/TranscriptEntryKind.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityTests.swift, Tests/AgentViewKitTests/Activity/ReasoningViewHostedTests.swift, Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift, Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift; `swift test` green (1395 tests in 127 suites, 78 tests in 12 suites), only the expected mlx-swift warning
    - next: /review
  timestamp: 2026-10-07T02:11:09.813975+00:00
- actor: claude-code
  id: 01m4a2bfze0jdebg7m98b718zw
  text: |-
    Coordinator change done: the stop announcement of `SessionAnnouncementObserver` is now silent while `SessionModel.isReplaying` is true (the same guard as the tool result announcement). TDD: the new hosted test `aReplayOfARunThatEndsMakesNoStopAnnouncement` (replay sends `running`, then `idle` `end_turn`) failed first ("Expectation failed: announcer.announcements.isEmpty"), then passed with the guard. The two replay tests now share `beginReplay(of:pumping:)` and `endReplay(_:of:pumping:)` helpers. The note in the earlier comment ("the turn announcement is not muted while isReplaying") no longer applies.

    ### implement — changed
    - evidence: Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift; `swift test --filter ThreadAccessibilityHostedTests` 18 tests pass; `swift test` green (1396 tests in 127 suites, 78 tests in 12 suites), only the expected mlx-swift warning
    - next: /review
  timestamp: 2026-10-07T02:16:20.718434+00:00
depends_on:
- 01M48MS20B5GS4711S119KD9GM
position_column: doing
position_ordinal: '80'
title: 'Bind the VoiceOver announcements and the activity indicator to SessionModel: agentState, tool call status, pending requests'
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. At present `ThreadAnnouncementObserver` (`Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift`) observes only an `AgentThread`: `turnAnnouncement(old:new:)` reads the kit `ThreadState`, `toolCallProgress(in:)` reads `ThreadItem` records, and `pendingRequests(of:)` reads the kit pending lists. `ActivityIndicator` (`Sources/AgentViewKit/Activity/ActivityIndicator.swift`) takes an `AgentThread`. A thread view over a `SessionModel` thus makes no announcement and has no activity indicator.

- [x] `ThreadAccessibility`: the announcement of a stop reads the change of `SessionModel.agentState` from `.running` or `.requiresAction` to `.idle`, with the stop reason of the model. The kit keeps no turn state of its own: the observer compares only the old and the new value that `onChange` gives.
- [x] The tool result announcement reads `ToolCallEntry.status` and `title` of the tool call entries of `SessionModel.transcript`. The action-required announcement reads `SessionModel.pendingPermissions`, `SessionModel.pendingElicitations` and `ConnectionModel.pendingElicitations`.
- [x] `ActivityIndicator` gets an initializer that takes a `SessionModel`. It reads `agentState` and the last `ToolCallEntry` with the status `.inProgress`. It keeps no copy.
- [x] `Sources/AgentViewKit/Thread/AgentThreadView.swift`: the session path adds the observer.
- [x] (Coordinator, 2026-10-07) The stop announcement is silent while `SessionModel.isReplaying` is true, the same as the tool result announcement.

## Acceptance Criteria
- [x] When the model changes `agentState` from `.running` to `.idle(end_turn)`, the announcer gets "Response complete" one time.
- [x] When the model changes a tool call entry status to `.completed`, the announcer gets the title and the status.
- [x] When the model adds a pending permission, the announcer gets "Action required: <title>" with high priority.
- [x] A history replay (`isReplaying`) of finished tool calls makes no tool result announcement.
- [x] A history replay (`isReplaying`) that sends `running` and then `idle` makes no stop announcement.
- [x] The activity indicator shows the title of the running tool call of the model, and goes away at `.idle`.

## Tests
- [x] `Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift`: one test for each announcement criterion with a `SessionModel`, the scripted agent and `RecordingAnnouncer`.
- [x] `Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityTests.swift`: the pure functions over `StateUpdate?` and the tool call entries.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.