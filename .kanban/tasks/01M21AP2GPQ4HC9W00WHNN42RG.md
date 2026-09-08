---
depends_on:
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21AJ767SWK19SZA82PZWGZ2
- 01M21AGCKBQJRDAVFZD6Q9P7JZ
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: a380
title: 'AgentAuthView: agent and terminal auth methods with sign-out (plan §9 E2, §12)'
---
## What
Create `Sources/AgentViewKit/Connections/AgentAuthView.swift`, per plan.md §9 E2 and §12 item 5.

- `AgentAuthView(methods: [AuthMethod], isAuthenticated: Bool)`: one row per method. An `agent` method shows a Sign in button that calls `AgentThreadActions.login(methodId)`. A `terminal` method shows a Run button that calls `runTerminalAuth(method)` and then hosts the returned `TerminalRecord` in a `TerminalView` with `stdin` enabled. When authenticated, a Sign out button calls `logout()`.
- The view appears in-thread when the ACP source reports `authenticationRequired` (error code -32000) and in the settings surface next to `ConnectionsView`.
- The `terminal` method never calls `login`.

## Acceptance Criteria
- [ ] An `agent` row calls `login` with the method id.
- [ ] A `terminal` row calls `runTerminalAuth` and shows a `TerminalView` with an input field.
- [ ] Sign out calls `logout` and is hidden when not authenticated.

## Tests
- [ ] `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift`: the three cases through `NoopThreadActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.