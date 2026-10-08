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
- actor: claude-code
  id: 01m4ds34eqnneqw4re2wryn5q0
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (53593c2): 4 findings (4 confirmed, 1 refuted). Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift:490, Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift:74 (two findings), Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift:79
    - next: Add one shared sessionUpdateFrame helper next to requestFrame in ScriptedSession.swift and one shared agent message chunk helper. Use them in the three hosted test files. Then run the review again.
  timestamp: 2026-10-08T12:51:27.319704+00:00
- actor: claude-code
  id: 01m4ds3f44vtrfx1cd142s3a2n
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 3 files (ConfigOptionsSessionModelHostedTests.swift, ComposerSessionModelHostedTests.swift, SessionStateBannersHostedTests.swift)
    - test: green — swift test, 1025 tests in 110 suites passed
    - commit: 53593c2
    - review: findings — ComposerSessionModelHostedTests.swift:490, SessionStateBannersHostedTests.swift:74 (x2), SessionStateBannersHostedTests.swift:79
  timestamp: 2026-10-08T12:51:38.244328+00:00
- actor: claude-code
  id: 01m4dsmptnj8cvvh7eb4de6bt9
  text: |-
    Review findings fixed:
    - `ScriptedSession.sessionUpdateFrame(sessionId:update:)` is new. It is next to `requestFrame` in `Sources/AgentViewKitTestSupport/ScriptedSession.swift`. The `sessionId` parameter is a `JSONValue` with the default `.string(sessionID)`. Thus the composer follow-up can give the `sessionId` value of its request (`?? .null`, as before). The private `send(updateValue:)` of `ScriptedSession` also uses the helper, so the `sessionId` wrapping has one definition.
    - `ScriptedSession.agentMessageChunkUpdate(messageID:text:) -> JSONValue` is new in the same file. `markerUpdate` (composer tests) and `chunkFrame(index:)` (state banner tests) use it. The two copied object literals are deleted.
    - `configUpdateFrame(options:)`, `updateFrame(carrying:for:)` and `chunkFrame(index:)` call `sessionUpdateFrame`. No changed test file calls `makeSessionUpdateFrame` directly now.
    - `SessionStateBannersHostedTests` does not use DemoSupport now, so its `import DemoSupport` is removed.
    - Three new tests in `ScriptedSessionTests`: the frame holds the method, the `sessionId` and the update; the default `sessionId` is `ScriptedSession.sessionID`; the chunk update decodes as `SessionUpdate` and is equal to `BackgroundRunScript.makeChunkUpdate(messageID:text:)`. RED: the build failed with "type 'ScriptedSession' has no member". GREEN: 6 tests in 1 suite passed.
    - `ScriptedSession.swift` is also compiled by the Benchmarks package through a link. `swift build --package-path Benchmarks` completes with exit 0.
    - Older test files (for example `SlashCommandSessionModelTests`, `ContextUsageSessionModelHostedTests`) have the same chunk shape as JSON text. The review rule does not let this card change older tests, so they are not changed.
  timestamp: 2026-10-08T13:01:03.189471+00:00
- actor: claude-code
  id: 01m4dsmsbh9m5h0qgthe4j1p7m
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKitTestSupport/ScriptedSession.swift, Tests/AgentViewKitTests/TestSupport/ScriptedSessionTests.swift, Tests/AgentViewKitTests/Config/ConfigOptionsSessionModelHostedTests.swift, Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift, Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift. `swift test`: 1028 tests in 110 suites passed, 0 failures. One dependency warning from the build system (mlx-swift_Cmlx.bundle), which is not from this change. `swift build --package-path Benchmarks`: exit 0. 4 of 4 review findings checked.
    - next: /review
  timestamp: 2026-10-08T13:01:05.777262+00:00
- actor: claude-code
  id: 01m4dt194tdyexwm43dqgeb8s7
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (df38a91): 1 finding, 1 confirmed, 1 refuted. Open: Sources/AgentViewKitTestSupport/ScriptedSession.swift:254 (duplication/duplication).
    - next: Make agentMessageChunkUpdate return JSONValue(encoding: BackgroundRunScript.makeChunkUpdate(messageID:text:)). Then run the tests, commit, and review again.
  timestamp: 2026-10-08T13:07:55.162633+00:00
- actor: claude-code
  id: 01m4dt1jzgnaexhp0gr9459kv1
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — 5 files (ScriptedSession.swift, ScriptedSessionTests.swift, three hosted test files)
    - test: green — swift test, 1028 tests in 110 suites passed; Benchmarks build complete
    - commit: df38a91
    - review: findings — Sources/AgentViewKitTestSupport/ScriptedSession.swift:254
  timestamp: 2026-10-08T13:08:05.232969+00:00
