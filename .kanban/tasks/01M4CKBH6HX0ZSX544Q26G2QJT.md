---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4drh6vc7q5qvvzzw5jzcxt4
  text: |-
    Research:
    - Only three places in Tests/ write the "method":"session/update" envelope as text. These are the three places that the card names.
    - `ScriptedWireAgent.makeSessionUpdateFrame(params: JSONValue) -> String` does not throw. `JSONValue(json:)` throws.
    - Each frame helper has one caller. Each caller is in a `ScriptedWireAgent.FollowUp` closure, `(JSONValue, Int) -> [String]`. This closure does not throw.
    - Plan: (1) Session state banners: make the chunk update as a typed `JSONValue`, with no parse. Add `import DemoSupport`. (2) Composer: make `markerUpdate` a typed `JSONValue`. Copy the `sessionId` value from the request, as `ScriptedWireAgent.echoFrame` does. (3) Config: the options are JSON text that `newSessionResult` and `sendUpdate` also use. Thus `configUpdateFrame` parses the update and throws. The test makes the frame before it sets the closure.
    - TDD: this change refactors test helpers only. There is no production code change. The tests that use the helpers are the guard: they must stay green.
  timestamp: 2026-10-08T12:41:39.948947+00:00
- actor: claude-code
  id: 01m4drrwa44ey4b15kjympn3tg
  text: |-
    Implementation landed:
    - ConfigOptionsSessionModelHostedTests: `configUpdateFrame(options:)` now throws. It parses the update text with `JSONValue(json:)` and makes the frame with `ScriptedWireAgent.makeSessionUpdateFrame(params:)`. The test `aChangeSendsSetConfigOptionAndTheViewShowsTheValueThatTheModelReports` makes the frame before it sets the `FollowUp` closure, because that closure cannot throw.
    - ComposerSessionModelHostedTests: `markerUpdate` is now a typed `JSONValue`. `updateFrame(carrying:for:)` takes a `JSONValue` update. It copies the `sessionId` value from the request (`?? .null`, as `ScriptedWireAgent.echoFrame` does) and makes the frame with the helper.
    - SessionStateBannersHostedTests: `chunkFrame(index:)` makes a typed `JSONValue` update and the frame with the helper. The file now imports DemoSupport.
    - `rg '"method"\s*:\s*"session/update"' Tests` finds no match.
    - The full `swift test` run prints one warning: `missing creator for mutated node` on `mlx-swift_Cmlx.bundle`. The card "Package skeleton" (01M21A8RWGWE533JR6GQ4DNN06) records this warning as a dependency warning. It does not come from this repository or from this change.
  timestamp: 2026-10-08T12:45:51.300653+00:00
- actor: claude-code
  id: 01m4drs6v0hen8aayx3a7fgdek
  text: |-
    ### implement — changed
    - evidence: 3 files — Tests/AgentViewKitTests/Config/ConfigOptionsSessionModelHostedTests.swift, Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift, Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift. `swift test`: 1025 tests in 110 suites passed, 0 failures. One dependency warning from the build system (mlx-swift_Cmlx.bundle), which is not from this change.
    - next: /review
  timestamp: 2026-10-08T12:46:02.080973+00:00
position_column: doing
position_ordinal: '80'
title: Use ScriptedWireAgent.makeSessionUpdateFrame in the older hosted tests
---
## What
Three older hosted test files write the `session/update` JSON-RPC envelope as text. The helper `ScriptedWireAgent.makeSessionUpdateFrame(params:)` (DemoSupport) now makes this frame for the scripted agents and for `ScriptedSession.sendUpdate`. Found during ^71k836q. The review rule did not let that task change older tests.

- [x] `Tests/AgentViewKitTests/Config/ConfigOptionsSessionModelHostedTests.swift` `configUpdateFrame(options:)`: make the frame with the helper.
- [x] `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift` `updateFrame(carrying:for:)`: make the frame with the helper.
- [x] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`: make the early chunk frame with the helper.

## Acceptance Criteria
- [x] No file in `Tests/` writes `"method":"session/update"` as text.
- [x] `swift test` passes.