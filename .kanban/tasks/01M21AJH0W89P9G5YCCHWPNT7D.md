---
comments:
- actor: claude-code
  id: 01m2nvgm5h9hgyeh01nypqhdb4
  text: |-
    Decisions:
    - `TaskListView(plans: [PlanID: Plan])` takes `thread.plans`. Plans show sorted by the raw id. The row identity is `task-entry-<plan>-<index>`, because a List needs row ids that are unique over all sections.
    - The priority tint and the plan status color come from new `AgentTheme.StatusColors.color(for: PlanEntry.Priority)` and `color(for: PlanEntry.Status)`. High uses `failed`, medium uses `running`, low uses `pending`.
    - ErrorView does not exist yet. `StateBanner(state:errorID:onShowError:)` shows a Show Error button when the host gives both values. A note is on ^8gn3p (ErrorView task 01M21BE4VMRYQA77767APWFM0S).
    - `AgentTheme.MaterialLevel.glass` (internal) maps the level to Liquid Glass. SwiftUI has no thin glass, so thin uses clear.
    - `ContextUsageView(usage: ContextUsage?)` is empty for nil. The ring help tag and the accessibility hint show the token counts.
  timestamp: 2026-09-16T19:36:18.353052+00:00
- actor: claude-code
  id: 01m2nvq77dnk17k2q4j8j352nq
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 9 files (3 views, glass map, status colors, 4 test files)
    - test: green — swift test --filter AgentViewKitTests, 632 tests in 55 suites passed
    - commit: 728fb56
    - review: findings — Sources/AgentViewKit/Status/ContextUsageView.swift:36 (code-hygiene/magic-numbers-swift)
    - correction: the ErrorView task short id is ^apwfm0s, not ^8gn3p as the decisions comment says.
  timestamp: 2026-09-16T19:39:54.477658+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: doing
position_ordinal: '8180'
title: TaskListView, StateBanner, ContextUsageView (plan §9 A, §9 C)
---
## What
Create `Sources/AgentViewKit/Status/TaskListView.swift`, `StateBanner.swift`, and `ContextUsageView.swift`, per plan.md §9 A and §9 C.

- `TaskListView(plans:)`: one checklist per plan id. Each entry shows a status symbol (pending, inProgress with `ProgressView`, completed, cancelled with strikethrough, unknown) and a priority tint. Reads `thread.plans` and updates in place on replace.
- `StateBanner(state:)`: hidden for `idle(endTurn)` and `running`. Shows a glass bar for `requiresAction` ("The agent needs your input") and for `idle` with `maxTokens`, `maxTurnRequests`, or `refusal`, each with a short explanation and a link to the related `ErrorView` when one exists.
- `ContextUsageView(usage:)`: a ring or bar with `used` of `size`, a tooltip with input, output, cached, and reasoning tokens when present, a cost label when present, and a quota state when present. Reads `thread.usage`.

## Acceptance Criteria
- [x] Replacing a plan keeps the list identity and updates the entries.
- [x] `StateBanner` is absent for `running` and present for `requiresAction`.
- [x] `ContextUsageView` shows "50%" for `used 500, size 1000` and hides cost when nil.

## Tests
- [x] `Tests/AgentViewKitTests/Status/TaskListViewHostedTests.swift`.
- [x] `Tests/AgentViewKitTests/Status/StateBannerHostedTests.swift`: one case per state.
- [x] `Tests/AgentViewKitTests/Status/ContextUsageViewHostedTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 14:36)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 9 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Sources/AgentViewKit/Status/ContextUsageView.swift:36` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.