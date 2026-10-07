---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4btmr5wc3je33mgbn6s7vgt
  text: 'Note from ^83200vg: the first subtask of this card is done there, in a different form. `InitializeRequest.makeAgentViewKitRequest(info:terminalAuthRunner:)` takes the runner, not `terminalAuth: Bool`, and sets `capabilities.auth.terminal = {}` only when the runner is not `nil`. The test is `KitInitializeRequestTests.aHostWithATerminalAuthRunnerAdvertisesTerminalAuth`. The kit views read the runner from the `terminalAuthRunner` environment value and the Reconnect closure from the `agentReconnect` environment value (`AgentReconnect = @MainActor () async -> Void`). `AgentViewKitTestSupport` has `FakeTerminalAuthRunner(exitStatus:)` with `runs`, and `ScriptedSession.open(terminalAuthRunner:)`. The in-memory demo agent lists an `agent` auth method, so the demo thread shows the sign-in card after `initialize`.'
  timestamp: 2026-10-07T18:40:04.284794+00:00
- actor: claude-code
  id: 01m4bwzsn7hamhsbmxf9xt11eq
  text: |-
    Research:
    - The first subtask is done in ^83200vg in a different form. `InitializeRequest.makeAgentViewKitRequest(info:terminalAuthRunner:)` takes the runner, not `terminalAuth: Bool`. This task uses that parameter and adds no `terminalAuth` parameter. `KitInitializeRequestTests` already has the two tests (`aHostWithATerminalAuthRunnerAdvertisesTerminalAuth`, `theInitializeFrameOfTheTestHelperAdvertisesOnlyTheKitCapabilities`).
    - `ACPDemoSession.swift` does not exist now. The demo connection file is `Sources/DemoSupport/DemoAgent.swift`, and the demo test file is `Tests/AgentViewKitTests/ACP/DemoAgentTests.swift`. This task uses these two files.
    - Client facts (pin 36f3249): `connect(over:)` sets `authState` to `.unknown` but keeps the method of a successful terminal login. The next `initialize` gives `.authenticated(methodId)` when the agent still lists the method. A `-32000` answer is a `RequestError` with `code == .authenticationRequired`. `connect(over:)` does not close the last connection, so the demo calls `disconnect()` first; otherwise an `AgentProcess` stays alive.
    - The in-process agent has no transport factory (`InProcessAgent.makeConnection` makes the model). Thus only the process agent gets a runner, `auth.terminal` and a Reconnect closure, as the card says.
    - No interactive terminal exists in the repo. The demo runner opens a `.command` script in Terminal.app with `/usr/bin/open`, and reads the exit status from a status file that the script writes. The demo app has no App Sandbox.
  timestamp: 2026-10-07T19:21:03.399511+00:00
- actor: claude-code
  id: 01m4by15m5m2x48zt6jry364jw
  text: |-
    Implementation:
    - Plan change: this task uses the `terminalAuthRunner:` parameter of `makeAgentViewKitRequest` from ^83200vg. It adds no `terminalAuth: Bool` parameter. `KitInitializeRequest.swift` did not change.
    - New `Sources/DemoSupport/TerminalAppAuthRunner.swift`: writes a `/bin/sh` `.command` script in a new temporary directory, opens it with `/usr/bin/open -a Terminal`, and reads the exit status from a status file (written through a rename). Each word is in single quotes; an environment name that the shell cannot read gives `nil` and opens no script. A hang-up, an interrupt or a terminate signal writes `stopped`, which gives `nil`. A start failure gives `nil` and a log line. The opener is a seam (`ScriptOpener`), so the tests run the script with `/bin/sh` and open no window.
    - `Sources/DemoSupport/DemoAgent.swift`: now a class. It has a transport factory, `terminalAuthRunner`, `initializeRequest`, `canReconnect`, `perform(_:)` (keeps the operation that failed with `-32000`), `reconnect()` (only in `.reconnectRequired`: `disconnect()`, new transport, `connect(over:)`, the same `initialize`; then the kept operation one time only when `authState` is `.authenticated`), `isAuthenticationRequired(_:)` and `makeInitializeRequest(terminalAuthRunner:)`. The process agent gets a `TerminalAppAuthRunner` and a factory; the in-memory agent gets neither.
    - `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift`: gives `.terminalAuthRunner` and `.agentReconnect` to the kit views. A `-32000` on the first `session/new` shows `AgentAuthView` (new phase `signingIn`); the Reconnect closure calls `DemoAgent.reconnect()`.
    - The kit views did not change. They keep no transport, no failed operation and no retry logic.
    - Discovery: `disconnect()` over a raw `InMemoryTransport` ends in the tests (no hang), so the reconnect tests need no wrapper transport.
    - New work: ^qz932n9 (no retry after an `agent` login in the `signingIn` phase; no session after a reconnect from the running thread).
  timestamp: 2026-10-07T19:39:16.997870+00:00
