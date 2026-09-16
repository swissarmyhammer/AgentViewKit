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
- actor: claude-code
  id: 01m2nyfhmb36af23zynh0az3py
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 3 files (AuthorizationView.swift, AuthorizationViewHostedTests.swift, connection-states.md)
    - test: green — swift test, 870 passed (693 + 85 + 71 + 20 + 1), only the accepted mlx warning
    - commit: 32cc198
    - review: findings — AuthorizationView.swift:85, :103, :111, :119; AuthorizationViewHostedTests.swift:207
  timestamp: 2026-09-16T20:28:08.715219+00:00
- actor: claude-code
  id: 01m2nypvcpswzkw3w4m3xb2scv
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — shared `makeIdentifier` helper for all six identifier builders; named test constants (cardWidth, cardHeight, waitTimeout, pollInterval, expectedCalls)
    - test: green — swift test, 870 passed, only the accepted mlx warning
    - commit: 2d645ce
    - review: findings — AuthorizationViewHostedTests.swift:204 (the literal in `.milliseconds(10)`). Fixed after the review with `pollIntervalMilliseconds`; local swiftlint no_magic_numbers reports 0 violations; swift test green (870).
  timestamp: 2026-09-16T20:32:08.086632+00:00
depends_on:
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: review
position_ordinal: '80'
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

## Review Findings (2026-09-16 15:24)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 5 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `Docs/decisions/connection-states.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Connections/AuthorizationView.swift:85` `duplication/duplication` — The titleIdentifier method copies the identifier method at lines 77-79. Both do the same work: take a prefix and an ID and build a string. Extract shared code instead. Make a new private static method that takes a prefix value and builds the identifier string. Call this method from all five accessors: identifier, titleIdentifier, connectIdentifier, retryIdentifier, and errorIdentifier.
- [x] `Sources/AgentViewKit/Connections/AuthorizationView.swift:103` `duplication/duplication` — The connectIdentifier method copies the identifier method at lines 77-79. Both do the same work: take a prefix and an ID and build a string. Extract shared code instead. Make a new private static method that takes a prefix value and builds the identifier string. Call this method from all five accessors: identifier, titleIdentifier, connectIdentifier, retryIdentifier, and errorIdentifier.
- [x] `Sources/AgentViewKit/Connections/AuthorizationView.swift:111` `duplication/duplication` — The retryIdentifier method copies the identifier method at lines 77-79. Both do the same work: take a prefix and an ID and build a string. Extract shared code instead. Make a new private static method that takes a prefix value and builds the identifier string. Call this method from all five accessors: identifier, titleIdentifier, connectIdentifier, retryIdentifier, and errorIdentifier.
- [x] `Sources/AgentViewKit/Connections/AuthorizationView.swift:119` `duplication/duplication` — The errorIdentifier method copies the identifier method at lines 77-79. Both do the same work: take a prefix and an ID and build a string. Extract shared code instead. Make a new private static method that takes a prefix value and builds the identifier string. Call this method from all five accessors: identifier, titleIdentifier, connectIdentifier, retryIdentifier, and errorIdentifier.
- [x] `Tests/AgentViewKitTests/Connections/AuthorizationViewHostedTests.swift:207` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.

## Review Findings (2026-09-16 15:29)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Tests/AgentViewKitTests/Connections/AuthorizationViewHostedTests.swift:204` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.