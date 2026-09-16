---
comments:
- actor: claude-code
  id: 01m2na3a5t8g7vasgm9qpbg72j
  text: 'Dependency added: ^fetnvp6. The `ExpandedBlocksStore.defaultExpanded` policy uses the type `(ThreadItem) -> Bool`. The type `ThreadItem` is not in the tree. Task ^fetnvp6 (model records) adds it and is not done. This task stays in todo until ^fetnvp6 is done.'
  timestamp: 2026-09-16T14:31:56.346136+00:00
- actor: claude-code
  id: 01m2neb0m5jmmefw6v88mtm2wz
  text: |-
    Research and design decisions (implement, iteration 1):
    - The dependencies ^q4dnn06 and ^fetnvp6 are done. `ThreadItem` (Model/ThreadItem.swift) has `id: String`.
    - `StreamingCoalescer` is the pattern for a `@MainActor` class that holds a stored `Task` handle and cancels it in `isolated deinit`. The scroll coalescer uses the same pattern.
    - Decision: `noteVisible(ids:distanceFromBottom:)`. The ids come from `onScrollTargetVisibilityChange`. The optional `distanceFromBottom` (points, default 0) is the distance from the bottom edge of the last item to the bottom edge of the viewport. The manager is pinned when the last visible id is the last item id and the distance is at most `tolerance`. An empty list is pinned.
    - Decision: the manager learns the last item id through `noteAppended(ids:)`. While pinned, an append requests a scroll to the bottom. While unpinned, an append adds the count of ids to `newItemsSinceUnpinned`.
    - Decision: scroll requests go to an `onScroll: (ScrollAnchorTarget) -> Void` closure with the targets `.bottom` and `.item(id)`. `requestScrollToBottom()` schedules one main-actor task; the calls before it runs do nothing more.
    - Decision: `saveAnchor()` keeps the first visible id. `restoreAnchor()` sends `.item(id)` when the manager is not pinned, and clears the anchor.
    - Decision: `ExpandedBlocksStore` keeps one private `@Observable` state object for each id, so a toggle invalidates only the views that read that id. `isExpanded(_ item:)` applies `defaultExpanded` when no decision is recorded. `seed(_ item:)` records the policy value one time.
  timestamp: 2026-09-16T15:46:03.013543+00:00
- actor: claude-code
  id: 01m2negqkc96gj9zyvvjfbh8hj
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift, Sources/AgentViewKit/Infrastructure/ExpandedBlocksStore.swift, Tests/AgentViewKitTests/Infrastructure/ScrollAnchorManagerTests.swift, Tests/AgentViewKitTests/Infrastructure/ExpandedBlocksStoreTests.swift, Tests/AgentViewKitTests/Helpers/ChangeFlag.swift (moved from the private class in ThreadItemTests.swift so that two suites share it), Tests/AgentViewKitTests/Model/ThreadItemTests.swift
    - test: green — swift test, 391 tests pass (368 AgentViewKitTests + 20 PackageStructureTests + 3 adapter markers), 0 failures, no new warning
    - discovery: the first ExpandedBlocksStore design kept a Bool entry and a separate decided set. A reader of `isExpanded(item)` with policy true was not invalidated by `collapse`, because the entry value was already false. The entry now holds `Bool?` (nil = no decision); a test covers this case.
    - discovery: an `@Observable` nested class cannot be `private`, because the macro adds an extension; it is `fileprivate`.
    - next: commit, then review HEAD~1..HEAD
  timestamp: 2026-09-16T15:49:10.380905+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21A961W19N9FWQ92FETNVP6
position_column: doing
position_ordinal: '8180'
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