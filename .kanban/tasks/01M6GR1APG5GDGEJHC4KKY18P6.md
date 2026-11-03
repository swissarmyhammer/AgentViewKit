---
assignees:
- claude-code
depends_on:
- 01M6GR0P93GSSX2D63SJ6RGWZ3
position_column: todo
position_ordinal: '8280'
title: 'Breadcrumb in AgentInfoHeader: sibling dropdowns, needsAttention marks, banner jump'
---
## What
Show the path of the shown session as a breadcrumb. Part (b) of the split of card 01M6GJ1SEKFK6V5QFY3VST23R5. Extend `Sources/AgentViewKit/Connections/AgentInfoHeader.swift`. Today it shows "Agent > Session" and the host gives `sessionTitle` as text. The header floats on glass in the top bar of `AgentThreadView` (`.safeAreaBar(edge: .top)`, `.floatingGlass()`).
- Replace `sessionTitle: String?` with the `SessionModel` that the thread shows. The crumbs are the agent, then `ancestors`, then the session. The views read the model fields and keep no copy.
- Each crumb has a dropdown (a menu) with the siblings of its level, like the path bar of GitHub. Each choice shows `title`, `workState`, and the pending request count (`PendingRequestCountBadge`).
- A crumb shows a state mark when `needsAttention` is true. A question from a grandchild shows on its ancestors.
- When the path does not fit the width, the middle crumbs collapse to "..." with a dropdown. The agent segment keeps the higher layout priority. This is a width rule, not a depth rule.
- Which session a window shows is VIEW state (in the host or in `AgentThreadView`). After a resume the view shows the ROOT.
- If the shown session is removed, the view falls back to its parent.
- A child that is not yet confirmed shows as unknown and its controls are disabled. A child that failed to restore shows as unknown with a reason.
- `StateBanner` follows the shown session. When a descendant needs the user, the banner says so and has a button that jumps to it.
- The `agents` tool row in the parent thread jumps to the child while the child exists. After the removal the row stays as history and shows the result.
- Keep the accessibility rules of the header: one header element, a label that names the path, and each dropdown reachable with VoiceOver.
- Make the API break below, and change all callers (hosts, demo, previews, doc comments).

## Acceptance Criteria
- [ ] The breadcrumb shows the full path of a chain of three sessions, and collapses the middle crumbs when the path does not fit the width.
- [ ] Each dropdown lists the siblings of its level with state and request count.
- [ ] A question from a grandchild marks the crumbs of its ancestors. The answer clears the mark.
- [ ] A removed child that is shown sends the view to its parent.
- [ ] After a resume the view shows the root. A waiting child shows by mark and by the banner jump.
- [ ] Replay-phase events make no mark and no notification.
- [ ] An unconfirmed child and a child that failed to restore show as unknown (with a reason in the second case).
- [ ] The `agents` tool row jumps to the child.
- [ ] The API break below is done and no `sessionTitle` is left.
- [ ] All shared criteria below hold.

## Tests
- [ ] `Tests/AgentViewKitTests/Sessions`: path, collapse by width, dropdown content, removal fallback, resume to root, unknown states, with the nested demo agent.
- [ ] `Tests/AgentViewKitTests/Status`: marks, and the banner button.
- [ ] Run `swift test --filter "Sessions|Status"`. All pass. Keep the test rules in the memory of the project: no flaky test, no hang.
- [ ] Update the PNG snapshots of the header, and give the paths to the user.

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
`AgentThreadView.init(session:connection:sessionTitle:headerContextMenuPath:composer:)` changes, because the header reads the `SessionModel`. The parameter `sessionTitle` is removed. These also change: `AgentInfoHeader.init(connection:sessionTitle:)`, `AgentInfoHeader.label(agent:sessionTitle:)`, `DefaultThreadComposer` (forwards the new form), and the doc comments that name the old form. Change all callers at once. Keep no shim.

## Dependencies outside this board
Start after FoundationModelsACPClient card `01M6GH6FH41C6VSFC3QRT8H1FS` (the model fields) and wire card `01M6GP1QC785QS2BS3TNVMKT7A` are done. A dependency across boards cannot be set. Start no card without the word of the user. #subagents