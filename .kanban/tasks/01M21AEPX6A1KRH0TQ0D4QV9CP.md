---
comments:
- actor: claude-code
  id: 01m2nra2jery7f4za09kqh7y0e
  text: |-
    ### implement — changed
    - Decision: the environment has a new key `expandedBlocksStore: ExpandedBlocksStore?`. `AgentThreadView` gives its own store to the rows when the host gives none. `StructuredItemView` and `UnknownItemView` keep the expanded state in that store, keyed by record id. With no store, they keep local state; `isExpanded:` sets the start state. Later tasks (SystemPromptView, ReasoningView, ToolCallView) can read the same key.
    - Decision: `ItemRow ==` compares the record object, the id, and the revision. A new record object with the same id and revision (remove, then insert) is then a different row.
    - Decision: each kind reads its override through a private generic view with only its own environment key, so a change to one override does not invalidate rows of other kinds.
    - Placeholders of the seven other kinds have the identifier `item-placeholder-<id>`.
    - Shared disclosure: `Sources/AgentViewKit/Items/JSONDisclosure.swift`. A `.contain` element on it made the row identifier hide the inner identifier, so the identifier is on the disclosure itself.
    - evidence: `swift test` green, 733 tests (566 in AgentViewKitTests).
    - next: commit, then review.
  timestamp: 2026-09-16T18:40:17.998374+00:00
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
- [x] `.toolCallView { … }` replaces the default for tool calls only.
- [x] A patch to one record of ten leaves `BodyEvaluationCounter` at one new evaluation for that row and zero for the other nine.
- [x] An unregistered `.structured` item renders `structured-item-<schemaName>`; a registered one renders the registration.
- [x] `.unknown` renders `unknown-item`.

## Tests
- [x] `Tests/AgentViewKitTests/Thread/AgentThreadViewHostedTests.swift`: mount, override, patch counts.
- [x] `Tests/AgentViewKitTests/Items/StructuredAndUnknownItemViewHostedTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.