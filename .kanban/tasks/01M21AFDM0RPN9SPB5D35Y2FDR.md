---
comments:
- actor: claude-code
  id: 01m2nczm5henqq54jftz3e0y9v
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 4 source files in Sources/AgentViewKit/Connections, a List-row fallback in HostedViewHarness, Docs/decisions/connection-states.md
    - test: green — swift test: 319 AgentViewKitTests, 20 package tests, 3 adapter tests, 0 warnings in the package files
    - commit: 031961a
    - review: clean — review sha HEAD~1..HEAD, 0 findings (7 files attempted)
    - decisions: the edge table is in Docs/decisions/connection-states.md. A tool toggle has the identifier connection-tool-<connection id>-<tool id>, because two servers can have a tool with the same name. A tool toggle uses the stock check box style, because the switch style has no accessibility label on macOS 27. The harness now reads List row children through the informal accessibility getter; later List views (SessionListView and others) can use this.
  timestamp: 2026-09-16T15:22:21.233082+00:00
depends_on:
- 01M21A9KJGPPJE0X01JE0B9V33
- 01M21ABMYXZQRNRDGB3DR6RK73
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: done
position_ordinal: 8d80
title: ConnectionStore, ConnectionsView, ConnectionRow, ConnectionStatusChip (plan §12)
---
## What
Create `Sources/AgentViewKit/Connections/ConnectionStore.swift`, `ConnectionsView.swift`, `ConnectionRow.swift`, and `ConnectionStatusChip.swift`, per plan.md §12. `AuthorizationPresenter` comes in its own task.

- `Connection`: `id`, `name`, `state` (`disconnected`, `connected`, `needsAuth`, `authenticating`, `expired`, `error(String)`), `tools: [ToolToggle]`. `ToolToggle { id, name, isEnabled }`.
- `ConnectionStore` (`@MainActor @Observable`): `connections`, `transition(id, to:)` with the allowed edges from §12 (a disallowed edge is a no-op and logs), `setToolEnabled(connectionID, toolID, Bool)`. Delegates `connect(id)` and `disconnect(id)` to a `ConnectionActions` protocol the host implements.
- `EnvironmentValues.connectionStore` and `.connectionStore(_:)`.
- `ConnectionStatusChip(state)`: a dot and a label per state. Accessibility identifier `connection-chip-<state>`, label the state name.
- `ConnectionRow` and `ConnectionsView`: a `List` with Connect or Disconnect per row and a toggle per tool. Identifiers `connection-row-<id>`, `connection-tool-<id>`.

## Acceptance Criteria
- [x] `transition` from `connected` to `needsAuth` succeeds; from `disconnected` to `expired` is a no-op.
- [x] Mounting the chip for each of the six states gives six distinct identifiers and labels.
- [x] `ConnectionsView` with two connections and three tools mounts two row elements and three tool toggles; a toggle press calls `setToolEnabled`.

## Tests
- [x] `Tests/AgentViewKitTests/Connections/ConnectionStoreTests.swift`: the edge table.
- [x] `Tests/AgentViewKitTests/Connections/ConnectionsViewHostedTests.swift`: rows, toggles, and chip identifiers through the harness.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.