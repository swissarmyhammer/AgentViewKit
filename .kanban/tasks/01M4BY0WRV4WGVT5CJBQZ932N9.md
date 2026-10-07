---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4c4jr1w35fr95nqrdcw48ff
  text: |-
    Research:
    - `AgentAuthView` calls `ConnectionModel.login(_:)` directly for an `agent` method. When the agent accepts, the model sets `authState = .authenticated(methodId)`. The kit gives the host no callback. Thus the demo tab must observe `authState` (SwiftUI `onChange`) and then tell `DemoAgent` to run the kept operation.
    - `ConnectionModel.disconnect()` closes each open session model and empties `openSessions`. `loginWithTerminal` has no `authState` precondition.
    - `DemoSupport` is `@MainActor` by default isolation. `ConnectionModel.initialize` is `@MainActor`, so `reconnect()` takes the kept operation in the same job as the `authState` change. An `onChange` retry that comes later finds no kept operation. Thus the operation runs one time only.
    - Plan: add `DemoAgent.retryFailedOperation()` (runs the kept operation when `authState` is `.authenticated`). `reconnect(onOpen:)` uses the kept operation, or else opens a new session (`session/new`) and gives it to `onOpen`. `ACPTabView` calls `retryFailedOperation()` when `authState` becomes `.authenticated`, and gives its select handler to `reconnect(onOpen:)`.
  timestamp: 2026-10-07T21:33:44.380307+00:00
- actor: claude-code
  id: 01m4c58g5ap8rbe9zwngbd81zj
  text: |-
    Implementation:
    - `DemoAgent.retryFailedOperation()` (new, public): when `authState` is `.authenticated`, it takes the kept operation, forgets it, and runs it through `perform(_:)`. A second call does nothing.
    - `DemoAgent.reconnect()` is now `reconnect(onOpen:)`. After the new `initialize` gives `.authenticated`, it runs the kept operation. When no operation is kept (for example after a prompt failed with `-32000`), it sends a new `session/new` and gives the session to `onOpen`. Decision: a new `session/new`, not a resume of the old session id, because it uses the same retry path and needs no resume capability.
    - Private helpers `makeOpenSessionOperation(onOpen:)` and `takeFailedOperation()` remove the copy of the `session/new` closure and of the take-and-clear code.
    - `ACPTabView`: `.task(id: agent?.connection.authState)` calls `authStateDidChange()`, which calls `retryFailedOperation()` when the state is `.authenticated`. The Reconnect closure gives `select(_:on:)` to `reconnect(onOpen:)`. `select(_:on:)` replaces the inline phase change.
    - No double run: `reconnect(onOpen:)` takes the kept operation in the same main-actor job in which `initialize` sets `.authenticated` (a return is not a suspension point). The task of the view runs later and finds no operation.
    - TDD: the two new tests failed first (stub API: sessions were empty, `session/new` count was 1), then passed.
  timestamp: 2026-10-07T21:45:37.194097+00:00
- actor: claude-code
  id: 01m4c58kpb9v0wza4w0b7h34mj
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/DemoSupport/DemoAgent.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift (3 new tests: anAgentLoginAfterAnAnswerWithCode32000RunsTheKeptNewSessionOneTime, aReconnectWithNoKeptOperationOpensASessionOnTheSecondTransport, aRetryBeforeASignInSendsNoRequest; existing tests moved to reconnect(onOpen:)). Gates: `swift test` 1316 tests in 128 suites + 85 tests in 12 suites + 1 test passed, only the mlx-swift missing-creator warning; `Scripts/check-readme.sh` passed; `Scripts/test-examples.sh AgentViewKitDemo` TEST SUCCEEDED (4 UI tests), no Swift warning in project files.
    - next: /review
  timestamp: 2026-10-07T21:45:40.811082+00:00
- actor: claude-code
  id: 01m4c5my3dg38wxgteeb9btbng
  text: |-
    ### test - green
    - evidence: swift test - 1316 tests in 128 suites passed, 0 failed, 0 skipped. Scripts/check-readme.sh - README gate passed (3 snippets). Scripts/test-examples.sh AgentViewKitDemo - 4 UI tests, 0 failures, example gate passed.
    - warnings: only the expected mlx-swift "missing creator for mutated node" and the Xcode "Metadata extraction skipped" notice.
    - next: review. No files changed. No commit made.

    step: test
    outcome: green
    evidence: swift test - 1316 tests, 128 suites, 0 failures; Scripts/check-readme.sh passed; Scripts/test-examples.sh AgentViewKitDemo - 4 tests, 0 failures
    task: ^qz932n9
  timestamp: 2026-10-07T21:52:24.685098+00:00
position_column: doing
position_ordinal: '80'
title: 'Demo: retry after an agent-method sign-in, and show a session after a reconnect from the thread'
---
## What
Task ^20j25qh added the terminal sign-in of the demo host: `DemoAgent.perform(_:)` keeps the operation that failed with `-32000`, and `DemoAgent.reconnect()` runs it one more time after a terminal sign-in. Two paths are not done:

1. The demo tab shows the sign-in card (`ACPTabView`, phase `signingIn`) when the first `session/new` fails with `-32000`. When the user signs in with an `agent` method (`ConnectionModel.login`), `authState` becomes `.authenticated`, but nothing opens the first session. The tab stays on the sign-in card.
2. When a prompt of the open session fails with `-32000`, the thread shows the sign-in card. After a terminal sign-in and Reconnect, `reconnect()` calls `disconnect()`, which closes the open session model. No operation is kept for the prompt, so the tab keeps the closed session.

Rule: the kit views bind to the client models and keep no retry logic. The fix is in the demo host (`Sources/DemoSupport/DemoAgent.swift`, `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift`).

- [x] After an `agent` login that sets `authState` to `.authenticated`, the demo runs the kept operation one more time.
- [x] After a reconnect from the running thread, the demo shows an open session of the new connection (for example a new `session/new`, or a resume of the old session id).

## Tests
- [x] `Tests/AgentViewKitTests/ACP/DemoAgentTests.swift`: an `agent` login after `-32000` runs the kept `session/new` one time.
- [x] A reconnect with no kept operation gives an open session on the second transport.
- [x] `swift test` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.