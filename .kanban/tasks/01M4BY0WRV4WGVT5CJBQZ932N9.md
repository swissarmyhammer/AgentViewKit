---
assignees:
- claude-code
position_column: todo
position_ordinal: ba80
title: 'Demo: retry after an agent-method sign-in, and show a session after a reconnect from the thread'
---
## What
Task ^20j25qh added the terminal sign-in of the demo host: `DemoAgent.perform(_:)` keeps the operation that failed with `-32000`, and `DemoAgent.reconnect()` runs it one more time after a terminal sign-in. Two paths are not done:

1. The demo tab shows the sign-in card (`ACPTabView`, phase `signingIn`) when the first `session/new` fails with `-32000`. When the user signs in with an `agent` method (`ConnectionModel.login`), `authState` becomes `.authenticated`, but nothing opens the first session. The tab stays on the sign-in card.
2. When a prompt of the open session fails with `-32000`, the thread shows the sign-in card. After a terminal sign-in and Reconnect, `reconnect()` calls `disconnect()`, which closes the open session model. No operation is kept for the prompt, so the tab keeps the closed session.

Rule: the kit views bind to the client models and keep no retry logic. The fix is in the demo host (`Sources/DemoSupport/DemoAgent.swift`, `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift`).

- [ ] After an `agent` login that sets `authState` to `.authenticated`, the demo runs the kept operation one more time.
- [ ] After a reconnect from the running thread, the demo shows an open session of the new connection (for example a new `session/new`, or a resume of the old session id).

## Tests
- [ ] `Tests/AgentViewKitTests/ACP/DemoAgentTests.swift`: an `agent` login after `-32000` runs the kept `session/new` one time.
- [ ] A reconnect with no kept operation gives an open session on the second transport.
- [ ] `swift test` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.