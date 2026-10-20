---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5d95pd121am9ttzhmhkkf88
  text: |-
    Research:
    - EditorKit `.commandScope(segment:subject:)` writes `contributeSubject(segment, subject)` as the `.scope` part of the node. `@FromTarget(kind:)` reads it from the fold: payload target > clicked > focused, then `fold.subject(for:)`. The subject must be `Sendable`: `SessionModel` (MainActor class), `TranscriptEntry` and `PendingPermissionRequest` are.
    - Problem found: `AgentCommandRegistration.register` writes `ScopeNode(path:isLayer:contribution: prior?.contribution)`. That copies the `.scope` part of the beacon into the `.host` part on each update. The copy holds an old subject, and the closure chain grows on each update. Plan: write the node with `ScopeTree.merging(nil, by: .host, at:)`, so the `.scope` part with the live subject stays.
    - Problem found: with no ambient `CommandSystem`, the scope uses a private system, but `.commandScope` reads `\.commandSystem` from the environment. Thus the item scopes register no node and no subject in the private system. Plan: install the system of the scope with `.commandSystem(system)` outside its `.commandScope`, so Copy Message in a context menu keeps working with the private system.
    - Headless tests (`CommandSystemHarness`) have no views. The tests that run a command at an item path must give the item scope with its subject, as the views do.
  timestamp: 2026-10-20T18:28:55.841524+00:00
- actor: claude-code
  id: 01m5d9jntvcjn6m2cz5a8hqwjb
  text: |-
    Implementation landed:
    - `AgentCommandScope` uses `.commandScope(segment:subject: session)` and installs its system with `.commandSystem(system)` outside it. Without that install, the private system got no item node, and Copy Message in the context menu failed (a test shows the failure).
    - `AgentItemScope<Subject>` / `agentItemScope(_:subject:)`: a message row gives `MessageEntry.transcriptEntry` (new internal property, the same object as a `TranscriptEntry`), a request card gives its `PendingPermissionRequest`.
    - `AgentCommand` has `@FromTarget(kind: AgentScopeKind.message) var message: TranscriptEntry?` and `@FromTarget(kind: AgentScopeKind.request) var request: PendingPermissionRequest?`. `payload(at:)` (read the segment id text) is gone; the private `itemPayload` puts the row key or the request id of the live subject under the payload key when the payload names no item. An explicit payload key still wins.
    - `AgentCommandRegistration.register` writes the node with `ScopeTree.merging(nil, by: .host, at:)`. The old code copied the `.scope` part into `.host` on each update: a stale subject stayed after the scope part went, and the closure chain grew. A headless test fails on the old code.
    - Test change: the headless harness has no views, so `AgentCommandsTests.makeFixture(session:items:configure:)` takes the item scopes with their subjects (`messageItems(of:)`, `requestItems(of:)`). Two AgentCommandPlacementTests (copy message, approve in a card) give the items, as the views do. Their assertions did not change.
    - New `Tests/AgentViewKitTests/Commands/AgentScopeSubjectHostedTests.swift`: a probe command of the test module reads the message entry (`===` the transcript object), the session model and the pending request through `@FromTarget` in a mounted thread; and Copy Message works with the private system.
  timestamp: 2026-10-20T18:36:01.243526+00:00
- actor: claude-code
  id: 01m5d9jt1be5bn16h4mqe96edx
  text: |-
    ### implement — changed
    - evidence: 10 files — Sources/AgentViewKit/Commands/{AgentCommandScope,AgentItemScope,AgentCommands,AgentCommandPlacement}.swift, Sources/AgentViewKit/Items/{MessageItemView,TranscriptMessageView}.swift, Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift, Tests/AgentViewKitTests/Commands/{AgentCommandsTests,AgentCommandPlacementTests,AgentScopeSubjectHostedTests (new)}.swift. `swift test`: 1348 tests in 158 suites passed (2 known issues that were there before), 129 package structure tests passed.
    - next: /review
  timestamp: 2026-10-20T18:36:05.547964+00:00
- actor: claude-code
  id: 01m5d9pv20swm11ccrm71ag30f
  text: |-
    ### test — green
    - evidence: swift test — 1348 tests in 158 suites passed, 0 failed, 2 known issues (existed before). 1 warning only: the mlx bundle build warning (existed before). No new warning. No skipped test.
    - next: review
  timestamp: 2026-10-20T18:38:17.664461+00:00
- actor: claude-code
  id: 01m5d9ts75q9fxjrsjmnb29bby
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 0d1e86e). 0 findings, 0 confirmed, 0 refuted. 10 files reviewed. 4 .kanban files not reviewed because .reviewignore excludes them.
    - next: The task is in done. No more work for this step.
  timestamp: 2026-10-20T18:40:26.853614+00:00
- actor: claude-code
  id: 01m5d9v2m9xxqy1f981wha911s
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 10 files
    - test: green — swift test, 1348 passed, 2 known issues that were there before
    - commit: 0d1e86e
    - review: clean — 0 findings
  timestamp: 2026-10-20T18:40:36.489008+00:00
position_column: done
position_ordinal: fff180
title: AVK-7b Live subject on each agent scope
---
Design: AVK-7, D105 (b). Step 5 work.

Today the scopes call `.commandScope(segment:)` with no subject (Commands/AgentCommandScope.swift:70, Commands/AgentItemScope.swift:28). `AgentCommand.payload(at:)` (Commands/AgentCommands.swift:208) reads the item from the text of the segment id.

Do:
- Each scope gives its live object with `.commandScope(segment:subject:)`: the thread scope gives the `SessionModel`, a message scope gives its transcript entry, a request scope gives its `PendingPermissionRequest`.
- The agent commands read the item with `@FromTarget` (or the context subject), not from the segment id text. Keep the payload keys for hosts that dispatch by id.
- Keep the behavior of AVK-1: Copy Message copies the message of its scope, Approve and Reject answer the request of their scope.

Acceptance: the AgentCommandPlacementTests still pass; a new test shows that a command registered by another module (a test scope) reads the message entry through `@FromTarget` at an `agentMessage` path. #avk-7