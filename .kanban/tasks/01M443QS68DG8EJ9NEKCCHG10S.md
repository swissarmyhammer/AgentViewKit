---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m49f4qyhwtfe8626pse1rn0v
  text: |-
    Research (implement step):
    - `ConnectionModel.state` (client `ConnectionState`) goes to `.disconnected` on end of input or a local close, and to `.failed(error)` on a transport failure. On a close, the model also closes each open `SessionModel`.
    - `initializeResponse.info` is an ACP `Implementation` (`name`, `version`, `title`).
    - `AuthState` cases: `.unknown`, `.notRequired`, `.required([AuthMethod])`, `.authenticated(AuthMethodId)`, `.failed(RequestError)`. `login(_:)` sets `.failed` only for a `RequestError`. A `ConnectionError` changes no state. `logout(_:)` changes no state on failure.
    - `SessionModel.prompt` adds an `ErrorEntry` with the JSON-RPC code on failure. `ErrorCode.authenticationRequired` is `-32000`.
    - `ConnectionModel.authMethods` gives ACP `AuthMethod` values. `AgentThreadActions.runTerminalAuth(_:)` takes the kit `AuthMethod.Terminal`. The model has no terminal auth runner, so the terminal row stays on the thread actions, with `SessionUpdateMapping.authMethod(_:)` at the time of the press.
    - `ScriptedWireAgent.failingMethods` always sends code -32603. The tests need -32000, so the agent needs a code for each failing method.
    - The demo `ACPSettingsSheet` calls `AgentAuthView(methods:isAuthenticated:thread:)`, so the demo changes too.
  timestamp: 2026-10-06T20:40:36.561374+00:00
- actor: claude-code
  id: 01m49gc3cr38g7j4ngdzt3z3by
  text: |-
    Implementation landed (TDD: the tests failed first because the new API did not exist, then passed).

    New views in `Sources/AgentViewKit/Connections/`:
    - `AgentConnectionBanner(connection:)`: reads `ConnectionModel.state` in the body. `.disconnected` and `.failed(error)` show a `StatusBar`; the failed banner shows `error.localizedDescription`. The kit has its own `ConnectionState` (MCP servers), so the code names the client type `FoundationModelsACPClient.ConnectionState`.
    - `AgentInfoHeader(connection:)`: reads `initializeResponse?.info`: `title ?? name`, and "Version <version>". Nothing before `initialize`.
    - `AgentLoginPrompt` (internal): shows `AgentAuthView(connection:)` while the last transcript entry is an `ErrorEntry` with `ErrorCode.authenticationRequired` (-32000). It also puts the session model in the environment.
    - `AgentThreadView(session:connection:...)` shows the header and the banner above the conversation, and the login prompt below it, when the host gives the connection model.

    `AgentAuthView` is now `init(connection:thread:)`. `methods:` and `isAuthenticated:` are gone. The `errors` map is gone. `rowIdentifier`, `signInIdentifier` and `runIdentifier` take the ACP `AuthMethodId`. New `loginErrorIdentifier`; `errorIdentifier(for:)` and `signOutErrorIdentifier` are removed.

    Decisions and gaps for the owner:
    1. The model has no terminal auth runner. The Run button still calls `AgentThreadActions.runTerminalAuth(_:)`, which takes the kit `AuthMethod.Terminal`. The view changes the ACP method with `SessionUpdateMapping.authMethod(_:)` at the time of the press, and keeps no copy. ^h1116ab and ^9vvaejb remove these types; then the Run row needs a new source.
    2. The model records no failure of `logout(_:)` and no `ConnectionError` of `login(_:)`. The card sends such a failure to the log and, when the environment has a session model, to `SessionModel.appendError` (update.md §4.7 rule for requests that the model does not record). The settings sheet has no session model, so there the failure only goes to the log.
    3. Sign Out shows whenever `canLogout` is true, also before a login, because the model cannot tell if the agent keeps a stored login.
    4. After a successful login, the login prompt in the thread stays (with no method rows) until the next transcript entry, because the last entry is still the -32000 error entry.
    5. `ACPDemoSession.authMethods` (a kit copy) is no longer read by the demo sheet. `ACPDemoSessionTests` still read it. ^s0edeb23 removes `ACPDemoSession`.

    Test support: `ScriptedWireAgent.errorCodes` (error code for each failing method, default -32603) and `ScriptedSession.makeInitializeResult(info:authMethods:)` with `ScriptedSession.agentInfo`.

    Discovery: a hosted test that waits only on a model value can read the view before SwiftUI draws the same main-actor turn. `aFailedSignOutAddsAnErrorEntryToTheSession` failed one time in the full suite for this reason. The wait now also checks the view state.
  timestamp: 2026-10-06T21:02:06.232066+00:00
