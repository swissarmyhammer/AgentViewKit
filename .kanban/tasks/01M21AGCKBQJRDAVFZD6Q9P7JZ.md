---
comments:
- actor: claude-code
  id: 01m2n2jt7he6hfmtbbe9c5nmr9
  text: 'Note from ^he8kkt1: the `ProcessLauncher` and `LaunchedProcess` protocols are now in `Sources/AgentViewKit/Platform/ProcessLauncher.swift` (the test-support target links only the kit). Signature: `launch(program:arguments:environment:) throws -> any LaunchedProcess`; `LaunchedProcess` has `output: AsyncStream<Data>`, `exitStatus: Int32?`, `write(_:) throws`, `terminate()`. In this task, add only the default launcher over `AgentProcess` in `Sources/AgentViewKitACP/ProcessLauncher.swift`. `FakeProcessLauncher` is in `AgentViewKitTestSupport`.'
  timestamp: 2026-09-16T12:20:35.697485+00:00
depends_on:
- 01M21ADNAKRK96TKZQMRMW1MG7
- 01M21BDG310SH8A60AFWXKPSDC
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: todo
position_ordinal: '9180'
title: 'ACP verbs: send, cancel, permission, elicitation, config, connect, login, terminal auth, logout through SwiftUIACPClient (plan §3.4, §12)'
---
## What
Create `Sources/AgentViewKitACP/ACPThreadActions.swift` and `ProcessLauncher.swift`, per plan.md §3.4 and §12.

- `ProcessLauncher` protocol: `launch(program:arguments:environment:) -> LaunchedProcess` with `output: AsyncStream<Data>`, `write(_:)`, `terminate()`, `exitStatus`. The default wraps `AgentProcess` from `../FoundationModelsACPClient`. Tests inject `FakeProcessLauncher`.
- `ACPThreadActions: AgentThreadActions` over a `SwiftUIACPClient`, a `SessionId`, an `AuthorizationPresenter`, and a `ProcessLauncher`.
- `send`: `session/prompt` with `[ContentBlock]` built from `UserInput` (text, image attachments as base64 `image` blocks, files as `resource_link`).
- `cancel`: `session/cancel`.
- `respond(to: PermissionRequest,_:)`: `answerPermissionRequest` with `selected(optionId)` or `cancelled`. When `decision.comment` is set, send it as the next prompt after the answer.
- `respond(to: ElicitationRequest,_:)`: `acceptElicitation(_:content:)`, `declineElicitation`, or `cancelElicitation`.
- `setConfigOption`: `session/set_config_option` with `Value.id` or `.boolean`; apply the returned full `configOptions` list to the thread.
- `connect(request)`: transitions the `ConnectionStore` entry for `request.serverName` to `authenticating`, presents `request.authorizationURL` through the presenter, and on the callback URL accepts the elicitation whose id is in `request.meta["elicitationId"]` when present; then transitions to `connected`. On a thrown error it transitions to `error(message)` and rethrows.
- `login(methodId)`: `auth/login`. `runTerminalAuth(method)`: launches the configured agent program through `ProcessLauncher` with the method's `args` and `env`, and exposes its output as a `TerminalRecord` on the thread. `logout()`: `auth/logout`.

## Acceptance Criteria
- [ ] Each of send, cancel, permission, elicitation, config, login, and logout sends the expected JSON-RPC method and params over an `InMemoryTransport`.
- [ ] A rejection with a comment sends the answer, then a prompt with the comment text.
- [ ] `runTerminalAuth` calls `FakeProcessLauncher.launch` with the method's args and env, never calls `auth/login`, and the thread gains a `TerminalRecord` with the scripted output.
- [ ] `connect` with `FakeWebAuthSession` moves the store entry through `authenticating` to `connected` and accepts the elicitation id from `meta`.
- [ ] `setConfigOption` replaces `thread.configOptions` with the response list.

## Tests
- [ ] `Tests/AgentViewKitACPTests/ACPThreadActionsTests.swift`: one test per verb against a scripted in-memory agent that records requests, with the fakes injected.
- [ ] `swift test --filter AgentViewKitACPTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.