---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: todo
position_ordinal: a880
title: 'ThreadMinimapView: scrubbable rail of turns, tool calls, and errors (plan §9 A)'
---
## What
Create `Sources/AgentViewKit/Thread/ThreadMinimapView.swift`, per plan.md §9 A.

- A thin vertical rail beside the conversation. One tick per item, tinted by kind (user, assistant, reasoning, tool call by status, error). The current viewport is a translucent band computed from `ScrollAnchorManager.visibleIDs`.
- Click or drag on the rail scrolls the conversation to the item under the pointer, through `ScrollViewProxy`, and sets `ScrollAnchorManager.anchorID`.
- Hidden below a configurable item count and when the window is narrow.
- Accessibility: the rail is one element with identifier `thread-minimap` and value "Item N of M", with an adjustable action that steps items. Under `#if DEBUG`, each tick is also an element with identifier `minimap-tick-<kind>` so tests can count them.

## Acceptance Criteria
- [ ] Twenty items produce twenty `minimap-tick-*` elements, and the count per kind equals the count of items per kind.
- [ ] A click at the vertical middle of the rail sets `anchorID` to the middle item's id.
- [ ] The value reads "Item 5 of 20" when `visibleIDs` starts at the fifth item.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/ThreadMinimapViewHostedTests.swift`: the three cases with a seeded `ScrollAnchorManager`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.