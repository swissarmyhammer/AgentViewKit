---
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ABMYXZQRNRDGB3DR6RK73
- 01M21AC5SYQ8PTDZBVTPG26SDH
- 01M21BD96KGE840RF97MXKS47E
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: todo
position_ordinal: '8e80'
title: AgentThreadView and ItemRow with per-record re-render, plus StructuredItemView and UnknownItemView (plan §3.6, §8, §9 A2)
---
## What
Create `Sources/AgentViewKit/Thread/AgentThreadView.swift`, `ItemRow.swift`, `Sources/AgentViewKit/Items/StructuredItemView.swift`, and `Sources/AgentViewKit/Items/UnknownItemView.swift`, per plan.md §3.6, §8, and §9 A2. The registries come from their own task; `ConversationView` scroll chrome comes in a later task.

- `AgentThreadView(thread:)`: a `ScrollView { LazyVStack { ForEach(thread.items, id: \.id) { ItemRow(item:) } } }`. The later `ConversationView` task replaces the plain scroll view.
- `ItemRow`: reads only its record, applies `.equatable()` on `(id, revision)`, and switches over `ThreadItem`. For each kind it reads the `ItemViewOverrides` key first, else a default. Defaults in this task: `StructuredItemView` for `.structured` after a `StructuredItemRegistry` miss, `UnknownItemView` for `.unknown`, and a labelled placeholder `Text` for the other seven kinds. Later tasks replace the placeholders.
- `StructuredItemView(record:)`: a disclosure with the `schemaName` and the payload as `JSONValue.prettyPrinted` in a monospaced `Text`.
- `UnknownItemView(record:)`: a disclosure with the raw kind and the raw JSON.
- Every row calls `BodyEvaluationCounter.note("row-<id>")` under `#if DEBUG`.
- Accessibility identifiers: `item-row-<id>`, `structured-item-<schemaName>`, `unknown-item`.

## Acceptance Criteria
- [ ] `.toolCallView { … }` replaces the default for tool calls only.
- [ ] A patch to one record of ten leaves `BodyEvaluationCounter` at one new evaluation for that row and zero for the other nine.
- [ ] An unregistered `.structured` item renders `structured-item-<schemaName>`; a registered one renders the registration.
- [ ] `.unknown` renders `unknown-item`.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/AgentThreadViewHostedTests.swift`: mount, override, patch counts.
- [ ] `Tests/AgentViewKitTests/Items/StructuredAndUnknownItemViewHostedTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.