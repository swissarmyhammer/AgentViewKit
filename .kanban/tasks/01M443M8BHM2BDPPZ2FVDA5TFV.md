---
assignees:
- claude-code
depends_on:
- 01M443M1YMTRRXEZYGFAJ4J75B
position_column: todo
position_ordinal: '9080'
title: Remove the Router and FoundationModels parts of ContextUsage and ThreadError.Kind
---
## What
Only the Router and FoundationModels sources made these values (update.md §6). ACP gives usage through `usage_update` (`used`, `size`, cost) and errors through JSON-RPC codes.

- [ ] In `Sources/AgentViewKit/Model/ContextUsage.swift`: remove `init(used:fill:)` and the `Input`, `Output` and `Quota` parts. Keep the fields that ACP `usage_update` fills.
- [ ] In `Sources/AgentViewKit/Model/ThreadError.swift`: remove the `ThreadError.Kind` cases `contextSizeExceeded`, `rateLimited`, `guardrailViolation` and `timeout`. Remove their blocks and actions from `Items/ErrorView.swift` and `Items/ErrorActions.swift`.
- [ ] Change `Status/ContextUsageView.swift` for the smaller `ContextUsage`.
- [ ] Delete or change `Tests/AgentViewKitTests/Model/ContextUsageTests.swift`, `ErrorViewHostedTests` and the `ContextUsageView` tests.

## Acceptance Criteria
- [ ] `ContextUsage` has only the fields that ACP fills. `ThreadError.Kind` has no case that only FoundationModels made.
- [ ] `swift test` passes.

## Tests
- [ ] Change `ContextUsageTests`: one test for the values from a `usage_update`.
- [ ] Add `contextSizeExceeded`, `guardrailViolation` and `init(used:fill:)` to `RemovedVocabularyTests`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.