- actor: claude-code
  id: 01m4by18ygh5n04sppg92h101f
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/DemoSupport/TerminalAppAuthRunner.swift (new), Sources/DemoSupport/DemoAgent.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift (new), Tests/AgentViewKitTests/ACP/DemoAgentTests.swift, Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift. RED: build failed on the missing symbols. GREEN: `swift test --filter "TerminalAppAuthRunnerTests|DemoAgentTerminalSignInTests|DemoAgentTests|KitInitializeRequestTests"` 22 tests in 5 suites pass. `swift test`: 1305 tests in 127 suites, 83 in 12, 1 in 1 pass, no warnings. `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo`: BUILD SUCCEEDED, 4 tests, 0 failures.
    - next: /review
  timestamp: 2026-10-07T19:39:20.400615+00:00
- actor: claude-code
  id: 01m4bydkvsrfh3nghfv66aw6a2
  text: |-
    ### test - green
    - evidence: swift test - 1305 tests in 127 suites passed, 0 failed, 0 skipped; Scripts/check-readme.sh - passed (3 snippets, compile); Scripts/test-examples.sh AgentViewKitDemo - 4 UI tests, 0 failures. Only the expected mlx-swift warning "missing creator for mutated node" appeared. No time-limit failure, so no uptime run.
    - next: review
  timestamp: 2026-10-07T19:46:04.793593+00:00
- actor: claude-code
  id: 01m4byvxserqhb561jqzbmvrce
  text: |-
    ### review — findings
    - scope: review sha HEAD~1..HEAD (commit 59f9d4b)
    - engine counts: 5 findings, 5 confirmed, 2 refuted. A check against the code removed 1 more finding: `Sources/DemoSupport/TerminalAppAuthRunner.swift:60` (code-hygiene/magic-numbers-swift). That line is the named constant `statusPollInterval = Duration.milliseconds(200)`. It is not a magic number.
    - evidence: 4 findings — Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:148, Sources/DemoSupport/DemoAgent.swift:161, Sources/DemoSupport/DemoAgent.swift:224, Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift:69
    - note: The New Session finding (ACPTabView.swift:148) is not one of the two paths in ^qz932n9. Those paths are the agent-method login and the reconnect after a prompt failure. In `openNewSession`, `agent.openSession()` is not sent through `perform`. Thus a `-32000` answer from New Session keeps no operation to retry.
    - next: implement the 4 open items in the 2026-10-07 14:46 Review Findings section. The task stays in review.
  timestamp: 2026-10-07T19:53:53.710684+00:00
- actor: claude-code
  id: 01m4byw9r8n8adtbmdzj4xep9b
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 6 files (TerminalAppAuthRunner, DemoAgent, ACPTabView, tests)
    - test: green — swift test 1305 passed, check-readme passed, test-examples 4 passed
    - commit: 59f9d4b
    - review: findings — Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:148, Sources/DemoSupport/DemoAgent.swift:161, Sources/DemoSupport/DemoAgent.swift:224, Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift:69
  timestamp: 2026-10-07T19:54:05.960995+00:00