- actor: claude-code
  id: 01m4dtjtgpdqh6xqgxwwmsfy9w
  text: |-
    Review finding fixed (ScriptedSession.swift agentMessageChunkUpdate):
    - `ScriptedSession.agentMessageChunkUpdate(messageID:text:)` now returns `try JSONValue(encoding: BackgroundRunScript.makeChunkUpdate(messageID:text:))`. The hand-built object is deleted. BackgroundRunScript.swift is not changed.
    - `JSONValue(encoding:)` throws, so `agentMessageChunkUpdate` now throws. Callers changed: (1) `SessionStateBannersHostedTests.chunkFrame(index:)` throws. `openOverflowingSession` makes the frames before `ScriptedSession.open`, because the `leadIns` closure cannot throw. (2) The static `markerUpdate` of the composer tests is now `makeMarkerUpdate() throws`. The test makes the value before it sets the `followUps` closure, because that closure cannot throw. (3) `ScriptedSessionTests` uses `try`.
    - Key check: new test `anAgentMessageChunkUpdateHasTheMembersOfATextChunkOnTheWire` examines the member names: `sessionUpdate`, `messageId`, `content`, and in `content`: `type`, `text`. It passed before the change (baseline) and after the change. Thus the encoded JSON has the same keys as the old hand-built value.
    - Module dependencies: in the root package, `ScriptedSession.swift` and `BackgroundRunScript.swift` are in the same target (AgentViewKitTestSupport). Thus the call is permitted there. The Benchmarks package compiles `ScriptedSession.swift` through a symbolic link, without `BackgroundRunScript.swift`. Thus the Benchmarks build failed without a change. As `Benchmarks/README.md` ("The boundary") tells, I added a link `Benchmarks/Benchmarks/AgentViewKitBenchmarks/BackgroundRunScript.swift`. I updated `BenchmarkSymlinkTests.linkedSources`, the README table and text, the `Benchmarks/Package.swift` comment, and the file header of `ScriptedSession.swift`. BackgroundRunScript.swift has no class and imports only FoundationModelsACP, so it compiles in the benchmark module with no default isolation.
    - Other hand-built wire shapes in ScriptedSession.swift: the `initialize` result, the `session/new` result, `permissionParams`, `formElicitationParams` and `requestFrame` are JSON text. No public builder in DemoSupport or in the test support makes these shapes (`ScriptedWireAgent.resultFrame` is private and makes a result frame, not a request frame). Thus no other copy was removed.
    - The ARCHITECTURE.md file does not exist.
  timestamp: 2026-10-08T13:17:30.006203+00:00
- actor: claude-code
  id: 01m4dtjxnsw2f9en6sbzcw6hg8
  text: |-
    ### implement — changed
    - evidence: 8 files — Sources/AgentViewKitTestSupport/ScriptedSession.swift, Tests/AgentViewKitTests/TestSupport/ScriptedSessionTests.swift, Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift, Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift, Tests/PackageStructureTests/BenchmarkSymlinkTests.swift, Benchmarks/README.md, Benchmarks/Package.swift, new link Benchmarks/Benchmarks/AgentViewKitBenchmarks/BackgroundRunScript.swift. `swift test`: 1029 tests in 110 suites passed, 93 tests in 11 suites passed, 1 test in 1 suite passed, 0 failures. One dependency warning from the build system (mlx-swift_Cmlx.bundle), which is not from this change. `swift build --package-path Benchmarks`: exit 0. 1 of 1 open review finding checked.
    - next: /review
  timestamp: 2026-10-08T13:17:33.241632+00:00
- actor: claude-code
  id: 01m4dtykj27tbj5ab125q9szgq
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (d49c3a5). 7 files reviewed. findings 0, confirmed 0, refuted 0, failed 0. All prior review findings are checked.
    - next: none. The task is in done.
  timestamp: 2026-10-08T13:23:56.098283+00:00
- actor: claude-code
  id: 01m4dtyva7evs2811sna0yk7ty
  text: |-
    ### finish iteration 3 — clean
    - implement: changed — 8 files (ScriptedSession.swift, tests, Benchmarks link and docs)
    - test: green — swift test, 1029 tests in 110 suites passed; Benchmarks build complete
    - commit: d49c3a5
    - review: clean — 0 findings, all 5 prior findings checked
  timestamp: 2026-10-08T13:24:04.039611+00:00
position_column: done
position_ordinal: ff9780
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

## Review Findings (2026-10-08 07:49)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 3 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift:490` `reuse/reuse` — The marked line builds the params object with sessionId and calls makeSessionUpdateFrame. The same wrapping appears in the two other hosted test files, so the pattern is written three times across the change. Move the sessionId wrapping into one shared helper in ScriptedSession.swift. This helper can take the sessionID from the request when needed, and this function can call it.
- [x] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift:74` `duplication/duplication` — The chunkFrame update object repeats the agent_message_chunk object of markerUpdate. Both build the same JSON with sessionUpdate, messageId and a text content. Only the messageId and the text differ. A later fix to the update shape must be made in two places. Extract one shared function in the test support, for example agentMessageChunkUpdate(messageID:text:), that returns the JSONValue object. Call it from chunkFrame (with messageID "early-\(index)" and text "Early.") and from markerUpdate (with messageID markerMessageID and text "Done."). Delete the copied object literal from both sites.
- [x] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift:74` `reuse/reuse` — The marked lines build an agent_message_chunk JSONValue with the same keys and text shape as the markerUpdate value in the composer tests. Only the messageId and the text differ. A parameterized helper would keep one definition of this update shape. Add one helper, for example agentMessageChunk(messageID:text:), in a shared test file. Use it for markerUpdate and for the update built in chunkFrame, and pass the messageId and text as parameters.
- [x] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift:79` `reuse/reuse` — The marked lines wrap the agent message chunk in a params object with sessionId and call makeSessionUpdateFrame. This repeats the sessionId wrapping that the other two hosted test files also write by hand. Call a shared sessionUpdateFrame helper, placed in ScriptedSession.swift next to requestFrame, instead of building the params object here.

## Review Findings (2026-10-08 08:05)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKitTestSupport/ScriptedSession.swift:254` `duplication/duplication` — agentMessageChunkUpdate builds an agent_message_chunk JSON value by hand, which repeats the shape already built by BackgroundRunScript.makeChunkUpdate. Two copies of one wire shape can drift apart. Delete the hand-built JSONValue object and return JSONValue(encoding: BackgroundRunScript.makeChunkUpdate(messageID: messageID, text: text)). The existing JSONValue(encoding:) initializer at ScriptedSession.swift:196 is already used for this. Check that the encoded JSON has the same keys as before. Do not edit BackgroundRunScript.swift, because it is outside this change.
