---
depends_on:
- 01M21A9KJGPPJE0X01JE0B9V33
- 01M21ABMYXZQRNRDGB3DR6RK73
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: '9080'
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
- [ ] `transition` from `connected` to `needsAuth` succeeds; from `disconnected` to `expired` is a no-op.
- [ ] Mounting the chip for each of the six states gives six distinct identifiers and labels.
- [ ] `ConnectionsView` with two connections and three tools mounts two row elements and three tool toggles; a toggle press calls `setToolEnabled`.

## Tests
- [ ] `Tests/AgentViewKitTests/Connections/ConnectionStoreTests.swift`: the edge table.
- [ ] `Tests/AgentViewKitTests/Connections/ConnectionsViewHostedTests.swift`: rows, toggles, and chip identifiers through the harness.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.