- actor: claude-code
  id: 01m4bz3f22my8k9zgw5ax29k7r
  text: |-
    Pick-up for the 4 items of Review Findings (2026-10-07 14:46). Plan:
    - New Session item: the view cannot be tested for a terminal sign-in (the UI tests use the in-memory agent, which has no terminal method). Thus the open-and-retry step moves into DemoAgent: a public `openSession(onOpen:)` sends `session/new` through `perform`, and gives the session to `onOpen` (also on the retry after a reconnect). The plain `openSession()` and `perform(_:)` become private, so that no caller can open a session without `perform`. Both tab paths (first session and New Session) call `openSession(onOpen:)`. A `-32000` from New Session shows the sign-in card through `show(_:of:)`; another New Session error keeps the session and shows `newSessionFailure`. New test: the first session opens, then New Session gets `-32000`, then a terminal sign-in and a reconnect open the New Session session (`ScriptedWireAgent.failingMethods` is set after the first session).
    - `makeInProcess` and `makeConnected(makeTransport:)`: one private static helper makes the agent and starts it. `reconnect()` and the helper share one private `connectAndInitialize()`: it connects over a new transport of the factory when the agent has a factory, then sends `initialize`.
    - Test `runInShell` and `openInTerminal`: one internal static `TerminalAppAuthRunner.run(program:arguments:)` that gives the exit status, or `nil` when the program does not start. It gives the status and not a Bool, because `runInShell` must not depend on the exit status of the script (the test of a stopped script must read the `stopped` text, not a failed open).
  timestamp: 2026-10-07T19:58:00.770065+00:00
- actor: claude-code
  id: 01m4bzq86ckxettjawsyq8b60m
  text: |-
    Implementation of the 4 findings:
    - New Session item: `DemoAgent.openSession(onOpen:)` is now the only way to open a session. It sends `session/new` through the private `perform(_:)`, so a `-32000` keeps the request for `reconnect()`. The old public `openSession()` and the public `perform(_:)` are gone (now private), so no caller can bypass the retry. In `ACPTabView`, the first session and New Session both call one private `openSession(on:failure:)`. New Session sends a `-32000` to `show(_:of:)` (sign-in card) and keeps `newSessionFailure` for each other error. New test `DemoAgentTerminalSignInTests.aNewSessionThatFailsWithCode32000OpensItsSessionAfterASignInAndAReconnect`: the first session opens, then `ScriptedWireAgent.failingMethods` makes the next `session/new` give `-32000`; sign-in and reconnect open the session (ids `[first-session, signed-in-session]`).
    - `makeInProcess` and `makeConnected(makeTransport:)` now call one private static `makeStarted(connection:workingDirectory:terminalAuthRunner:makeTransport:)`; they differ only in the arguments.
    - `reconnect()` and `makeStarted` share one private `connectAndInitialize()`: it connects over a new transport of the factory when the agent has a factory (the in-memory model is connected by `InProcessAgent`), then sends `initialize` and stops the agent on failure. The old `initialize()` helper is merged into it.
    - `TerminalAppAuthRunner.run(program:arguments:) -> Int32?` (internal static) holds the one `Process` start and `terminationHandler` continuation. `openInTerminal` compares its result with `successStatus`; the test `runInShell` checks only that the shell started. It returns the status, not a Bool, because `runInShell` must not read the exit status of the script: `aRunThatTheUserStopsGivesNoExitStatus` must get `nil` from the `stopped` text, not from a failed open. Two new tests: `runGivesTheExitStatusOfTheProgram`, `runOfAProgramThatDoesNotStartGivesNoExitStatus`.
    - RED: the filtered build failed on the missing `TerminalAppAuthRunner.run` and `DemoAgent.openSession(onOpen:)`. GREEN: 25 tests in 5 suites pass.
    - Not touched: the two paths of ^qz932n9.
  timestamp: 2026-10-07T20:08:49.100359+00:00
