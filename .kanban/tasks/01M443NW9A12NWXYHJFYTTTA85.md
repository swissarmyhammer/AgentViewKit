---
assignees:
- claude-code
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
position_column: todo
position_ordinal: '9480'
title: 'Bind the tool call and diff views to ToolCallEntry: name for the registry, title as label, structured diffs, linked elicitation'
---
## What
Source: update.md §4.7 ("Tool call view"), §5 (`ToolCallUpdate.name`), §9.4 (structured diffs).

- [ ] Bind `ToolCallView` (`Sources/AgentViewKit/Items/ToolCallView.swift`) to `ToolCallEntry`. Use the ACP tool kind and status types; remove the use of the kit `ToolKind` and `ToolCallStatus` in this view. `ToolKindSymbol.swift` maps the ACP kind.
- [ ] Select the tool view in the registry (`Thread/Registries.swift`) by `name` (the program name of the tool). Show `title` as the label. With no `name`, use the default view.
- [ ] Show `Diff.changes` (structured diff content) in `DiffView` (`Sources/AgentViewKit/Diff/DiffView.swift`) when there is no `git_patch`. Today these show as unknown.
- [ ] Show the session elicitations linked to a tool call in its row. Read them with `ToolCallEntry.linkedElicitationIDs` and look each one up in `SessionModel.pendingElicitations`.

## Acceptance Criteria
- [ ] A tool call with `name` "read_file" uses the view registered for "read_file", and shows `title` as its label.
- [ ] A tool call with a structured diff shows the diff, not the unknown view.
- [ ] A pending elicitation whose ID is in `linkedElicitationIDs` of a tool call shows in that row.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift`: registry selection by `name`; label from `title`; structured diff; linked elicitation. Feed the session with the test helper of the transcript task.
- [ ] `RegistryResolutionTests` covers the `name` key.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.