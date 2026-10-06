---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m493326qqn9ekz49ye0n0wtn
  text: |-
    Research (FoundationModelsACPClient be7e615, FoundationModelsACP fe0d82d, sources under .build/checkouts):
    - `SessionModel.selectPermission(_:option:)` (Model/SessionModel+Pending.swift) is synchronous. It calls `permissions.resolve(id, with: PendingPermissionRequest.selectedResponse(optionId))`. `PendingRequestQueue.resolve` (PendingRequestQueue.swift) resumes the continuation in `KeyedWaiters` and removes the item from `items`. It does not write a frame.
    - The suspended call is `ModelClient.requestPermission` (Model/ModelClient.swift), which returns `await session.awaitPermissionDecision(for:)`. `ClientSideConnection.serve` (FoundationModelsACP Connection/ClientSideConnection.swift) gives that result back to the connection core, and the core writes the response frame later, on the task of the inbound request.
    - `SessionModel.prompt(_:meta:)` (Model/SessionModel+Prompt.swift) adds the local pending user message at once (`addPendingPrompt`), then sends `session/prompt` through the request sender on the task of the caller. So the prompt frame can go out before the response frame. The frame order is not a contract of the client model.
    - The client has no public signal that the response frame is written and no async variant of `selectPermission`. The only public permission API is `pendingPermissions`, `selectPermission(_:option:)` and `cancelPermission(_:)`. `flushPendingChunks()` is for text chunks only.
    - Decision: case 3 of the order. The kit cannot guarantee the frame order without its own sequencing, which the rule forbids. The test changes to check what the kit guarantees: the card calls `selectPermission` with the chosen option before it calls `prompt`. The test reads this through the client model: at the moment the pending request goes away, the transcript has no user message with the comment yet.
    - The same wire-order assertion (`answer < prompt`) is also in `aRejectWithACommentSendsTheAnswerAndThenThePrompt`. It has the same race through the card, so that assertion goes too.
    - Upstream: the frame order needs a FoundationModelsACPClient change: an async `selectPermission` (and `cancelPermission`) that returns after the response frame is written.
  timestamp: 2026-10-06T17:09:58.615456+00:00
- actor: claude-code
  id: 01m493nawcgvj0w2w6g1hj3f48
  text: |-
    Implementation (one file: Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift; no production change):
    - Removed `thePermissionResponseFrameComesBeforeTheNextPromptFrame` and the `orderRuns` constant. That test called `model.selectPermission` and `model.prompt` directly, so it tested no kit code. It asserted a wire order that the client model does not promise.
    - Renamed `aRejectWithACommentSendsTheAnswerAndThenThePrompt` to `aRejectWithACommentAnswersTheRequestBeforeItSendsThePrompt`. It drives the real card (press "no", type the comment, press Send). The `answer < prompt` wire assertion is gone. The new assertion: a one-shot `withObservationTracking` on `model.pendingPermissions` (helper `flagAnswerBeforePrompt`) records, at the removal of the pending request, that the transcript has no user message with the comment. `SessionModel.prompt` adds its pending user message synchronously, so a prompt before the select leaves the flag clear. No sleep. The test still checks the wire result (`selected`, `no`), the user message in the transcript, and an empty `pendingPermissions`.
    - The helper `transcriptHasUserMessage` reuses `SessionTranscriptViewHostedTests.userMessage(_:)` and `text(of:)`.
    - RED: with the order in `SessionModel.reply(to:_:)` reversed for one run (prompt, then select), the test failed at `answeredBeforePrompt.value → false`. The production file was then restored; `git diff` shows no change in Sources.
    - GREEN: `swift test --filter "PendingRequestsSessionModelHostedTests/aRejectWithACommentAnswersTheRequestBeforeItSendsThePrompt" --maximum-repetitions 100`: 100 of 100 passed, no issue.
    - Full `swift test` 2 times: each run 1,299 tests in 119 suites + 77 tests in 12 suites + 1 test passed, 0 failures. The only warning is the known mlx-swift `missing creator for mutated node`.
    - The ACP time limit (5 s) is not changed. No retries, no `withKnownIssue`.
    - Open item: the acceptance item "10 full runs, or an upstream issue open and linked" is not complete. The dispatcher asked for 2 full runs and a record on this card. A person must open the FoundationModelsACPClient issue (async `selectPermission`/`cancelPermission` that returns after the response frame is written) and link it here.
  timestamp: 2026-10-06T17:19:57.324869+00:00
