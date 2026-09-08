---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: todo
position_ordinal: c280
title: 'ConversationView: bottom anchoring, scroll-to-bottom pill, empty state, load earlier (plan §8)'
---
## What
Create `Sources/AgentViewKit/Thread/ConversationView.swift` and `ScrollToBottomPill.swift`, per plan.md §8. `AgentThreadView` replaces its plain `ScrollView` with this view.

- `ConversationView(thread:)`: `ScrollView { LazyVStack { ForEach(thread.items, id: \.id) { ItemRow } } }` with `defaultScrollAnchor(.bottom)`, `scrollPosition`, and `onScrollTargetVisibilityChange` feeding `ScrollAnchorManager.noteVisible(ids:)`.
- On an insert while `isPinnedToBottom` is true, the view calls `requestScrollToBottom()`. While false, the pill shows `newItemsSinceUnpinned`; a tap scrolls to the last id and pins.
- `emptyState` slot (`@ViewBuilder`) shown when `thread.items` is empty.
- "Load earlier" row: the view shows the last `pageSize` items (default 200) and a top row that reveals the previous page. `pageSize` is a modifier `.conversationPageSize(_:)`.
- Accessibility identifiers: `conversation-list`, `scroll-to-bottom-pill`, `load-earlier-row`.

## Acceptance Criteria
- [ ] With 300 items and the default page size, the list shows 200 rows and the load-earlier row; a press shows 300.
- [ ] An insert while pinned leaves the last id visible; while unpinned the pill reads "1 new".
- [ ] A press on the pill pins and hides the pill.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift`: the three cases with the harness and a seeded `ScrollAnchorManager`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.