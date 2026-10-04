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
Source: update.md §4.2 (last-value state `usage`), §4.5 (kit `ContextUsage` replaced by the ACP type).

- [ ] `ContextUsageView` (`Sources/AgentViewKit/Status/ContextUsageView.swift`) reads `SessionModel.usage` (the ACP usage update: `used`, `size`, cost when present).
- [ ] Show nothing when `usage` is nil.
- [ ] Remove the kit `ContextUsage` use from this view.

## Acceptance Criteria
- [ ] After a `usage_update`, the view shows used of size and the cost when the agent sends it.
- [ ] With no usage update, the view is hidden.

## Tests
- [ ] `Tests/AgentViewKitTests/Status/ContextUsageSessionModelHostedTests.swift`: with and without a usage update; with and without cost.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.