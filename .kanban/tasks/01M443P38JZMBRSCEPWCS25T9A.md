---
assignees:
- claude-code
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
position_column: todo
position_ordinal: '9580'
title: Bind the terminal, plan, unknown and error rows to their TranscriptEntry objects
---
## What
Source: update.md §4.4 (plans, terminals, unknown updates), §4.7 ("Error rows", "Terminal view", "Plan view").

- [ ] Bind `TerminalView` (`Sources/AgentViewKit/Terminal/TerminalView.swift`) to `TerminalEntry`. Show its computed `text`. Remove the kit terminal decode.
- [ ] Bind `TaskListView` (`Sources/AgentViewKit/Status/TaskListView.swift`) to `PlanTranscriptEntry`, at its position in the transcript. A plan with a `planId` keeps its first position; a plan with no `planId` is a new row. Show `UnknownContent` items with their type.
- [ ] Bind `UnknownItemView` to `UnknownEntry`: show the type string and the raw JSON.
- [ ] Bind `ErrorView` (`Items/ErrorView.swift`) to `ErrorEntry`: show `code`, `message` and `data`. The kit keeps no error list. For a failed request that the kit sends outside the model, call `SessionModel.appendError(code:message:data:)`.

## Acceptance Criteria
- [ ] A terminal chunk appends text; an `output` snapshot replaces it.
- [ ] Two plan updates with the same `planId` show one row at the first position.
- [ ] An unknown session update shows a row with its type string.
- [ ] A failed prompt shows an error row with the JSON-RPC code.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift`: one test for each criterion, with a scripted session.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.