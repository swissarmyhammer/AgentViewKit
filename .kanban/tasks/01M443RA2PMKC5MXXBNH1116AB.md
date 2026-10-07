---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m48rj3dq5z3z54yrj30jwj59
  text: 'Note from ^rdk4w45: `ACPSessionList` and `ACPSessionListTests` are already removed. The session picker binds to `ConnectionModel.sessions`, so this card has no session list file to remove. `ACPThreadSource.resumeSession(_:cwd:on:thread:agentName:)` now has only its test as a caller.'
  timestamp: 2026-10-06T14:05:57.047344+00:00
- actor: claude-code
  id: 01m4agd75z34gq5jd1s0dx72hn
  text: |-
    Research (implement start):
    - `ACPSessionList` is already gone (^rdk4w45). The ACP/ folder has `ACPThreadSource.swift`, `SessionUpdateMapping.swift`, `TranscriptSeed.swift` and `ACPThreadActions.swift` to remove.
    - Outside `Sources/AgentViewKit/ACP/`, one call of `SessionUpdateMapping` stays: `AgentAuthView.runTerminalAuth` converts the ACP `AuthMethodTerminal` into the kit `AuthMethod.Terminal` for `AgentThreadActions.runTerminalAuth(_:)`. ^83200vg removes `runTerminalAuth` later, but it is blocked upstream. Plan: `AgentThreadActions.runTerminalAuth(_:)` takes the ACP `AuthMethodTerminal` directly, so the conversion goes away and no new conversion comes.
    - `ACPThreadActions` has no caller outside its test: the demo app, the README and the snippets give `LoggingThreadActions`. Plan: delete it, with `ACPAgentProgram` and `ACPThreadActionsError`.
    - The deprecated `AgentThreadView(thread:actions:)` has about 22 callers in 10 hosted test files. The card deletes it. The thread-path helpers that only this initializer uses also go: `ThreadAnnouncementObserver`, the thread forms of `ThreadAccessibility.turnAnnouncement`, `toolCallProgress(in: [ThreadItem])` and `pendingRequests(of: AgentThread)` (their doc comments say that this removal removes them). `ConversationView(thread:)`, `ItemRow` and the other `.thread` cases stay for ^gzj5cye.
    - Protocol version check: move to `SupportedProtocolVersions.swift`. No kit record can hold the refusal now, so the check throws an error that names both versions.
    - README prose names `AgentThreadView(thread:actions:)` two times; change it.
  timestamp: 2026-10-07T06:21:57.311176+00:00
- actor: claude-code
  id: 01m4ah7bs6wkg7hzy07xv98es8
  text: |-
    Progress:
    - RED then GREEN: `RemovedVocabularyTests` has new tests `noFileUsesTheRemovedACPAdapter` (scans Sources, Tests/AgentViewKitTests, Examples and README.md for ACPThreadSource, SessionUpdateMapping, ACPSessionList, TranscriptSeed, ACPThreadActions, ACPThreadActionsError, ACPAgentProgram, SessionUpdateFixtures) and `noFileCallsTheRemovedThreadInitializer` (multi-line pattern `AgentThreadView\(\s*thread:`). The old `thePendingRequestCardsUseNoSessionUpdateMapping` test is gone: the new scan covers it. Both new tests failed first for the right reason.
    - RED then GREEN: `ProtocolVersionTests` calls the new place of the check. `SupportedProtocolVersions.accept(_:requested:)` throws `UnsupportedProtocolVersionError`. `ConnectionModel.initializeCheckingProtocolVersion(_:)` maps `ProtocolVersionMismatchError` to the same error. No kit record holds the refusal now. 9 tests pass.
    - RED then GREEN: `AgentThreadActions.runTerminalAuth(_:)` takes the ACP `AuthMethodTerminal`. `AgentAuthView` calls it directly. The last `SessionUpdateMapping` call outside ACP/ is gone, and no new conversion came.
    - Deleted: ACPThreadSource.swift, SessionUpdateMapping.swift, TranscriptSeed.swift, ACPThreadActions.swift and their tests and SessionUpdateFixtures. The `AgentProcessLauncherTests` suite moved from ACPThreadActionsTests.swift to its own file. Deleted the deprecated `AgentThreadView(thread:actions:)`, `ThreadAnnouncementObserver`, the thread forms of `ThreadAccessibility` functions, and the internal `agentCommandScope(thread:anchors:)`.
    - README, Docs/decisions/acp-version.md and doc comments no longer name the adapter.
    - A sub agent moves the hosted tests that used the removed initializer to the session path (in progress).
  timestamp: 2026-10-07T06:36:13.990252+00:00