- actor: claude-code
  id: 01m493nevc9y01m4j2xqs92685
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift. Commands: `swift test --filter ...aRejectWithACommentAnswersTheRequestBeforeItSendsThePrompt` (RED with the order reversed, then restored), the same filter with `--maximum-repetitions 100` (100/100 pass), full `swift test` 2 times (1,299 + 77 + 1 pass each, 0 failures, only the known mlx warning).
    - next: /review. Open: a person must open the FoundationModelsACPClient issue for an async `selectPermission` and link it on this card.
  timestamp: 2026-10-06T17:20:01.389005+00:00
- actor: claude-code
  id: 01m49568rn4hgy3ep07mxzypwf
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — removed the wire frame-order test; aRejectWithACommentAnswersTheRequestBeforeItSendsThePrompt checks the kit order through the model with no sleep
    - test: green — swift test 10 runs, 1299 passed each
    - commit: ce6765f
    - review: findings — Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift:130
  timestamp: 2026-10-06T17:46:40.789299+00:00
- actor: claude-code
  id: 01m4956am90ds5503ddjzacfwq
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (ce6765f), 1 finding (1 confirmed, 0 refuted) — Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift:130 reuse/reuse: flagAnswerBeforePrompt reinvents the observation tracking pattern that ChangeFlag.observing provides.
    - next: /implement the finding in the dated Review Findings section (2026-10-06 12:44). The task stays in review.
  timestamp: 2026-10-06T17:46:42.697424+00:00
- actor: claude-code
  id: 01m495k2n474k91qykrd7x2v5h
  text: |-
    Fix for the review finding `reuse/reuse` (flagAnswerBeforePrompt):
    - `ChangeFlag.observing(_:when:)` (Sources/AgentViewKitTestSupport/ChangeFlag.swift) has a new parameter `when condition: @escaping @Sendable () -> Bool = { true }`. The change handler sets the flag only when `condition()` gives `true` at the change. The default keeps the old behavior, so the 13 current callers (`ChangeFlag.observing { ... }` with one trailing closure) compile and work with no change.
    - `flagAnswerBeforePrompt` now calls `ChangeFlag.observing { _ = model.pendingPermissions } when: { MainActor.assumeIsolated { !transcriptHasUserMessage(...) } }`. Its own `withObservationTracking` and `ChangeFlag()` are gone. The `import Observation` in that file is removed, because nothing in the file uses it now.
    - New tests: Tests/AgentViewKitTests/TestSupport/ChangeFlagTests.swift (no condition sets the flag; condition true at the change sets it; condition false at the change leaves it clear). The probe is `@MainActor @Observable`, so the `@Sendable` condition can capture it.
    - RED: `swift test --filter ChangeFlagTests` failed to compile with "extra trailing closure passed in call" (no `when:` parameter). GREEN: 3 of 3 pass.
    - Discovery: `ThreadItemTests.bumpNotifiesAnObserverOfTheRevision` also hand-writes the same pattern. That file is not in the scope of this card, so I added ^1v77tbh for it.
  timestamp: 2026-10-06T17:53:40.516950+00:00
