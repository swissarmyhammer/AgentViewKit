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
depends_on:
- 01M443S0EDEB23N7RPAR39TGZ5
- 01M443RTQWKFHNWK4SH96PTE46
- 01M48MQS1Q5HBNDFMBD2CT0C6C
- 01M48MR5W3YAB8VFA4KTJZVCYN
- 01M48MRPTCY92MXNFB1XZHAA2A
position_column: doing
position_ordinal: '80'
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