- actor: claude-code
  id: 01m4ak7ngrftrjazbjykfxqnq5
  text: |-
    ### implement — changed
    - evidence: `swift test` 1293 tests in 125 suites + 83 tests in 12 suites, all pass (only warning: the mlx-swift `missing creator for mutated node`; no deprecation warning, because the old initializer is gone). `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo` passed (4 UI tests). periphery: no dead declaration in Sources. Unstable tests ^zcktrsh and ^vhp5fv7 did not fail in this run.
    - Deleted sources: ACPThreadSource.swift, SessionUpdateMapping.swift, TranscriptSeed.swift, ACPThreadActions.swift (ACPSessionList was already gone, ^rdk4w45). Deleted tests: ACPThreadSourceTests, SessionUpdateMappingTests, SessionUpdateFixtures, ACPThreadActionsTests (its `AgentProcessLauncherTests` suite moved to AgentProcessLauncherTests.swift), AgentThreadViewHostedTests (covered by SessionTranscriptViewHostedTests). AgentViewKitACPModuleTests and ScriptedWireAgent+Bounded.swift used no removed type.
    - Deleted the deprecated `AgentThreadView(thread:actions:)`, `ThreadAnnouncementObserver`, the thread forms of `ThreadAccessibility.turnAnnouncement`, `toolCallProgress(in:)`, `pendingRequests(of:)`, and the internal `agentCommandScope(thread:anchors:)`.
    - Version check: `SupportedProtocolVersions.accept(_:requested:)` throws `UnsupportedProtocolVersionError`; `ConnectionModel.initializeCheckingProtocolVersion(_:)` maps `ProtocolVersionMismatchError` to it. ProtocolVersionTests call the new place.
    - No kit conversion is left in AgentAuthView: `AgentThreadActions.runTerminalAuth(_:)` takes `AuthMethodTerminal`, `TerminalRecord.authID(for:)` takes `AuthMethodId`.
    - Old-path hosted tests: moved to the session path or deleted where a session test covers the same behaviour (list in the sub agent report, kept in the chat reply). Two `ReasoningViewHostedTests` tests now mount `ItemRow` directly, because a thought entry on the session path is never in progress; ^gzj5cye removes them with the thread path.
    - Bridges kept, because the thread path still calls them until ^gzj5cye: `JSONValue.acpValue` (ToolCallSource .record, ElicitationView), `PlanEntry.acpEntry` (TaskListView), `ToolKind.acpKind` and `ToolCallStatus.acpStatus` (ToolCallSource .record), `PermissionPresentation.order(of: [AgentViewKit.PermissionOption])` (AgentCommandTarget thread path), the internal `ExpandedBlocksStore` id forms (ReasoningView, JSONDisclosure, ToolCallSource, AgentCommandTarget). None lost all callers.
    - next: /review
  timestamp: 2026-10-07T07:11:21.112512+00:00
- actor: claude-code
  id: 01m4am9yvzx580ywze4bjp06je
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (commit 2d0b517), 2 findings (2 confirmed, 1 refuted) — Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift:72 (reuse/reuse), Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift:155 (completeness/invariant-propagation)
    - next: /implement — do the two items in the "Review Findings (2026-10-07 02:16)" section
  timestamp: 2026-10-07T07:30:04.799063+00:00
- actor: claude-code
  id: 01m4ama0w4zd2pf4gak7sdsa0c
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ACPThreadSource, SessionUpdateMapping, TranscriptSeed and ACPThreadActions deleted; AgentThreadView(thread:actions:) deleted; protocol version check in SupportedProtocolVersions; old-path tests moved to the session path or deleted when covered; 49 paths
    - test: green — swift test, 1293 passed; README and demo UI gates passed
    - commit: 2d0b517
    - review: findings — Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift:72, Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift:155
  timestamp: 2026-10-07T07:30:06.852886+00:00
