---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m44e4zapb6dhd6z03q5ypyqj
  text: |-
    Research done. Source of truth: FoundationModelsACPClient `a65af8a`, `Sources/FoundationModelsACPClient/Model/` and `PendingElicitation.swift`, read with `git show` in the sibling checkout `../FoundationModelsACPClient`. ACP type names checked in `../FoundationModelsACP` at `27419fa`.

    Differences from update.md §4.2 and §4.3 (design):
    - `ConnectionModel.openSessions: [SessionId: SessionModel]` is the open set. `session(for:)` gives one open model. `sessions: [SessionInfo]` is the session list only.
    - Connect call: `connect(over:logger:bufferLimits:client:)`, returns `ClientSideConnection`. `init(coalescingCadence:clock:logger:)`.
    - `ConnectionState` cases: `.disconnected` (start value), `.connecting`, `.connected`, `.failed(any Error)`. Equality compares the case only.
    - Initialize and auth: `initialize(_:)`, `initializeResponse`, `agentCapabilities`, `authMethods`, `authState: AuthState` (`.unknown`, `.notRequired`, `.required`, `.authenticated`, `.failed`), `login(_:)`, `logout(_:)`.
    - Capability flags: `canListSessions`, `canResumeSessions`, `canCloseSessions`, `canDeleteSessions`, `canLogout`. A call without the capability throws `ConnectionModelError.unsupported(method:)`. `newSession(_:)` has no flag.
    - `deleteSession(_:)` takes a `SessionId`; `close(_:)` needs `canCloseSessions`.
    - `ConnectionModel.pendingElicitations` items are `PendingElicitation` with `requestId` and `requestMethod`. Replies: `acceptElicitation(_:content:)`, `declineElicitation(_:)`, `cancelElicitation(_:)`.
    - `TranscriptEntry` is an enum with 9 cases: `userMessage`, `agentMessage`, `thought`, `toolCall`, `terminal`, `plan`, `unknown`, `compaction`, `error`. There is no "local pending message" case: a local prompt is a `UserMessageEntry` with `SendState.pending`. `TranscriptEntry.ID` is `.wire(SessionEntry.ID)` or `.local(UUID)`.
    - Entry classes: `UserMessageEntry`, `AgentMessageEntry`, `ThoughtEntry`, `ToolCallEntry` (has `name`, `title`, `linkedElicitationIDs`), `TerminalEntry` (`bytes`, computed `text`), `PlanTranscriptEntry`, `UnknownEntry`, `CompactionEntry`, `ErrorEntry`.
    - SessionModel adds: `notices: [SessionNotice]`, `dismissNotice(_:)`, `updateTap()`, `flushPendingChunks()`, `defaultCoalescingCadence`, `appendError(code:message:data:)`, `prompt(_:meta:)`, `cancel(meta:)`, `setConfigOption(_:)`, `selectPermission(_:option:)`, `cancelPermission(_:)`, `cancelAllPending()`, `isReplaying`, `history: SessionHistory` (`.live`, `.retained(replayFrom:)`), `hasMissedUpdates`, `isClosed`.
  timestamp: 2026-10-04T21:47:03.382749+00:00
- actor: claude-code
  id: 01m44eh0d3ppptk4mh0p73vhsb
  text: |-
    Implementation landed.

    - update.md: §4.2 and §4.3 are written again with the real names of `a65af8a`. The "(design)" marks are gone from the two headings. The D3 status says the models are built. The §4.1 note, the §4.4 terminal row (`text` is now in `TerminalEntry`), §1 ("It holds") and the §12 risk now agree with the built models.
    - New test `Tests/PackageStructureTests/UpdatePlanNamesTests.swift`. It reads each code span of §4.2 and §4.3 and fails for a span that is not in a fact table of the `a65af8a` client API, the ACP names of FoundationModelsACP `27419fa`, the wire names, or Swift attributes. It also requires each known difference from the card, requires `openSessions` in each §4.3 block that tells the open set, and fails on "(design)" headings and on "not built yet".
    - `ReadmeCoverageTests.section(_:of:)` got an `endingAt:` parameter (default `## `), so the new suite reuses it for `###` sections. New test `sectionEndsAtTheGivenPrefix`.

    Discoveries:
    - A code span that crosses a line break (the old `newSession(...) async throws\n -> SessionModel`) breaks the backtick pairs, so the new text keeps each span on one line.
    - The test skips commit hashes (`a65af8a`), because a hash is not an API name.
    - The design said `ConnectionModel.close` stops the stream. In the built code, `SessionModel.markClosed()` stops it. The text now says this.
    - `PendingElicitation` of the connection model has `requestMethod` in addition to `requestId`. The design did not name it.

    Tests: `swift test --filter UpdatePlanNamesTests` was RED (16 issues), then GREEN. `swift test --filter PackageStructureTests`: 56 tests passed. Full `swift test`: 1 + 56 + 1284 + 59 + 120 tests passed, no warning.
  timestamp: 2026-10-04T21:53:37.699938+00:00
- actor: claude-code
  id: 01m44eh1wdqnh925c9g4phk7qr
  text: |-
    ### implement — changed
    - evidence: 3 files — update.md, Tests/PackageStructureTests/UpdatePlanNamesTests.swift (new), Tests/PackageStructureTests/ReadmeCoverageTests.swift; `swift test --filter PackageStructureTests` 56 passed; full `swift test` all suites passed, 0 warnings
    - next: /review
  timestamp: 2026-10-04T21:53:39.213509+00:00
position_column: doing
position_ordinal: '80'
title: Check update.md sections 4.2 and 4.3 against the real client model API
---
## What
The names in update.md §4.2 and §4.3 come from the design. The built client models (FoundationModelsACPClient `a65af8a`, `Sources/FoundationModelsACPClient/Model/`) use some other names. Correct the plan before the pin move, so that each later task uses the real names. Source: update.md §4.1, §11 step 6. This task can run now; it does not change code.

- [x] Compare §4.2 and §4.3 with the public API of `ConnectionModel`, `SessionModel` and `TranscriptEntry`. Known differences: the open set is `openSessions`; the connect call is `connect(over:logger:bufferLimits:client:)`; the model also has `CompactionEntry`, `ErrorEntry`, `SessionNotice`, `dismissNotice(_:)`, `updateTap()`, `appendError(code:message:data:)`, `ToolCallEntry.linkedElicitationIDs`, and the capability flags `canListSessions`, `canResumeSessions`, `canCloseSessions`, `canDeleteSessions`, `canLogout`.
- [x] Correct update.md §4.2, §4.3 and the stale "not built yet" status in the decisions table.
- [x] Add `Tests/PackageStructureTests/UpdatePlanNamesTests.swift`: it reads `update.md` and fails if it finds the design names that do not exist (for example `sessions` used as the open set). Delete this test with `update.md` in the documents task.

## Acceptance Criteria
- [x] Each API name in update.md §4.2 and §4.3 exists in the client model source at `a65af8a`.

## Tests
- [x] `UpdatePlanNamesTests` passes.
- [x] `swift test --filter PackageStructureTests` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.