- actor: claude-code
  id: 01m495k60pwvzgzy9d5m1cdtz0
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKitTestSupport/ChangeFlag.swift, Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift, Tests/AgentViewKitTests/TestSupport/ChangeFlagTests.swift (new). Commands: `swift test --filter ChangeFlagTests` (RED: compile error, no `when:`; GREEN: 3/3 pass); `swift test --filter "PendingRequestsSessionModelHostedTests/aRejectWithACommentAnswersTheRequestBeforeItSendsThePrompt" --maximum-repetitions 50` (50/50 pass); full `swift test` (1302 tests in 120 suites + 77 tests in 12 suites + 1 test pass, 0 failures; only the known mlx `missing creator for mutated node` warning). No sleeps.
    - next: /review. The finding in "Review Findings (2026-10-06 12:44)" is `- [x]`. The task stays in doing.
  timestamp: 2026-10-06T17:53:43.958504+00:00
position_column: doing
position_ordinal: '80'
title: Make PendingRequestsSessionModelHostedTests.thePermissionResponseFrameComesBeforeTheNextPromptFrame stable
---
## What
The full `swift test` run on 2026-10-06 (during ^s8sq0bf) failed one time in this test: "Run 39: the prompt frame came before the response frame" (answer index 81, prompt index 80). The other 1,323 tests passed.

`SessionModel.selectPermission(_:option:)` (FoundationModelsACPClient `be7e615`, `SessionModel+Pending.swift`) only resumes the continuation of the pending request (`permissions.resolve`). The response frame goes out later, from the task of the request handler. A `SessionModel.prompt(_:meta:)` call right after the select can write its frame first. The test asserts the opposite order, so it fails when the prompt wins the race.

This is not caused by a kit view. Find out if the order is a contract of the client model:
- If the client model must send the response first, report it upstream (FoundationModelsACPClient) and keep the test.
- If the order is not a contract, record that decision and change the test to assert what the model does promise.

## Decision
The frame order is not a contract of the client model. The client has no public signal that the response frame is written, and no async `selectPermission`. The kit adds no sequencing of its own (owner rule: the kit binds to the client model and adds no turn logic, no sequencing and no parallel state).

The test now checks only what the kit guarantees: the card calls `selectPermission` with the chosen option before it calls `prompt`. `aRejectWithACommentAnswersTheRequestBeforeItSendsThePrompt` reads this order in the client model. The model-only test `thePermissionResponseFrameComesBeforeTheNextPromptFrame` is removed, and the wire-order assertion in the reject-with-comment test is removed.

## Upstream need (FoundationModelsACPClient)
The wire order "permission response frame before the next prompt frame" needs a FoundationModelsACPClient change: an async `selectPermission(_:option:)` (and `cancelPermission(_:)`) that returns after the response frame is written. When the client has it, the kit can await it before it sends the comment prompt, and a wire-order test can come back.

## Acceptance Criteria
- [x] The cause is recorded on this card, with the client model code that sends the response.
- [x] The test passes in 10 full `swift test` runs, or an upstream issue is open and linked here. (2 full runs pass, as the dispatcher asked; the changed test passes 100 of 100 repetitions. No upstream issue is open yet: the need is recorded above. A person must open the FoundationModelsACPClient issue and link it here.) — 10 full runs on 2026-10-06, each 1299 passed and 0 failed. The upstream change (an async `selectPermission` and `cancelPermission` in FoundationModelsACPClient that return after the response frame is written) is recorded for the owner.
- [x] Do not raise the test time limit and do not add retries.

## Workflow
- Use `/tdd`.

## Review Findings (2026-10-06 12:44)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 1 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift:130` `reuse/reuse` — flagAnswerBeforePrompt reinvents the observation tracking pattern that ChangeFlag.observing provides. Both create a ChangeFlag and use withObservationTracking to set it when observed values change. The difference is conditional — this code sets the flag only if the transcript check fails — but ChangeFlag.observing could be extended to support an onChange callback with custom logic, rather than always setting immediately. Either extend ChangeFlag.observing to accept an onChange callback parameter that receives a ChangeFlag to set conditionally, or call a parameterized variant that takes both a read closure and a condition closure.
