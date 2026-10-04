---
assignees:
- claude-code
position_column: todo
position_ordinal: a680
title: Check update.md sections 4.2 and 4.3 against the real client model API
---
## What
The names in update.md §4.2 and §4.3 come from the design. The built client models (FoundationModelsACPClient `a65af8a`, `Sources/FoundationModelsACPClient/Model/`) use some other names. Correct the plan before the pin move, so that each later task uses the real names. Source: update.md §4.1, §11 step 6. This task can run now; it does not change code.

- [ ] Compare §4.2 and §4.3 with the public API of `ConnectionModel`, `SessionModel` and `TranscriptEntry`. Known differences: the open set is `openSessions`; the connect call is `connect(over:logger:bufferLimits:client:)`; the model also has `CompactionEntry`, `ErrorEntry`, `SessionNotice`, `dismissNotice(_:)`, `updateTap()`, `appendError(code:message:data:)`, `ToolCallEntry.linkedElicitationIDs`, and the capability flags `canListSessions`, `canResumeSessions`, `canCloseSessions`, `canDeleteSessions`, `canLogout`.
- [ ] Correct update.md §4.2, §4.3 and the stale "not built yet" status in the decisions table.
- [ ] Add `Tests/PackageStructureTests/UpdatePlanNamesTests.swift`: it reads `update.md` and fails if it finds the design names that do not exist (for example `sessions` used as the open set). Delete this test with `update.md` in the documents task.

## Acceptance Criteria
- [ ] Each API name in update.md §4.2 and §4.3 exists in the client model source at `a65af8a`.

## Tests
- [ ] `UpdatePlanNamesTests` passes.
- [ ] `swift test --filter PackageStructureTests` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.