---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: '9880'
title: TaskListView, StateBanner, ContextUsageView (plan §9 A, §9 C)
---
## What
Create `Sources/AgentViewKit/Status/TaskListView.swift`, `StateBanner.swift`, and `ContextUsageView.swift`, per plan.md §9 A and §9 C.

- `TaskListView(plans:)`: one checklist per plan id. Each entry shows a status symbol (pending, inProgress with `ProgressView`, completed, cancelled with strikethrough, unknown) and a priority tint. Reads `thread.plans` and updates in place on replace.
- `StateBanner(state:)`: hidden for `idle(endTurn)` and `running`. Shows a glass bar for `requiresAction` ("The agent needs your input") and for `idle` with `maxTokens`, `maxTurnRequests`, or `refusal`, each with a short explanation and a link to the related `ErrorView` when one exists.
- `ContextUsageView(usage:)`: a ring or bar with `used` of `size`, a tooltip with input, output, cached, and reasoning tokens when present, a cost label when present, and a quota state when present. Reads `thread.usage`.

## Acceptance Criteria
- [ ] Replacing a plan keeps the list identity and updates the entries.
- [ ] `StateBanner` is absent for `running` and present for `requiresAction`.
- [ ] `ContextUsageView` shows "50%" for `used 500, size 1000` and hides cost when nil.

## Tests
- [ ] `Tests/AgentViewKitTests/Status/TaskListViewHostedTests.swift`.
- [ ] `Tests/AgentViewKitTests/Status/StateBannerHostedTests.swift`: one case per state.
- [ ] `Tests/AgentViewKitTests/Status/ContextUsageViewHostedTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.