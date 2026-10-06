---
assignees:
- claude-code
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
- 01M443M8BHM2BDPPZ2FVDA5TFV
position_column: todo
position_ordinal: '9e80'
title: Bind ContextUsageView to the usage of SessionModel
---
## What
Source: update.md §4.2 (last-value state `usage`), §4.5 (kit `ContextUsage` replaced by the ACP type). Owner rule (2026-10-06): the view binds directly to the observable model of FoundationModelsACPClient. It shows what the model holds. The kit keeps no copy of the usage and computes no usage value that the model does not report.

- [ ] `ContextUsageView` (`Sources/AgentViewKit/Status/ContextUsageView.swift`) takes the `SessionModel` and reads `SessionModel.usage` (`UsageUpdate?`: `used`, `size`, and `cost` when present) directly in its body. Do not keep the usage in `@State`, in a kit struct or in a kit `@Observable` object.
- [ ] Show nothing when `usage` is nil.
- [ ] Remove the kit `ContextUsage` use from this view. Do not add a kit type that copies `UsageUpdate`.

## Acceptance Criteria
- [ ] A `usage_update` that the model applies shows in the view with no other step: used of size, and the cost when the agent sends it.
- [ ] A second `usage_update` replaces the shown values: the view always shows the last value of the model.
- [ ] With `usage` nil, the view is hidden.
- [ ] No kit type keeps a copy of `UsageUpdate`.

## Tests
- [ ] `Tests/AgentViewKitTests/Status/ContextUsageSessionModelHostedTests.swift`: the scripted agent sends a `usage_update`, and the test asserts the shown text; a second update changes the text; with and without cost; with no update the view is hidden.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.