---
comments:
- actor: claude-code
  id: 01m2nw5ee73sp979xthje4p7r6
  text: 'Note from ^hpprm0t (CheckpointView): that task added `Checkpoint`, `AgentThread.checkpoints`, `ThreadChange.setCheckpoints`, and the `CheckpointActions` protocol only. It did not add a FoundationModels or Router source that rewrites the transcript. The description of this task says that the transcript rewrite "lands with the checkpoint task". That is not true now. This task must add the source-side branch, or a new task must add it. `ThreadChange.clear` removes the checkpoints; a branch swap must not send `.clear`.'
  timestamp: 2026-09-16T19:47:40.615429+00:00
- actor: claude-code
  id: 01m2q81a9p2fcwfnjqmmz3gwm9
  text: |-
    ### finish iteration 1 — findings
    - implement: added the local branch model (Branches.swift, AgentThread.branches, ThreadChange.addBranch and .selectBranch) and BranchNavigator. Decision: the kit keeps branches local; the source-side branch is the new task ^5y246w4.
    - test: swift test exit 0. AgentViewKitTests 1261, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. No new warnings.
    - commit: 284bc00
    - review: 1 finding (swift/access-control on BranchNavigator.swift:50).
  timestamp: 2026-09-17T08:34:22.646592+00:00
- actor: claude-code
  id: 01m2q8da9m9r9m9tg82gx1mwrr
  text: |-
    ### finish iteration 2 — findings
    - implement: gave each new member in BranchNavigator.swift, Branches.swift and AgentThread.swift an explicit access modifier (fix for the 03:28 finding).
    - test: swift test exit 0. AgentViewKitTests 1261, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. No new warnings.
    - commit: 6545e16
    - review: 1 new finding (swift/access-control on BranchNavigator.swift:53, input property `messageID` must be `internal`). Fixed: `internal let messageID`; tests pass again (same counts).
  timestamp: 2026-09-17T08:40:55.860824+00:00
- actor: claude-code
  id: 01m2q8m5wf1hv3pxs55cmd4w8z
  text: |-
    ### finish iteration 3 — findings
    - implement: `messageID` changed to `internal let` (fix for the 03:36 finding).
    - test: swift test exit 0. AgentViewKitTests 1261, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. No new warnings.
    - commit: 4a57bfa
    - review: 1 new finding (swift/access-control on BranchNavigator.swift:53, an input property must have no explicit `internal`). This finding is different from the 03:36 finding, which permitted both forms. Fixed: `let messageID: String`. The other internal members keep the explicit modifier (03:28 rule). Tests pass again (same counts).
  timestamp: 2026-09-17T08:44:40.719625+00:00
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21AHDHY0H7A92PP2KTRTZEZ
position_column: review
position_ordinal: '80'
title: 'BranchNavigator: regenerate and branch paging with a branch model on AgentThread (plan §9 A)'
---
## What
Create `Sources/AgentViewKit/Model/Branches.swift` and `Sources/AgentViewKit/Items/BranchNavigator.swift`, per plan.md §9 A.

- Branch model: `AgentThread.branches: [String: BranchSet]` keyed by the user message id. `BranchSet { alternatives: [[ThreadItem]]; selectedIndex: Int }`. `ThreadChange.addBranch(afterUserMessage:, items:)` and `.selectBranch(afterUserMessage:, index:)`. Selecting a branch swaps the items after that user message in `items`.
- `BranchNavigator(messageID:)`: a small "< 2 / 3 >" control in the assistant message footer when a branch set exists, and a Regenerate button on the last assistant message that calls `send` with the prior user input and records the old items as a branch.
- Sources: the ACP source has no branch wire; the kit keeps branches local. The FoundationModels source can branch by `Transcript` rewrite; that lands with the checkpoint task.

## Acceptance Criteria
- [x] Adding a branch and selecting index 1 swaps the trailing items.
- [x] The navigator is absent without a branch set and shows "1 / 2" with one alternative.
- [x] Regenerate calls `send` with the prior user input.

## Tests
- [x] `Tests/AgentViewKitTests/Model/BranchesTests.swift`: add and select.
- [x] `Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift`: presence, label, regenerate through `NoopThreadActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-17 03:28)

- [x] `Sources/AgentViewKit/Items/BranchNavigator.swift:50` `swift/access-control` — The static constant `regenerateSymbol` lacks an explicit access modifier. On a public struct, internal members need explicit marking to clarify they are not part of the public API. This is inconsistent with the adjacent `private let logger` on line 59, which is explicitly marked. Change line 50 to `private static let regenerateSymbol = "arrow.trianglehead.2.clockwise"`.

## Review Findings (2026-09-17 03:36)

- [x] `Sources/AgentViewKit/Items/BranchNavigator.swift:53` `swift/access-control` — Input property `messageID` should be `internal`, not `private`. SwiftUI views should keep input properties (those passed via `init` parameters) at `internal` access level and reserve `private` for dynamic properties like `@State` and `@Environment`. Making an input property `private` forces an unnecessary hand-written `init` that merely assigns the parameter to the property. Change `private let messageID: String` to `internal let messageID: String` or remove the access modifier entirely to use the default `internal`.

## Review Findings (2026-09-17 03:41)

- [x] `Sources/AgentViewKit/Items/BranchNavigator.swift:53` `swift/access-control` — SwiftUI view input properties should be implicitly internal, not explicitly marked with the `internal` modifier. The explicit keyword is redundant and violates the idiomatic form for SwiftUI views. Change `internal let messageID: String` to `let messageID: String` to follow SwiftUI idiom.