---
assignees:
- claude-code
depends_on:
- 01M443QS68DG8EJ9NEKCCHG10S
position_column: todo
position_ordinal: b480
title: 'Bind the sign-in views to the client auth state: required, failures and terminal sign-in'
---
## Start condition
Do not start this task before the kit pins a FoundationModelsACPClient commit that has the client tasks 73c1nkk, fxa80af, cgznw8q and 9caa4y2. Before that commit, the client auth state has no `.required` case, no `AuthFailure` value and no `loginWithTerminal(_:runner:)` method.

## What
Context: task ^cchg10s added `Sources/AgentViewKit/Connections/AgentAuthView.swift`, `AgentLoginPrompt.swift`, `AgentConnectionBanner.swift` and `AgentInfoHeader.swift`. Read these files before you start. The kit must read the auth state from `ConnectionModel` and must not find the auth state from the transcript or keep its own failure path.

- [ ] `AgentLoginPrompt` and `AgentThreadView` (`Sources/AgentViewKit/Thread/AgentThreadView.swift`) show the sign-in card when `ConnectionModel.authState` is `.required(authMethods)`. Remove the kit check of the last transcript entry for an `ErrorEntry` with the code `-32000`.
- [ ] `AgentAuthView` shows each failure from `authState` `.failed(AuthFailure)`. The `operation` of the failure is `.login(AuthMethodId)`, `.logout` or `.terminalLogin(AuthMethodId)`. The `reason` of the failure is `.request(RequestError)` or `.terminal(exitStatus:message:)`. Remove the kit path that only writes to the log, and remove the `SessionModel.appendError` call for a failed logout and for a login on a closed connection.
- [ ] The Run button of a terminal method calls `ConnectionModel.loginWithTerminal(_:runner:)` with a kit `TerminalAuthRunner` (`runTerminalAuth(arguments:environment:) async throws -> Int32`). The kit gives the runner, because the host owns the interactive terminal. Remove `AgentThreadActions.runTerminalAuth(_:)` and the conversion of the ACP method into a kit type.
- [ ] The host sets `ClientCapabilities.auth.terminal` in its `InitializeRequest` when it gives a runner. Do this in the demo (`Examples/AgentViewKitDemo`) and in the in-process helper.
- [ ] Sign Out stays visible when `canLogout` is true. ACP v2 alpha.7 gives no "stored login" data. The client session confirmed this.

Size: 2 to 4 source files.

## Acceptance Criteria
- [ ] No kit code reads the transcript to find if sign-in is necessary.
- [ ] Each `AuthFailure` shows its text.
- [ ] A terminal method runs through the runner. Exit status 0 shows the signed-in state.
- [ ] `AgentThreadActions` has no `runTerminalAuth`.

## Tests
- [ ] Hosted tests with the scripted agent in `Tests/AgentViewKitTests/Connections/ConnectionModelViewsHostedTests.swift` and `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift`:
  - an answer with the code `-32000` shows the sign-in card;
  - a login that the agent refuses shows its failure text;
  - a failed logout shows its failure text;
  - a fake runner with exit status 0 shows the signed-in state;
  - a fake runner with exit status 1 shows the terminal failure text.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream