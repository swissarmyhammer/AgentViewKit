---
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21AHDHY0H7A92PP2KTRTZEZ
position_column: todo
position_ordinal: b980
title: 'BranchNavigator: regenerate and branch paging with a branch model on AgentThread (plan §9 A)'
---
## What
Create `Sources/AgentViewKit/Model/Branches.swift` and `Sources/AgentViewKit/Items/BranchNavigator.swift`, per plan.md §9 A.

- Branch model: `AgentThread.branches: [String: BranchSet]` keyed by the user message id. `BranchSet { alternatives: [[ThreadItem]]; selectedIndex: Int }`. `ThreadChange.addBranch(afterUserMessage:, items:)` and `.selectBranch(afterUserMessage:, index:)`. Selecting a branch swaps the items after that user message in `items`.
- `BranchNavigator(messageID:)`: a small "< 2 / 3 >" control in the assistant message footer when a branch set exists, and a Regenerate button on the last assistant message that calls `send` with the prior user input and records the old items as a branch.
- Sources: the ACP source has no branch wire; the kit keeps branches local. The FoundationModels source can branch by `Transcript` rewrite; that lands with the checkpoint task.

## Acceptance Criteria
- [ ] Adding a branch and selecting index 1 swaps the trailing items.
- [ ] The navigator is absent without a branch set and shows "1 / 2" with one alternative.
- [ ] Regenerate calls `send` with the prior user input.

## Tests
- [ ] `Tests/AgentViewKitTests/Model/BranchesTests.swift`: add and select.
- [ ] `Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift`: presence, label, regenerate through `NoopThreadActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.