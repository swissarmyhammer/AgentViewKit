---
comments:
- actor: claude-code
  id: 01m2n1spv947fk4bcb12z5ctfq
  text: |-
    ### implement — changed
    - evidence: 4 new files: Docs/decisions/subagent-source.md, Sources/AgentViewKit/Subagents/SubagentSource.swift, Tests/AgentViewKitTests/Subagents/SubagentSourceTests.swift, Tests/Fixtures/subagent/router-agent-spawn.jsonl. Decision: router. The Router `session` TranscriptEvent carries agentSpawn (parentSessionId, parentToolCallId) and the child sessionId. The ACP agent sets no `_meta` on tool_call_update. AG-UI is a reference shape only.
    - next: test

    ### test — green
    - evidence: swift build: only the accepted mlx-swift warning. swift test: 22 tests pass (13 + 6 + 1 + 1 + 1). swift test --filter AgentViewKitTests: 6 tests pass, exit 0.
    - next: commit
  timestamp: 2026-09-16T12:06:53.033544+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: doing
position_ordinal: '80'
title: 'Research R14: subagent data source survey, recorded as the SubagentSource decision (plan §14)'
---
## What
Settle research R14 from plan.md §14 and record it where the code can check it.

- Survey the three candidates: Router `SessionEvent` (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/SessionEvent.swift`, look for a child-session or fork event), ACP `_meta` on `tool_call_update` (what `../FoundationModelsACPAgent` emits for a subagent tool), and AG-UI `SUBAGENT_*` events as a reference shape.
- Write `Docs/decisions/subagent-source.md` with a table `candidate | carries parent id | carries state | carries child thread id | available today` and the v1 decision, including the field mapping onto `SubagentRun`.
- Encode the decision: `Sources/AgentViewKit/Subagents/SubagentSource.swift` with `enum SubagentSource { case router, acpMeta, agUI }` and `static let v1: SubagentSource`, and a fixture file under `Tests/Fixtures/subagent/` recorded from the chosen source.

## Acceptance Criteria
- [x] `Docs/decisions/subagent-source.md` exists with the table and the decision.
- [x] `SubagentSource.v1` matches the `decision:` line in the file (a test parses it).
- [x] The fixture file exists and decodes.

## Tests
- [x] `Tests/AgentViewKitTests/Subagents/SubagentSourceTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.