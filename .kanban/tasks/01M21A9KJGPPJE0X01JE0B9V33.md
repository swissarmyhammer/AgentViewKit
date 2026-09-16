---
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
- [ ] `StopReason(wireValue: "max_tokens")` gives `.maxTokens`; `"x"` gives `.unknown("x")`. The same test shape for `PlanEntry.Priority` and `PlanEntry.Status`.
- [ ] `ContextUsage.fraction` is `used / size` and clamps to `0...1`; `size == 0` gives `0`.
- [ ] `Docs/decisions/usage-model.md` exists, and every `ContextUsage field` in its table is a stored property name on `ContextUsage` (a test parses the table and compares with `Mirror`).

## Tests
- [ ] `Tests/AgentViewKitTests/Model/ThreadStateTests.swift`: stop reason mapping.
- [ ] `Tests/AgentViewKitTests/Model/PlanTests.swift`: priority and status mapping.
- [ ] `Tests/AgentViewKitTests/Model/ContextUsageTests.swift`: fraction, clamp, zero size, and the decision-table match.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #foundation #model