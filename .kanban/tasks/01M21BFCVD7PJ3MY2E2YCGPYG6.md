---
comments:
- actor: claude-code
  id: 01m2nw5ee73sp979xthje4p7r6
  text: 'Note from ^hpprm0t (CheckpointView): that task added `Checkpoint`, `AgentThread.checkpoints`, `ThreadChange.setCheckpoints`, and the `CheckpointActions` protocol only. It did not add a FoundationModels or Router source that rewrites the transcript. The description of this task says that the transcript rewrite "lands with the checkpoint task". That is not true now. This task must add the source-side branch, or a new task must add it. `ThreadChange.clear` removes the checkpoints; a branch swap must not send `.clear`.'
  timestamp: 2026-09-16T19:47:40.615429+00:00
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