- actor: claude-code
  id: 01m4bzqacpnd0r23c23rag4b5r
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/DemoSupport/DemoAgent.swift, Sources/DemoSupport/TerminalAppAuthRunner.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift, Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift. `swift test --filter "KitInitializeRequestTests|DemoAgentTests|DemoAgentTerminalSignInTests|TerminalAppAuthRunnerTests"`: 25 tests in 5 suites pass. `swift test`: 1308 tests in 127 suites, 83 in 12, 1 in 1 pass, 0 failures, no compiler warnings (only the expected mlx-swift "missing creator for mutated node"). `Scripts/check-readme.sh`: passed. `Scripts/test-examples.sh AgentViewKitDemo`: BUILD SUCCEEDED, 4 tests, 0 failures. No time-limit failure. All 4 items of Review Findings (2026-10-07 14:46) are checked.
    - next: /review
  timestamp: 2026-10-07T20:08:51.350147+00:00
- actor: claude-code
  id: 01m4c038zxapxyvpecgs66t1zx
  text: |-
    ### test — green
    - evidence: `swift test` — 1308 tests in 127 suites passed, 0 failed, 0 skipped. `Scripts/check-readme.sh` — README gate passed (3 snippets). `Scripts/test-examples.sh AgentViewKitDemo` — 4 UI tests, 0 failures, TEST SUCCEEDED, example gate passed.
    - warnings: only the expected mlx-swift "missing creator for mutated node" line and the Xcode "Metadata extraction skipped" notice.
    - code change: none. No time-limit failure, so no load check was needed.
    - next: review.
  timestamp: 2026-10-07T20:15:23.133938+00:00
depends_on:
- 01M49GHXXC7CY7R1PRZ83200VG
- 01M49HGF5KFW6185XJATDG13NJ
- 01M443S0EDEB23N7RPAR39TGZ5
- 01M4BHMJNEVT7DQ6KHVZTXQXVH
position_column: doing
position_ordinal: '80'
title: 'Reconnect and retry after a terminal sign-in in the demo host: runner, auth.terminal, new transport, initialize, retry'
---
## Start condition
The pin task ^ztxqxvh moves the pins; this task starts after it.

## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

Task ^83200vg binds the sign-in views to the client auth state. It shows the Run button only when the host gives a `terminalAuthRunner`, and it shows the Reconnect button of `.reconnectRequired(methodId)`. This task does the host part. Only a host can make a transport and run a terminal, so this work is in the demo host, not in the kit views.

ACP v2 terminal sign-in: after the terminal process ends, the client MUST reconnect and send `initialize` again. The client model sets `.reconnectRequired(methodId)`. When the host calls `connect(over:)` with a NEW transport and then `initialize`, the model sets `.authenticated(methodId)`. The model does not retry the operation that failed with `-32000`. The host must retry it.

Note: ^83200vg did the first subtask in a different form. `InitializeRequest.makeAgentViewKitRequest(info:terminalAuthRunner:)` takes the runner, not `terminalAuth: Bool`, and sets `capabilities.auth.terminal = {}` only when the runner is not `nil`. This task uses that parameter. `ACPDemoSession.swift` does not exist now: the demo connection file is `Sources/DemoSupport/DemoAgent.swift`, and the demo test file is `Tests/AgentViewKitTests/ACP/DemoAgentTests.swift`.

Subtasks:
- [x] In `Sources/AgentViewKit/ACP/KitInitializeRequest.swift` (from ^tdg13nj), the request sets `capabilities.auth.terminal = {}` only when the host gives a terminal auth runner (done in ^83200vg with the `terminalAuthRunner:` parameter). The demo gives a runner only for an `AgentProcess` agent. The in-process helper (^96pte46) gives no runner.
- [x] Add a demo `TerminalAuthRunner` (new file in `Sources/DemoSupport/`): `TerminalAppAuthRunner`. It runs the agent command with the `arguments` and the `environment` of the method in a Terminal.app window. It returns the exit status. It returns `nil` when the process cannot start or when the user cancels. The demo gives the runner in the `terminalAuthRunner` environment value only when it starts the agent as an `AgentProcess`, and then sends `auth.terminal`.
- [x] The demo gives the Reconnect closure of ^83200vg. The closure makes a new transport, calls `ConnectionModel.connect(over:)` and then `initialize` with the same `InitializeRequest`. Put a transport factory on the demo connection so that a test can give scripted transports.
- [x] The demo keeps the operation that failed with `-32000` (for example `session/new`) as an async closure. After the new `initialize`, when `authState` is `.authenticated(methodId)`, the demo runs the operation one more time. The demo does not retry in other states.

