---
assignees:
- claude-code
depends_on:
- 01M48MS20B5GS4711S119KD9GM
position_column: todo
position_ordinal: af80
title: 'Bind the VoiceOver announcements and the activity indicator to SessionModel: agentState, tool call status, pending requests'
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. At present `ThreadAnnouncementObserver` (`Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift`) observes only an `AgentThread`: `turnAnnouncement(old:new:)` reads the kit `ThreadState`, `toolCallProgress(in:)` reads `ThreadItem` records, and `pendingRequests(of:)` reads the kit pending lists. `ActivityIndicator` (`Sources/AgentViewKit/Activity/ActivityIndicator.swift`) takes an `AgentThread`. A thread view over a `SessionModel` thus makes no announcement and has no activity indicator.

- [ ] `ThreadAccessibility`: the announcement of a stop reads the change of `SessionModel.agentState` from `.running` or `.requiresAction` to `.idle`, with the stop reason of the model. The kit keeps no turn state of its own: the observer compares only the old and the new value that `onChange` gives.
- [ ] The tool result announcement reads `ToolCallEntry.status` and `title` of the tool call entries of `SessionModel.transcript`. The action-required announcement reads `SessionModel.pendingPermissions`, `SessionModel.pendingElicitations` and `ConnectionModel.pendingElicitations`.
- [ ] `ActivityIndicator` gets an initializer that takes a `SessionModel`. It reads `agentState` and the last `ToolCallEntry` with the status `.inProgress`. It keeps no copy.
- [ ] `Sources/AgentViewKit/Thread/AgentThreadView.swift`: the session path adds the observer.

## Acceptance Criteria
- [ ] When the model changes `agentState` from `.running` to `.idle(end_turn)`, the announcer gets "Response complete" one time.
- [ ] When the model changes a tool call entry status to `.completed`, the announcer gets the title and the status.
- [ ] When the model adds a pending permission, the announcer gets "Action required: <title>" with high priority.
- [ ] A history replay (`isReplaying`) of finished tool calls makes no tool result announcement.
- [ ] The activity indicator shows the title of the running tool call of the model, and goes away at `.idle`.

## Tests
- [ ] `Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift`: one test for each announcement criterion with a `SessionModel`, the scripted agent and `RecordingAnnouncer`.
- [ ] `Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityTests.swift`: the pure functions over `StateUpdate?` and the tool call entries.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.