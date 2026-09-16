---
comments:
- actor: claude-code
  id: 01m2ny8jm23mzmza39k2p87vz1
  text: |-
    Decisions (no user question; they follow plan.md §12):
    - `PendingRequestsHost` does not exist yet. The PermissionView task ^y5ra063 creates it. This task does not need it for its criteria, so I added no dependency. I wrote the requirement as a comment on ^y5ra063.
    - The card finds the server by `ConnectionID(serverName)`, then by display name. With no match or no store, the chip shows `needs-auth`.
    - The card does not change the store. Only the chip of the card shows `authenticating` while `connect` runs.
    - SwiftUI merges the Connect button into its ProgressView (role `AXBusyIndicator`). The test checks that role.
    - On error, a Retry button replaces the Connect button. A CancellationError shows no error.
    - Recorded in Docs/decisions/connection-states.md.
  timestamp: 2026-09-16T20:24:20.354189+00:00
depends_on:
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: doing
position_ordinal: '8180'
title: 'AuthorizationView: the in-thread Connect card for an MCP server (plan §12)'
---
## What
Create `Sources/AgentViewKit/Connections/AuthorizationView.swift`, per plan.md §12.

- `AuthorizationView(request: AuthorizationRequest)`: a glass card with "Connect to <serverName>", the requested scopes as chips, a `.glassProminent` Connect button that calls `AgentThreadActions.connect(_:)`, and a `ConnectionStatusChip` for the server's state read from the ambient `ConnectionStore`.
- While `connect` runs, the button shows a `ProgressView` and the chip shows `authenticating`. On error the card shows the message and offers Retry.
- The card is rendered by `PendingRequestsHost` for each entry in `thread.pendingAuthorizations`.

## Acceptance Criteria
- [x] A tap on Connect calls `connect` with the request.
- [x] The chip label follows the store state for the server.
- [x] A thrown error shows the message and a Retry button.

## Tests
- [x] `Tests/AgentViewKitTests/Connections/AuthorizationViewHostedTests.swift`: the three cases through `NoopThreadActions` and a seeded `ConnectionStore`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.