Size: 3 to 4 source files: `KitInitializeRequest.swift`, the new demo runner file, and the demo connection file `Sources/DemoSupport/DemoAgent.swift`, plus the demo tab `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift`.

## Acceptance Criteria
- [x] The `initialize` frame has `capabilities.auth.terminal` only when the host gives a runner.
- [x] After a runner exit status 0 and a press on Reconnect, the second transport gets `initialize`, then the retried operation. `authState` is `.authenticated(methodId)`.
- [x] A runner result `nil` shows the terminal failure text and starts no reconnect.
- [x] The kit views keep no transport, no failed operation and no retry logic.

## Tests
- [x] `Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift`: a runner sends `params.capabilities.auth.terminal == {}`. No runner sends no `params.capabilities.auth`.
- [x] The demo test file `Tests/AgentViewKitTests/ACP/DemoAgentTests.swift` (`DemoAgentTerminalSignInTests`), with two `ScriptedWireAgent` transports and a fake runner:
  - the first agent answers `session/new` with `-32000`; the fake runner returns 0; the model sets `.reconnectRequired(methodId)`;
  - Reconnect sends `initialize` with `auth.terminal` on the second transport, then `session/new` one more time; `authState` is `.authenticated(methodId)`;
  - a fake runner that returns `nil` gives the terminal failure and no second `initialize`.
- [x] Command: `swift test --filter "KitInitializeRequestTests|DemoAgentTests|DemoAgentTerminalSignInTests|TerminalAppAuthRunnerTests"`. Then `swift test` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-10-07 14:46)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 6 file(s) reviewed, 6 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

- [x] `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:148` `completeness/invariant-propagation` — The first session is opened through agent.perform, so a -32000 answer keeps the operation for the retry after a terminal sign-in. The New Session path in openNewSession (ACPTabView.swift line 189) calls agent.openSession() directly and does not use perform. A -32000 answer from New Session is therefore not kept, and reconnect() has no operation to retry. The sign-in card is also never shown for that path. The user only sees newSessionFailure, and cannot reach the Reconnect flow from New Session. Route openNewSession through agent.perform, and on failure call show(error, of: agent) instead of setting newSessionFailure only for the -32000 case. Add a test where a New Session -32000 is followed by a terminal sign-in and reconnect, and assert that the retried session/new opens the session.
- [x] `Sources/DemoSupport/DemoAgent.swift:161` `duplication/duplication` — makeInProcess repeats the tail of makeConnected(makeTransport:): it builds a DemoAgent from the connection, the working directory and the runner or factory, then awaits agent.initialize() and returns the agent. Only the connection construction and the nil or non-nil arguments differ. The two copies can drift apart, for example when a step is added to one and not the other. Extract a private static helper that takes the connected ConnectionModel, the working directory, the runner and the factory, and builds the agent and runs initialize. Both makeInProcess and makeConnected(makeTransport:) then call it and differ only in the arguments they pass.
- [x] `Sources/DemoSupport/DemoAgent.swift:224` `duplication/duplication` — reconnect() repeats the connect-then-initialize sequence of makeConnected(makeTransport:): connect over a new transport from the factory, then send the same initialize request. Any change to how a connection starts, for example a new step before initialize, would have to be made in both places. Extract a private async helper, for example `connectAndInitialize(over factory: TransportFactory)`, that calls connect over a new transport and then initialize. Call it from makeConnected(makeTransport:) and from reconnect().
- [x] `Tests/AgentViewKitTests/ACP/TerminalAppAuthRunnerTests.swift:69` `reuse/reuse` — runInShell rebuilds the same Process launch and terminationHandler continuation that openInTerminal already has in TerminalAppAuthRunner.swift. The only difference is the executable and the return value, so the process code is duplicated. Extract one helper that runs an executable with arguments and returns whether it started and exited with status zero. Have openInTerminal and runInShell both call it, passing /usr/bin/open or /bin/sh as the executable.
