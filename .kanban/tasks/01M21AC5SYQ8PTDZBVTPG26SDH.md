---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: todo
position_ordinal: '8880'
title: ScrollAnchorManager and ExpandedBlocksStore (plan §8, §9 C2)
---
## What
Create `Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift` and `ExpandedBlocksStore.swift`, per plan.md §8.

- `ScrollAnchorManager` (`@MainActor @Observable`): `isPinnedToBottom` with a tolerance in points, `anchorID: String?` saved before a list update and restored after, `visibleIDs: [String]` (the ids in view, in order), `newItemsSinceUnpinned: Int` for the scroll-to-bottom pill, `requestScrollToBottom()` coalesced to one request per tick, and `noteVisible(ids:)` fed from `onScrollTargetVisibilityChange`, which also sets `visibleIDs`.
- `ExpandedBlocksStore` (`@MainActor @Observable`): a set of expanded item ids with `isExpanded(id)`, `toggle(id)`, `expand(id)`, `collapse(id)`, and a `defaultExpanded: (ThreadItem) -> Bool` policy. Kept out of the row views so a toggle does not invalidate the list.

## Acceptance Criteria
- [ ] `noteVisible` with the last id inside the tolerance sets `isPinnedToBottom` true; outside sets false; `visibleIDs` equals the ids passed.
- [ ] While unpinned, each appended id increments `newItemsSinceUnpinned`; pinning resets it to zero.
- [ ] Ten `requestScrollToBottom()` calls in one tick produce one scroll callback.
- [ ] `ExpandedBlocksStore.toggle` flips only the given id.

## Tests
- [ ] `Tests/AgentViewKitTests/Infrastructure/ScrollAnchorManagerTests.swift`: pin, unpin, visible ids, count, coalesce, anchor save and restore.
- [ ] `Tests/AgentViewKitTests/Infrastructure/ExpandedBlocksStoreTests.swift`: toggle and default policy.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.