---
comments:
- actor: claude-code
  id: 01m2n94sc8ckrxvq3394a065nz
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 6 source files, 3 test files, Docs/decisions/usage-model.md. Decision: `PlanID` is not defined in plan.md, so this task adds it in Plan.swift as a String `RawRepresentable` struct. A shared `WireValueEnum` protocol gives `init(wireValue:)` to the three enums. `ThreadState` and `ContextUsage.Quota` have no `unknown` case, because the kit makes them from typed values, not from wire strings.
    - test: green — swift test, 185 passed (15 + 167 + 1 + 1 + 1)
    - commit: 37b6de7
    - review: findings — Tests/AgentViewKitTests/Model/ContextUsageTests.swift:131
  timestamp: 2026-09-16T14:15:16.104911+00:00
depends_on:
- 01M21BCD7C9V8N4SED5GE34A4E
position_column: doing
position_ordinal: '8180'
title: 'Thread-level types: ThreadState, Plan, SlashCommand, ThreadInfo, ContextUsage with the R16 usage merge (plan §3.2, §14)'
---
## What
Create the thread-level value types in `Sources/AgentViewKit/Model/`, per plan.md §3.2. `TerminalRecord`, `ConfigOption`, the pending request types, and `AgentThreadActions` come in their own tasks.

- `ThreadState.swift`: `idle(StopReason?)`, `running`, `requiresAction`. `StopReason`: `endTurn, maxTokens, maxTurnRequests, refusal, cancelled, unknown(String)`.
- `Plan.swift`: `Plan { id: PlanID; entries: [PlanEntry] }`, `PlanEntry { content, priority (high, medium, low, unknown(String)), status (pending, inProgress, completed, cancelled, unknown(String)) }`.
- `SlashCommand.swift`: `name`, `description`, `inputHint`.
- `ThreadInfo.swift`: `title`, `updatedAt`.
- `ContextUsage.swift`: `used`, `size`, `cost (amount, currency)?`, `input (total, cached)?`, `output (total, reasoning)?`, `quota (belowLimit(approaching), limitReached)?`. Computed `fraction`.
- Research R16 (plan.md §14): merge FoundationModels `Usage` (macOS 27 `LanguageModelSession.usage` and `ResponseStream.Snapshot.usage`), the Private Cloud Compute quota state, and ACP `usage_update` into `ContextUsage`. Write `Docs/decisions/usage-model.md` with a table `source field | ContextUsage field | note`. Every row names a field that exists on `ContextUsage`.
- Enums with an `unknown(String)` case: `StopReason`, `PlanEntry.Priority`, `PlanEntry.Status`.

## Acceptance Criteria
- [x] `StopReason(wireValue: "max_tokens")` gives `.maxTokens`; `"x"` gives `.unknown("x")`. The same test shape for `PlanEntry.Priority` and `PlanEntry.Status`.
- [x] `ContextUsage.fraction` is `used / size` and clamps to `0...1`; `size == 0` gives `0`.
- [x] `Docs/decisions/usage-model.md` exists, and every `ContextUsage field` in its table is a stored property name on `ContextUsage` (a test parses the table and compares with `Mirror`).

## Tests
- [x] `Tests/AgentViewKitTests/Model/ThreadStateTests.swift`: stop reason mapping.
- [x] `Tests/AgentViewKitTests/Model/PlanTests.swift`: priority and status mapping.
- [x] `Tests/AgentViewKitTests/Model/ContextUsageTests.swift`: fraction, clamp, zero size, and the decision-table match.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #foundation #model

## Review Findings (2026-09-16 09:12)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 9 file(s) reviewed, 3 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `Docs/decisions/usage-model.md` — no validator matches this file

- [x] `Tests/AgentViewKitTests/Model/ContextUsageTests.swift:131` `reuse/reuse` — The text(of:) method reimplements identical file-reading logic that already exists elsewhere. Per the clone-siblings probe, Tests/AgentViewKitTests/Subagents/SubagentSourceTests.swift::SubagentFixtureFiles::text has 1.00 similarity, and PackageStructureTests/PackageRoot.swift::PackageRoot::text has 0.99 similarity. Rather than duplicating this file-reading pattern across multiple test files, the functionality should be extracted to a shared test utility. Extract the file-reading logic `String(contentsOf:root.appending(path:), encoding:.utf8)` to a shared test helper module (or extend an existing test utility) and import it into ContextUsageTests and other test files rather than reimplementing it here.