- actor: claude-code
  id: 01m4amp68gx8xrn8ha3ekkdz3a
  text: |-
    Review findings (2026-10-07 02:16), both done:
    - reuse/reuse: `BackgroundRunScript.makeChunkUpdate(messageID:text:)` in AgentViewKitTestSupport is now `public`. ThreadAccessibilityHostedTests calls it, and its own copy is deleted. A search of the test target found no other typed `.agentMessageChunk(ContentChunk(...))` helper. The JSON-text chunk helpers (`WireBlockJSON.makeChunk`, `SessionTranscriptViewHostedTests.chunk`) make wire JSON, not a `SessionUpdate` value, so they are a different helper.
    - completeness/invariant-propagation: the test `aMountedSessionThreadViewRegistersTheTenCommands` has a purpose: it proves that the session path of `AgentThreadView` applies `agentCommandScope` itself (^19kd9gm). An outer scope would hide a regression, so the test keeps no outer scope. `mount` and `mountInSessionScope` are now one helper, `mount(session:system:outerScope:composer:pasteboard:)`. It always gives the `connection` input, the `\.sessionModel` environment and the pasteboard. A `@ViewBuilder` helper `scoped(_:in:)` applies the outer scope only when `outerScope` is true. The test has a doc comment that says it mounts no outer scope on purpose. The cancel, approve and copy tests keep their old setup (`outerScope: false`). The two scope tests and the composer tests use `outerScope: true`.
    - Mutation check: I removed `.agentCommandScope(session: session, anchors: anchors)` from `AgentThreadView` one time. The test failed with 4 issues (the scope tree was empty). Then I restored the line; `git diff` shows no change in AgentThreadView.swift.
  timestamp: 2026-10-07T07:36:45.584185+00:00
- actor: claude-code
  id: 01m4amp94skdb1mw00emd6gaze
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKitTestSupport/BackgroundRunScript.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift, Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift. `swift test --filter 'AgentCommandScopeHostedTests|ThreadAccessibilityHostedTests|BackgroundRun'`: 28 tests in 3 suites passed. Mutation run (scope removed from AgentThreadView): `aMountedSessionThreadViewRegistersTheTenCommands` failed with 4 issues, then the scope was restored. Full `swift test`: 1293 tests in 125 suites and 83 tests in 12 suites passed; the only warning is the known mlx-swift `missing creator for mutated node` build warning. The unstable tests ^zcktrsh and ^vhp5fv7 did not fail and were not changed. Both review findings are `- [x]`. No commit, no push.
    - next: /review
  timestamp: 2026-10-07T07:36:48.537519+00:00
- actor: claude-code
  id: 01m4amzbx47yyejt9k5b5wr9tg
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 1a36b18), 0 findings (0 confirmed, 0 refuted), 3 files reviewed, 2 .kanban files excluded by .reviewignore. All prior Review Findings items are checked.
    - next: none — task moved to done
  timestamp: 2026-10-07T07:41:46.276299+00:00
- actor: claude-code
  id: 01m4amzd5ts773h386ag0efn2g
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — shared BackgroundRunScript.makeChunkUpdate; one mount helper with an outerScope option; the scope test mounts no outer scope on purpose and fails when the view scope is removed
    - test: green — swift test, 1293 passed
    - commit: 1a36b18
    - review: clean — 0 findings
  timestamp: 2026-10-07T07:41:47.578242+00:00
depends_on:
- 01M443S0EDEB23N7RPAR39TGZ5
- 01M443RTQWKFHNWK4SH96PTE46
- 01M48MQS1Q5HBNDFMBD2CT0C6C
- 01M48MR5W3YAB8VFA4KTJZVCYN
- 01M48MRPTCY92MXNFB1XZHAA2A
position_column: done
position_ordinal: ff8480
title: 'Remove the ACP adapter: ACPThreadSource, SessionUpdateMapping, ACPSessionList and ACPThreadActions'
---
## What
When all view groups, the demo app and the README snippets use `SessionModel` and `ConnectionModel`, the bridge of the pin-move task has no user. Source: update.md §4.5 (rows 2, 3, 4, 6, 7). This also removes the double fold of each update. Owner rule (2026-10-06): each view binds directly to the observable model of FoundationModelsACPClient and calls the model methods. After this task no kit code converts a model value into a kit copy.

