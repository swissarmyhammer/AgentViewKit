---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m46am42vz61t5485tk7g5c2e
  text: |-
    Research done.
    - No ACP source makes `addAuthorization`. Only `AgentThreadApplyTests`, `PermissionViewHostedTests`, `ThreadAccessibilityTests` and `ACPThreadActionsTests` apply it.
    - `ElicitationURLConsentView` uses only `AuthorizationPresenter` (`present(url:callbackScheme:ephemeral:)` and the `authorizationPresenter` environment value). It does not use `AuthorizationRequest` or `AuthorizationView`.
    - These parts exist only for `addAuthorization`: `AuthorizationRequest` and `AuthorizationRequestID`, `AgentThread.pendingAuthorizations`, `ThreadChange.resolveAuthorization`, `AuthorizationView`, the authorization cards in `PendingRequestsHost`, the authorization labels in `ThreadAccessibility`, `AgentThreadActions.connect(_:)` (protocol, `LoggingThreadActions`-style default, `NoopThreadActions`, `ACPThreadActions`). In `ACPThreadActions`, these members serve only `connect(_:)`: `presenter`, `connectionStore`, `callbackScheme`, `ephemeral`, `defaultCallbackScheme`, `elicitationIdMetaKey`, `callbackSchemeMetaKey`, and the wire `elicitationId` fallback in `pendingElicitationID(matching:)`.
    - Decision: remove all of these. Keep `AuthorizationPresenter`, `WebAuthSessionFactory`, `ConnectionStore` and `AgentAuthView`.
    - `ACPDemoSession` passes `connectionStore:` to `ACPThreadActions`; that argument goes.
    - Docs (`plan.md`, `README.md` Components line, `Docs/decisions/connection-states.md`) still name `AuthorizationView`. The plan rewrite task ^g95wwbs owns those lines, so this task leaves them.
  timestamp: 2026-10-05T15:23:54.331619+00:00
- actor: claude-code
  id: 01m46b327e7ev8f9krpkatnw6e
  text: |-
    Implementation done (TDD).
    - RED: added the names to `RemovedVocabularyTests.removedSymbols`: `AuthorizationPayload`, `AuthorizationRequest`, `AuthorizationRequestID`, `AuthorizationView`, `addAuthorization`, `pendingAuthorizations`, `resolveAuthorization`, `removePlan`. `sourcesUseNoRemovedSymbol` failed with the expected uses.
    - Latent bug found in the scanner: `wholeWord` used the default Unicode word boundaries. These do not break at a `.` between two letters, so `thread.pendingAuthorizations` was not found (the uses in `ThreadAccessibility.swift` and `PendingRequestsHost.swift` were missed). New test `usesFindsAWordAfterAMemberDot` failed first; the fix is `.wordBoundaryKind(.simple)`. With the fix, no earlier removed name shows a use.
    - GREEN: removed `ThreadChange.removePlan`, `.addAuthorization`, `.resolveAuthorization`; `AgentThread.pendingAuthorizations`; deleted `Catalog/AuthorizationPayload.swift` (the `Catalog` directory is now gone), `Model/Requests/AuthorizationRequest.swift`, `Connections/AuthorizationView.swift` and `AuthorizationViewHostedTests.swift`; removed `connect(_:)` from `AgentThreadActions`, `LoggingThreadActions`, `NoopThreadActions` and `ACPThreadActions`; removed the authorization cards from `PendingRequestsHost` and the authorization summaries from `ThreadAccessibility`.
    - `ACPThreadActions` lost the members that only `connect(_:)` used: `presenter`, `connectionStore`, `callbackScheme`, `ephemeral`, `defaultCallbackScheme`, `elicitationIdMetaKey`, `callbackSchemeMetaKey`, and the wire `elicitationId` fallback of `pendingElicitationID(matching:)` (the kit id is always the local UUID string). The init now takes `thread`, `client`, `connection`, `sessionId`, `processLauncher`, `agentProgram`. `ACPDemoSession` no longer passes `connectionStore:`.
    - Kept: `AuthorizationPresenter` (its doc example now names the Open in Browser button of `ElicitationURLConsentView`), `WebAuthSessionFactory`, `ConnectionStore`, `AgentAuthView`.
    - `TaskListViewHostedTests`: the empty-state test now uses `.clear` in place of `.removePlan` (renamed `clearingTheThreadShowsTheEmptyState`), because `.clear` is the remaining way to empty the plans.
    - Not changed, for ^g95wwbs: `plan.md`, the README Components line for `AuthorizationView`, and `Docs/decisions/connection-states.md` still name the removed parts. `update.md` §6 rows stay as the record of the removal.
  timestamp: 2026-10-05T15:32:03.950655+00:00
- actor: claude-code
  id: 01m46b34bvf64pcnfwtycfykag
  text: |-
    ### implement — changed
    - evidence: 25 files (8 Sources files changed, 3 Sources files deleted, 7 test files changed, 1 test file deleted, plus `Sources/DemoSupport/ACPDemoSession.swift`). `swift test --filter RemovedVocabularyTests` red, then green; `swift test` passed: 1 + 66 + 1157 + 124 tests, 0 failures, 0 warnings; `Scripts/test-examples.sh AgentViewKitDemo` passed (2 UI tests). README not changed, so `Scripts/check-readme.sh` was not needed.
    - next: /review
  timestamp: 2026-10-05T15:32:06.139825+00:00
depends_on:
- 01M443KTS93HHQJREBRF279MDW
position_column: doing
position_ordinal: '8280'
title: Remove addAuthorization, the authorization payload and removePlan
---
## What
No ACP source makes `addAuthorization` or `removePlan`. Authorization through the catalog payload was the Router model (update.md §6). The ACP auth flow (`authMethods`, login, logout) stays, and `AgentAuthView` stays.

- [x] Remove `addAuthorization` and `removePlan` from `ThreadChange` and their apply code from `AgentThread`.
- [x] Delete `Sources/AgentViewKit/Catalog/AuthorizationPayload.swift` (if the catalog task left it) and remove `AuthorizationPayload.elicitationId`. Examine `Sources/AgentViewKit/Model/Requests/AuthorizationRequest.swift`, `Connections/AuthorizationView.swift` and `Connections/AuthorizationPresenter.swift`: keep the parts that the URL elicitation consent (`ElicitationURLConsentView`) uses; remove the parts that only `addAuthorization` used.
- [x] Change `AgentThreadApplyTests`, `PermissionViewHostedTests`, `ThreadAccessibilityTests`, `TaskListViewHostedTests` and the ACP action tests that use these changes.
- [x] Add `addAuthorization` and `removePlan` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [x] No source uses `addAuthorization`, `removePlan` or `AuthorizationPayload`.
- [x] The URL elicitation consent tests and `AgentAuthView` tests pass.
- [x] `swift test` passes.

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.