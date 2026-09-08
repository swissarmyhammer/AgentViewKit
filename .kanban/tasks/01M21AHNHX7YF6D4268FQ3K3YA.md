---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: '9580'
title: ReasoningView, ShimmerView, ActivityIndicator (plan §5, §9 B)
---
## What
Create `Sources/AgentViewKit/Activity/ShimmerView.swift`, `ActivityIndicator.swift`, and `Sources/AgentViewKit/Items/ReasoningView.swift`, per plan.md §5 and §9 B.

- `ShimmerView(text:)`: a label with a moving highlight. Reads `\.accessibilityReduceMotion`; when true it shows a static label. Under `#if DEBUG` its accessibility value is `"animating"` or `"static"`.
- `ActivityIndicator(state:)`: `thinking` shows a shimmer; `runningTool(name)` shows a `ProgressView` and the name; `idle` shows nothing. Identifier `activity-indicator`.
- `ReasoningView(record:isInProgress:)`: a collapsible block, identifier `reasoning-<id>`. While in progress, the title shimmers and the body streams through `ResponseView`. On completion the title becomes "Thought for N s" from the timestamps when present, and the block collapses unless the user expanded it. Expanded state lives in `ExpandedBlocksStore`.
- In-progress is derived: a reasoning item is in progress when it is the last item and `thread.state == .running`.

## Acceptance Criteria
- [ ] With `\.accessibilityReduceMotion` true in the hosted environment, the shimmer element value is `"static"`; with false it is `"animating"`.
- [ ] A reasoning item that is last while running mounts the shimmer; after a following message its title is "Thought for N s".
- [ ] A user expansion survives the auto-collapse on completion.

## Tests
- [ ] `Tests/AgentViewKitTests/Activity/ReasoningViewHostedTests.swift`: the three cases with the environment set through the harness.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.