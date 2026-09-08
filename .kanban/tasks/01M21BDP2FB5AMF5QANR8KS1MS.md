---
depends_on:
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: todo
position_ordinal: b380
title: 'AuthorizationView: the in-thread Connect card for an MCP server (plan §12)'
---
## What
Create `Sources/AgentViewKit/Connections/AuthorizationView.swift`, per plan.md §12.

- `AuthorizationView(request: AuthorizationRequest)`: a glass card with "Connect to <serverName>", the requested scopes as chips, a `.glassProminent` Connect button that calls `AgentThreadActions.connect(_:)`, and a `ConnectionStatusChip` for the server's state read from the ambient `ConnectionStore`.
- While `connect` runs, the button shows a `ProgressView` and the chip shows `authenticating`. On error the card shows the message and offers Retry.
- The card is rendered by `PendingRequestsHost` for each entry in `thread.pendingAuthorizations`.

## Acceptance Criteria
- [ ] A tap on Connect calls `connect` with the request.
- [ ] The chip label follows the store state for the server.
- [ ] A thrown error shows the message and a Retry button.

## Tests
- [ ] `Tests/AgentViewKitTests/Connections/AuthorizationViewHostedTests.swift`: the three cases through `NoopThreadActions` and a seeded `ConnectionStore`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.