- actor: claude-code
  id: 01m49gc6czyzjpdst2d3a1east
  text: |-
    ### implement — changed
    - evidence: 10 files. New: Sources/AgentViewKit/Connections/AgentConnectionBanner.swift, AgentInfoHeader.swift, AgentLoginPrompt.swift, Tests/AgentViewKitTests/Connections/ConnectionModelViewsHostedTests.swift. Changed: Sources/AgentViewKit/Connections/AgentAuthView.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKitTestSupport/ScriptedSession.swift, Sources/DemoSupport/ScriptedWireAgent.swift, Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPSettingsSheet.swift. `swift test`: 1327 tests in 123 suites passed, no new warnings. `Scripts/test-examples.sh AgentViewKitDemo`: TEST SUCCEEDED. README not changed.
    - next: /review
  timestamp: 2026-10-06T21:02:09.311547+00:00
- actor: claude-code
  id: 01m49gcfjd18pg0g7283ax08pk
  text: 'Correction to the implementation comment: the task "Remove the kit copies of the ACP value types" is ^71k836q, not "^9vvaejb". That task removes the kit `AuthMethod` and says that no view converts a model value to a kit value, so it must also remove the `SessionUpdateMapping.authMethod(_:)` call in the Run button of `AgentAuthView`.'
  timestamp: 2026-10-06T21:02:18.701405+00:00
depends_on:
- 01M443NCQ6B4040Y9X0SBNCN28
- 01M443NN55C6HTFT2F2REPFZA1
position_column: doing
position_ordinal: '80'
title: 'Bind the connection banner and auth views to ConnectionModel: state, agent info, login on error -32000'
---
## What
Source: update.md §4.3 (state, initialize result, auth state), §4.7 ("Connection banner"), §9.4 (connection state not shown, agent information not used, error code lost). Owner rule (2026-10-06): the views bind directly to the observable model of FoundationModelsACPClient. They show what `ConnectionModel` holds and call its methods. The kit keeps no connection state, no auth state, no auth method list and no error map of its own for the agent connection.

Scope limit (owner decision, 2026-10-06): this task does not add an agent connection mirror into `ConnectionStore`. This task does not change the MCP connection views (`ConnectionsView`, `ConnectionRow`, `ConnectionStatusChip`) or `ConnectionStore`. Task ^s3zygvh owns them.

- [x] Show the agent connection from `ConnectionModel.state` (the client `ConnectionState`: `.disconnected`, `.connecting`, `.connected`, `.failed`), read directly in the body. Show a banner for `.disconnected` and `.failed` with the error text. Do not add an agent connection row or an agent connection state to `ConnectionStore` or to the kit `ConnectionState` enum (`Sources/AgentViewKit/Connections/ConnectionStore.swift`). Do not change `ConnectionsView`, `ConnectionRow` or `ConnectionStatusChip`.
- [x] Show the agent name and version from `ConnectionModel.initializeResponse` (agent info), not from the host.
- [x] `AgentAuthView` (`Sources/AgentViewKit/Connections/AgentAuthView.swift`) takes the `ConnectionModel`. It reads `authMethods`, `authState` and `canLogout` directly, and calls `login(_:)` and `logout(_:)`. Remove the `methods:` and `isAuthenticated:` parameters, which copy model values. Show a login failure from `authState` `.failed(RequestError)`, not from the kit `errors` map. A per-button "call in progress" flag stays view state. Hide logout when `canLogout` is false.
- [x] When a request fails with JSON-RPC code `-32000` (authentication required), read the code from the `ErrorEntry` that the model adds (the kit keeps no error list), and start the login flow.

## Acceptance Criteria
- [x] A transport close changes `ConnectionModel.state`, and the disconnected banner shows with no other step.
- [x] The header shows the agent name from the `initialize` result.
- [x] A login that the agent refuses shows the error of `authState` `.failed`; a successful login hides the sign-in rows because `authState` becomes `.authenticated`.
- [x] A prompt that fails with `-32000` opens the login view.

## Tests
- [x] `Tests/AgentViewKitTests/Connections/ConnectionModelViewsHostedTests.swift`: one test for each criterion, with a scripted agent that closes, that sends agent info, that refuses a login, and that answers `-32000`. Assert the `auth/login` frame for the Sign In button.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.