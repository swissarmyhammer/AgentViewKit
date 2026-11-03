---
assignees:
- claude-code
depends_on:
- 01M6GR1RR24763YSQ7QRYZEW6G
position_column: todo
position_ordinal: '8480'
title: Accessibility and acceptance tests for nested sessions
---
## What
Check the whole feature with accessibility tests and end-to-end acceptance tests. Part (d) of the split of card 01M6GJ1SEKFK6V5QFY3VST23R5. Fix any gap that the tests find in cards (a), (b) and (c).
- Accessibility: the header is one element, its label names the path, and each dropdown is reachable with VoiceOver. Each command has an accessibility name. Marks and the banner button have labels. Update `Docs/decisions/accessibility.md` for the new header.
- Acceptance: run the nested demo agent and the nested recording through the model and the views, and check each shared criterion below.

## Acceptance Criteria
- [ ] VoiceOver reads the path of a chain of three sessions, and each dropdown is reachable.
- [ ] Each shared criterion below has one test that names it.
- [ ] The decision record of accessibility is updated.
- [ ] All shared criteria below hold.

## Tests
- [ ] `Tests/AgentViewKitTests/Accessibility`: label and value of the header for a chain of three sessions; the dropdowns; the command names; the banner button.
- [ ] `Tests/AgentViewKitTests/Sessions`: resume to root, unconfirmed child, replay is history, removal on the final tool call, child with no link stays, failed restore, row jump.
- [ ] Run `swift test --filter "Sessions|Commands|Status|Accessibility"`. All pass. Keep the test rules in the memory of the project: no flaky test, no hang, no window, no focus taken.
- [ ] Update the PNG snapshots, and give the paths to the user.

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