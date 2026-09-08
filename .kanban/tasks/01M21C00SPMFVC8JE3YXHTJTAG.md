---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: todo
position_ordinal: c780
title: 'Research R14: subagent data source survey, recorded as the SubagentSource decision (plan §14)'
---
## What
Settle research R14 from plan.md §14 and record it where the code can check it.

- Survey the three candidates: Router `SessionEvent` (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/SessionEvent.swift`, look for a child-session or fork event), ACP `_meta` on `tool_call_update` (what `../FoundationModelsACPAgent` emits for a subagent tool), and AG-UI `SUBAGENT_*` events as a reference shape.
- Write `Docs/decisions/subagent-source.md` with a table `candidate | carries parent id | carries state | carries child thread id | available today` and the v1 decision, including the field mapping onto `SubagentRun`.
- Encode the decision: `Sources/AgentViewKit/Subagents/SubagentSource.swift` with `enum SubagentSource { case router, acpMeta, agUI }` and `static let v1: SubagentSource`, and a fixture file under `Tests/Fixtures/subagent/` recorded from the chosen source.

## Acceptance Criteria
- [ ] `Docs/decisions/subagent-source.md` exists with the table and the decision.
- [ ] `SubagentSource.v1` matches the `decision:` line in the file (a test parses it).
- [ ] The fixture file exists and decodes.

## Tests
- [ ] `Tests/AgentViewKitTests/Subagents/SubagentSourceTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.