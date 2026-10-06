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
Source: update.md §4.3 (state, initialize result, auth state), §4.7 ("Connection banner"), §9.4 (connection state not shown, agent information not used, error code lost). Owner rule (2026-10-06): the views bind directly to the observable model of FoundationModelsACPClient. They show what `ConnectionModel` holds and call its methods. The kit keeps no connection state, no auth state, no auth method list and no error map of its own for the agent connection.

- [ ] Show the agent connection from `ConnectionModel.state` (the client `ConnectionState`: `.disconnected`, `.connecting`, `.connected`, `.failed`), read directly in the body. Show a banner for `.disconnected` and `.failed` with the error text. No kit code writes the agent connection state into `ConnectionStore` or into the kit `ConnectionState` enum (`Sources/AgentViewKit/Connections/ConnectionStore.swift`); the MCP server rows of `ConnectionStore` are not part of this task.
- [ ] Show the agent name and version from `ConnectionModel.initializeResponse` (agent info), not from the host.
- [ ] `AgentAuthView` (`Sources/AgentViewKit/Connections/AgentAuthView.swift`) takes the `ConnectionModel`. It reads `authMethods`, `authState` and `canLogout` directly, and calls `login(_:)` and `logout(_:)`. Remove the `methods:` and `isAuthenticated:` parameters, which copy model values. Show a login failure from `authState` `.failed(RequestError)`, not from the kit `errors` map. A per-button "call in progress" flag stays view state. Hide logout when `canLogout` is false.
- [ ] When a request fails with JSON-RPC code `-32000` (authentication required), read the code from the `ErrorEntry` that the model adds (the kit keeps no error list), and start the login flow.

## Acceptance Criteria
- [ ] A transport close changes `ConnectionModel.state`, and the disconnected banner shows with no other step.
- [ ] The header shows the agent name from the `initialize` result.
- [ ] A login that the agent refuses shows the error of `authState` `.failed`; a successful login hides the sign-in rows because `authState` becomes `.authenticated`.
- [ ] A prompt that fails with `-32000` opens the login view.

## Tests
- [ ] `Tests/AgentViewKitTests/Connections/ConnectionModelViewsHostedTests.swift`: one test for each criterion, with a scripted agent that closes, that sends agent info, that refuses a login, and that answers `-32000`. Assert the `auth/login` frame for the Sign In button.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.