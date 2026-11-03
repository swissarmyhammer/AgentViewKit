---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: 'Nested session fixtures: ScriptedSession helpers, nested demo agent, nested recording'
---
## What
Make test and demo fixtures that hold a parent session with child sessions. Part (a) of the split of card 01M6GJ1SEKFK6V5QFY3VST23R5. The fixtures are flat today.
- `ScriptedSession` (`Sources/AgentViewKitTestSupport/ScriptedSession.swift`): helpers for the child announcement, child events with the child id, child `state_update`, a child permission request, and the final `tool_call_update` of the linked `agents` call. The helpers carry the link `_meta.sah.agentRun` on both messages. A helper can leave the link out (a child with no link).
- `DemoAgent` / `ScriptedWireAgent` (`Sources/AgentViewKitDemoSupport/`): a nested demo agent with a root, a child, and a grandchild, for the gallery and the UI tests.
- `RecordedSessionsScenario`: a nested recording whose Router record has `agentSpawn`, to test resume with replay. It covers: a replay phase, a first current snapshot after the resume response, and a child that fails to restore.

## Acceptance Criteria
- [ ] The three fixtures exist and are used by a test of the model.
- [ ] A fixture can send the final tool call update after the last update of the child.
- [ ] A fixture can make a child with no link, a child that needs the user, and a child that fails to restore.
- [ ] The recording gives a replay phase, then a current snapshot.
- [ ] All shared criteria below hold for the whole feature. This card gives the data for them.

## Tests
- [ ] `Tests/AgentViewKitTests/Sessions`: the fixtures build the expected tree (a chain of three sessions) through the client model.
- [ ] Run `swift test --filter "Sessions"`. All pass.

## Workflow
- Use `/tdd`: write failing tests first, then implement.

## Shared criteria of the whole feature
These criteria apply to all four cards of the split. Each card holds the full list. The decision record is `Docs/decisions/sub-agent-sessions.md`.
- The model is plain parent and child sessions, all the way down. Do not write a rule for a number of levels. A test chain of three sessions is only a test size.
- Use the names `SessionModel.parent`, `children`, `ancestors`, `siblings`, `descendants`, `workState`, `needsAttention`, and `SessionPathEntry`. Do not use a name that starts with `Subagent` (`RemovedVocabularyTests`).
- Which session a window shows is VIEW state, not model state. Two windows can show different sessions of one connection.
- After a resume, the view shows the ROOT. A child that needs the user shows through `needsAttention` on its ancestors and through a jump button in the banner.
- A child is unconfirmed until its first current snapshot after the resume response. It shows as unknown, and its controls are disabled.
- Everything inside the replay phase is history: no attention marks and no notifications.
- A finished child is removed when its linked tool call has a final status. The link is `_meta.sah.agentRun` (wire card `01M6GP1QC785QS2BS3TNVMKT7A`). A child with no link stays until its parent closes.
- The `agents` tool row in the parent thread jumps to the child while the child exists. After the removal, the row stays as history and shows the result.
- A child that failed to restore shows as unknown, with a reason.
- The middle crumbs collapse when the path does not fit the width of the bar. This is a width rule, not a depth rule.
- If the shown session is removed, the view falls back to its parent.
- The breadcrumb shows the full path of a chain of three sessions. Each dropdown lists the siblings of its level with state and request count (`PendingRequestCountBadge`).
- A question from a grandchild marks the crumbs of its ancestors. The answer clears the mark.
- Go to parent, open child, next sibling, previous sibling, and jump work with the keyboard and from the menus. Jump lists all descendants with their paths, such as "Agent > Reviewer > Linter", and opens the chosen one.
- The banner of the shown session tells of a waiting descendant, and its button jumps to it.
- VoiceOver reads the path, and each dropdown is reachable.

## Public API break
`AgentThreadView.init(session:connection:sessionTitle:headerContextMenuPath:composer:)` changes, because the header reads the `SessionModel`. The parameter `sessionTitle` is removed. These also change: `AgentInfoHeader.init(connection:sessionTitle:)`, `AgentInfoHeader.label(agent:sessionTitle:)`, `DefaultThreadComposer` (forwards the new form), and the doc comments that name the old form. Change all callers at once. Keep no shim. (This card does not make the break. Card (b) does.)

## Dependencies outside this board
Start after FoundationModelsACPClient card `01M6GH6FH41C6VSFC3QRT8H1FS` (the model fields) and wire card `01M6GP1QC785QS2BS3TNVMKT7A` are done. A dependency across boards cannot be set. Start no card without the word of the user. #subagents