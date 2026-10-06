---
assignees:
- claude-code
depends_on:
- 01M49GHXXC7CY7R1PRZ83200VG
- 01M49HGF5KFW6185XJATDG13NJ
- 01M443S0EDEB23N7RPAR39TGZ5
position_column: todo
position_ordinal: b680
title: 'Reconnect and retry after a terminal sign-in in the demo host: runner, auth.terminal, new transport, initialize, retry'
---
## Start condition
Do not start this task before the kit pins a FoundationModelsACPClient commit that has the client task 9caa4y2. Before that commit, the client auth state has no `.reconnectRequired(methodId)` case, and the runner does not return `Int32?`.

## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

Task ^83200vg binds the sign-in views to the client auth state. It shows the Run button only when the host gives a `terminalAuthRunner`, and it shows the Reconnect button of `.reconnectRequired(methodId)`. This task does the host part. Only a host can make a transport and run a terminal, so this work is in the demo host, not in the kit views.

ACP v2 terminal sign-in: after the terminal process ends, the client MUST reconnect and send `initialize` again. The client model sets `.reconnectRequired(methodId)`. When the host calls `connect(over:)` with a NEW transport and then `initialize`, the model sets `.authenticated(methodId)`. The model does not retry the operation that failed with `-32000`. The host must retry it.

Subtasks:
- [ ] In `Sources/AgentViewKit/ACP/KitInitializeRequest.swift` (from ^tdg13nj), add the input `terminalAuth: Bool` to `InitializeRequest.agentViewKit(info:)`. Set `capabilities.auth.terminal = {}` only when `terminalAuth` is true. A host sets it to true only when it can run the agent command in an interactive terminal. The in-process helper (^96pte46) sets it to false.
- [ ] Add a demo `TerminalAuthRunner` (new file in `Sources/DemoSupport/`). It runs the agent command with the `arguments` and the `environment` of the method in an interactive terminal. It returns the exit status. It returns `nil` when the process cannot start or when the user cancels. The demo gives the runner in the `terminalAuthRunner` environment value only when it starts the agent as an `AgentProcess`, and then sends `terminalAuth: true`.
- [ ] The demo gives the Reconnect closure of ^83200vg. The closure makes a new transport, calls `ConnectionModel.connect(over:)` and then `initialize` with the same `InitializeRequest`. Put a transport factory on the demo connection so that a test can give scripted transports.
- [ ] The demo keeps the operation that failed with `-32000` (for example `session/new`) as an async closure. After the new `initialize`, when `authState` is `.authenticated(methodId)`, the demo runs the operation one more time. The demo does not retry in other states.

Size: 3 to 4 source files: `KitInitializeRequest.swift`, the new demo runner file, and the demo connection file that ^r39tgz5 leaves (now `Sources/DemoSupport/ACPDemoSession.swift`).

## Acceptance Criteria
- [ ] The `initialize` frame has `capabilities.auth.terminal` only when the host gives a runner.
- [ ] After a runner exit status 0 and a press on Reconnect, the second transport gets `initialize`, then the retried operation. `authState` is `.authenticated(methodId)`.
- [ ] A runner result `nil` shows the terminal failure text and starts no reconnect.
- [ ] The kit views keep no transport, no failed operation and no retry logic.

## Tests
- [ ] `Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift`: `terminalAuth: true` sends `params.capabilities.auth.terminal == {}`. `terminalAuth: false` sends no `params.capabilities.auth`.
- [ ] The demo test file that ^r39tgz5 leaves (now `Tests/AgentViewKitTests/ACP/ACPDemoSessionTests.swift`), with two `ScriptedWireAgent` transports and a fake runner:
  - the first agent answers `session/new` with `-32000`; the fake runner returns 0; the model sets `.reconnectRequired(methodId)`;
  - Reconnect sends `initialize` with `auth.terminal` on the second transport, then `session/new` one more time; `authState` is `.authenticated(methodId)`;
  - a fake runner that returns `nil` gives the terminal failure and no second `initialize`.
- [ ] Command: `swift test --filter "KitInitializeRequestTests|ACPDemoSessionTests"`. Then `swift test` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream