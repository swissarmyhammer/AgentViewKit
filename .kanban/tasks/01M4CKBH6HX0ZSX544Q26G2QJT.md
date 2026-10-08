---
assignees:
- claude-code
position_column: todo
position_ordinal: ba80
title: Use ScriptedWireAgent.makeSessionUpdateFrame in the older hosted tests
---
## What
Three older hosted test files write the `session/update` JSON-RPC envelope as text. The helper `ScriptedWireAgent.makeSessionUpdateFrame(params:)` (DemoSupport) now makes this frame for the scripted agents and for `ScriptedSession.sendUpdate`. Found during ^71k836q. The review rule did not let that task change older tests.

- [ ] `Tests/AgentViewKitTests/Config/ConfigOptionsSessionModelHostedTests.swift` `configUpdateFrame(options:)`: make the frame with the helper.
- [ ] `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift` `updateFrame(carrying:for:)`: make the frame with the helper.
- [ ] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`: make the early chunk frame with the helper.

## Acceptance Criteria
- [ ] No file in `Tests/` writes `"method":"session/update"` as text.
- [ ] `swift test` passes.