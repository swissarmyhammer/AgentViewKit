---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4ak7agddd6h020s0td1anhm
  text: 'Note from ^h1116ab: `ACPThreadActions.swift` is deleted (no host used it; the demo and the README give `LoggingThreadActions`). `AgentThreadActions.runTerminalAuth(_:)` now takes the ACP `AuthMethodTerminal`, and `TerminalRecord.authID(for:)` takes the ACP `AuthMethodId`, so `AgentAuthView` has no conversion of the ACP method into a kit type any more. `AgentProcessLauncher` and `ProcessLauncher` stay (with `AgentProcessLauncherTests`), and the new `terminalAuthRunner` can use them. This task then changes only `AgentAuthView.swift`, `AgentLoginPrompt.swift` and `AgentThreadActions.swift`.'
  timestamp: 2026-10-07T07:11:09.837710+00:00
depends_on:
- 01M443QS68DG8EJ9NEKCCHG10S
- 01M443RA2PMKC5MXXBNH1116AB
- 01M4BHMJNEVT7DQ6KHVZTXQXVH
position_column: todo
position_ordinal: b480
title: 'Bind the sign-in views to the client auth state: required, failures and terminal sign-in'
---
## Start condition
The pin task ^ztxqxvh moves the pins; this task starts after it. The pin task only makes the kit compile with `AuthState.failed(AuthFailure)`. This task does the views.

## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

Context: task ^cchg10s added `Sources/AgentViewKit/Connections/AgentAuthView.swift`, `AgentLoginPrompt.swift`, `AgentConnectionBanner.swift` and `AgentInfoHeader.swift`. Read these files before you start. The kit must read the auth state from `ConnectionModel`. The kit must not find the auth state from the transcript, and must not keep its own failure path.

This task does the views. Task ^20j25qh does the host part: the demo runner, `capabilities.auth.terminal`, the new transport, the new `initialize` and the retry of the failed operation. Task ^h1116ab removes the ACP adapter first, so this task changes only what stays of `ACPThreadActions`.

- [ ] `AgentLoginPrompt` shows the sign-in card when `ConnectionModel.authState` is `.required(authMethods)`. Remove the kit check of the last transcript entry for an `ErrorEntry` with the code `-32000`.
- [ ] `AgentAuthView` shows each failure from `authState` `.failed(AuthFailure)`. The `operation` of the failure is `.login(AuthMethodId)`, `.logout` or `.terminalLogin(AuthMethodId)`. The `reason` of the failure is `.request(RequestError)` or `.terminal(exitStatus:message:)`. `login(_:)` throws `unsupported` for a terminal method id or an unknown id, and `loginWithTerminal` throws `unsupported` when the last `InitializeRequest` did not set `capabilities.auth.terminal`. The card shows the text of each of these failures. Remove the kit path that only writes to the log, and remove the `SessionModel.appendError` call for a failed logout and for a login on a closed connection.
- [ ] The Run button of a terminal method calls `ConnectionModel.loginWithTerminal(_:runner:)` with the runner in the new environment value `terminalAuthRunner`. The runner has `runTerminalAuth(arguments:environment:) async -> Int32?`. The value `nil` is a failure, and a cancel gives `nil`. When the environment has no runner, the Run button does not show. Remove `AgentThreadActions.runTerminalAuth(_:)`, its implementation, and the conversion of the ACP method into a kit type.
- [ ] `canLogin` false hides the Sign In rows of the agent methods. `canLogin` is true only when `authMethods` has a method of the type "agent". Sign Out shows when `canLogout` is true. ACP v2 tells that an agent with an `authMethods` list that is not empty MUST support `auth/logout`. ACP v2 alpha.7 gives no "stored login" data.
- [ ] When `authState` is `.reconnectRequired(methodId)`, the card shows the text "Reconnect to the agent to finish the sign-in" and a Reconnect button. The button calls the host closure in the new environment value `agentReconnect`. The host makes a new transport, calls `connect(over:)` and `initialize`, and then retries the failed operation (^20j25qh). When the environment has no closure, the card shows only the text. The view keeps no transport and no failed operation.

Size: 4 source files: `AgentAuthView.swift`, `AgentLoginPrompt.swift`, `Sources/AgentViewKit/Model/AgentThreadActions.swift`, and `ACPThreadActions.swift` (if ^h1116ab keeps it).

## Acceptance Criteria
- [ ] No kit code reads the transcript to find if sign-in is necessary.
- [ ] Each `AuthFailure` shows its text, also the `unsupported` failures.
- [ ] A terminal method runs through the runner. A runner result `nil` shows the terminal failure text.
- [ ] `canLogin` false shows no Sign In row. `canLogout` true shows Sign Out.
- [ ] `.reconnectRequired(methodId)` shows the Reconnect text, and the button calls the host closure.
- [ ] `AgentThreadActions` has no `runTerminalAuth`.

## Tests
- [ ] Hosted tests with the scripted agent in `Tests/AgentViewKitTests/Connections/ConnectionModelViewsHostedTests.swift` and `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift`:
  - an answer with the code `-32000` shows the sign-in card;
  - a login that the agent refuses shows its failure text;
  - a failed logout shows its failure text;
  - `login(_:)` with an unknown method id shows the `unsupported` failure text;
  - `authMethods` with only a terminal method (`canLogin` false) shows no Sign In row;
  - with no `terminalAuthRunner`, the Run button does not show;
  - a fake runner that returns `nil` shows the terminal failure text;
  - a fake runner that returns 0 gives `.reconnectRequired(methodId)`, the card shows the Reconnect text, and a press calls the fake `agentReconnect` closure one time.
- [ ] Command: `swift test --filter "ConnectionModelViewsHostedTests|AgentAuthViewHostedTests"`. Then `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.