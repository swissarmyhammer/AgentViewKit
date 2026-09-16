---
comments:
- actor: claude-code
  id: 01m2nwhmtr9g16hgn62bca5jmj
  text: 'Note from ^apwfm0s (ErrorView): ConversationView must mount `StateBanner(state:errorID:onShowError:)` with `errorID` set to the id of the newest `.error` item (a `ThreadError`) that relates to the stop reason, and an `onShowError` closure that scrolls to the row of that id (`ItemRow` identifier `item-row-<id>`; the card has identifier `error-<case>`). ConversationView must also pass the host `ErrorActions` through `.errorActions(_:)` when the host gives them. With no actions, an error card shows no button.'
  timestamp: 2026-09-16T19:54:20.376121+00:00
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