- [x] Delete `Sources/AgentViewKit/ACP/ACPThreadSource.swift`, `SessionUpdateMapping.swift`, `ACPSessionList.swift`, `TranscriptSeed.swift` (only `ACPThreadSource` uses it), and the deprecated `AgentThreadView(thread:actions:)` initializer.
- [x] Before the delete, make sure that no file outside `Sources/AgentViewKit/ACP/` calls `SessionUpdateMapping` (the three content tasks remove the calls in the entry views and the request cards). If a call stays, move it to the task that owns its view; do not add a new kit conversion.
- [x] Delete `ACPThreadActions.swift`, or reduce it to what the views still need that the models do not give (for example the terminal auth process). Each view calls the model methods directly.
- [x] Move the protocol version check: `ACPThreadSource.acceptProtocolVersion` goes to `Sources/AgentViewKit/ACP/SupportedProtocolVersions.swift` (or to the caller of `ConnectionModel.initialize(_:)`). Change `ProtocolVersionTests` to call the new place.
- [x] Delete their tests: `ACPThreadSourceTests`, `SessionUpdateMappingTests`, `SessionUpdateFixtures`, `ACPSessionListTests`, `ACPThreadActionsTests`, and the tests of `TranscriptSeed`. Change `AgentViewKitACPModuleTests` and `ScriptedWireAgent+Bounded.swift` where they use the removed types. Move each test that still checks view behaviour into the view test of its group, as a binding test: a model change shows in the view, and a view action calls the model method.
- [x] Add `ACPThreadSource`, `SessionUpdateMapping`, `ACPSessionList` and `TranscriptSeed` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [x] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` refers to the removed types or the old initializer.
- [x] No source in `Sources/AgentViewKit/` converts a `TranscriptEntry` value, a pending request or a `ConnectionModel` value into a kit copy.
- [x] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] `ProtocolVersionTests` passes against the new place of the version check.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-10-07 02:16)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 40 file(s) reviewed, 8 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `Docs/decisions/acp-version.md` — no validator matches this file
> - `README.md` — no validator matches this file

> ⚠️ tool rules `code-hygiene/disallowed-constructs-swift`, `code-hygiene/function-length-swift`, `code-hygiene/idioms-swift`, `code-hygiene/magic-numbers-swift` and `code-hygiene/missing-docs-swift` each declined the nine files that this change deletes (no file at the path): Sources/AgentViewKit/ACP/ACPThreadActions.swift, Sources/AgentViewKit/ACP/ACPThreadSource.swift, Sources/AgentViewKit/ACP/SessionUpdateMapping.swift, Sources/AgentViewKit/ACP/TranscriptSeed.swift, Tests/AgentViewKitTests/ACP/ACPThreadActionsTests.swift, Tests/AgentViewKitTests/ACP/ACPThreadSourceTests.swift, Tests/AgentViewKitTests/ACP/SessionUpdateFixtures.swift, Tests/AgentViewKitTests/ACP/SessionUpdateMappingTests.swift, Tests/AgentViewKitTests/Thread/AgentThreadViewHostedTests.swift.

- [x] `Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift:72` `reuse/reuse` — Function `makeChunkUpdate` reinvents a utility that already exists elsewhere with 0.96 semantic similarity. A shared implementation should be called instead of duplicating the capability. Import and call the existing `makeChunkUpdate` from `BackgroundRunScript` instead of redefining it, or extract both into a shared test utility if the context differs enough to warrant separate implementations.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift:155` `completeness/invariant-propagation` — The new test `aMountedSessionThreadViewRegistersTheTenCommands` calls the unchanged `mount` helper which does not apply the `.agentCommandScope` modifier or pass `connection` to AgentThreadView, while the refactoring updates all session-based tests to use `mountInSessionScope` that applies both. The test's later assertions (lines 161–164) expect commands to be registered, which requires the scope setup that `mount` does not provide. Change line 155 to use `Self.mountInSessionScope(session: session, system: system)` instead of `Self.mount(...)` to match the refactoring pattern and enable proper command registration.