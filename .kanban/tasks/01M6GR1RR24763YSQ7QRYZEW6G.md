---
assignees:
- claude-code
depends_on:
- 01M6GR1APG5GDGEJHC4KKY18P6
position_column: done
position_ordinal: ffffff9180
title: 'EditorKit commands and jump over descendants: parent, child, siblings, quick-open'
---
## What
Add keyboard commands and a jump list for sessions. Part (c) of the split of card 01M6GJ1SEKFK6V5QFY3VST23R5. Follow `Sources/AgentViewKit/Lists/AgentRowListCommands.swift` and `Sources/AgentViewKit/Commands/` (EditorCommands scopes, `nav.*`, `FocusPath`, `AgentKeymap`).
- The breadcrumb gets its own command scope, so the crumbs take keyboard focus.
- Commands: go to parent, open child, next sibling, previous sibling, and jump. They change the VIEW state of the shown session. They do not write model state.
- Jump is a quick-open list over `descendants` (and the ancestors), filtered by name. Each entry shows its path, such as "Agent > Reviewer > Linter". A child that is unknown shows its state.
- Add the commands to `AgentCommands`, `AgentKeymap`, and the command placement (menus). Give each command an accessibility name.
- A jump to a session that was removed does nothing and keeps the shown session.

## Acceptance Criteria
- [ ] Go to parent, open child, next sibling, and previous sibling work with the keyboard and from the menus.
- [ ] Jump lists all descendants with their paths and opens the chosen one. The filter works by name.
- [ ] The crumbs take focus through the new scope.
- [ ] Each command has an accessibility name.
- [ ] All shared criteria below hold.

## Tests
- [ ] `Tests/AgentViewKitTests/Commands`: the five commands, the scope focus, the jump list and the filter, with the nested demo agent.
- [ ] Run `swift test --filter "Commands"`. All pass. Keep the test rules in the memory of the project: no flaky test, no hang, no window, no focus taken.

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
`AgentThreadView.init(session:connection:sessionTitle:headerContextMenuPath:composer:)` changes, because the header reads the `SessionModel`. The parameter `sessionTitle` is removed. These also change: `AgentInfoHeader.init(connection:sessionTitle:)`, `AgentInfoHeader.label(agent:sessionTitle:)`, `DefaultThreadComposer` (forwards the new form), and the doc comments that name the old form. Change all callers at once. Keep no shim. (Card (b) makes the break.)

## Dependencies outside this board
Start after FoundationModelsACPClient card `01M6GH6FH41C6VSFC3QRT8H1FS` (the model fields) and wire card `01M6GP1QC785QS2BS3TNVMKT7A` are done. A dependency across boards cannot be set. Start no card without the word of the user. #subagents