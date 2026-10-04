---
assignees:
- claude-code
depends_on:
- 01M443KTS93HHQJREBRF279MDW
position_column: todo
position_ordinal: 8f80
title: Remove addAuthorization, the authorization payload and removePlan
---
## What
No ACP source makes `addAuthorization` or `removePlan`. Authorization through the catalog payload was the Router model (update.md §6). The ACP auth flow (`authMethods`, login, logout) stays, and `AgentAuthView` stays.

- [ ] Remove `addAuthorization` and `removePlan` from `ThreadChange` and their apply code from `AgentThread`.
- [ ] Delete `Sources/AgentViewKit/Catalog/AuthorizationPayload.swift` (if the catalog task left it) and remove `AuthorizationPayload.elicitationId`. Examine `Sources/AgentViewKit/Model/Requests/AuthorizationRequest.swift`, `Connections/AuthorizationView.swift` and `Connections/AuthorizationPresenter.swift`: keep the parts that the URL elicitation consent (`ElicitationURLConsentView`) uses; remove the parts that only `addAuthorization` used.
- [ ] Change `AgentThreadApplyTests`, `PermissionViewHostedTests`, `ThreadAccessibilityTests`, `TaskListViewHostedTests` and the ACP action tests that use these changes.
- [ ] Add `addAuthorization` and `removePlan` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [ ] No source uses `addAuthorization`, `removePlan` or `AuthorizationPayload`.
- [ ] The URL elicitation consent tests and `AgentAuthView` tests pass.
- [ ] `swift test` passes.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.