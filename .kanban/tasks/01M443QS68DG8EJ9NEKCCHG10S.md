---
assignees:
- claude-code
depends_on:
- 01M443NCQ6B4040Y9X0SBNCN28
- 01M443NN55C6HTFT2F2REPFZA1
position_column: todo
position_ordinal: 9d80
title: 'Bind the connection banner and auth views to ConnectionModel: state, agent info, login on error -32000'
---
## What
Source: update.md §4.3 (state, initialize result, auth state), §4.7 ("Connection banner"), §9.4 (connection state not shown, agent information not used, error code lost).

- [ ] `ConnectionStatusChip` and `ConnectionsView` (`Sources/AgentViewKit/Connections/`) read `ConnectionModel.state` (`.connecting`, `.connected`, `.disconnected`, `.failed`). Show a banner for `.disconnected` and `.failed` with the error text. Remove the kit connection state in `ConnectionStore` that duplicates it.
- [ ] Show the agent name and version from `ConnectionModel.initializeResponse` (agent info), not from the host.
- [ ] `AgentAuthView` reads `ConnectionModel.authMethods` and `authState`, and calls `login(_:)` and `logout(_:)`. Hide logout when `canLogout` is false.
- [ ] When a request fails with JSON-RPC code `-32000` (authentication required), keep the code in the error entry and start the login flow.

## Acceptance Criteria
- [ ] A transport close shows the disconnected banner.
- [ ] The header shows the agent name from the `initialize` result.
- [ ] A prompt that fails with `-32000` opens the login view.

## Tests
- [ ] `Tests/AgentViewKitTests/Connections/ConnectionModelViewsHostedTests.swift`: one test for each criterion, with a scripted agent that closes, that sends agent info, and that answers `-32000`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.