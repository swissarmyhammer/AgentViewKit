---
comments:
- actor: claude-code
  id: 01m2ntskhr4rqz15266yqyvw8s
  text: |-
    ### implement — changed
    Decisions (plan.md §9 A, no question to the user):
    - `ScrollAnchorManager` gets `noteJump(to:)`. It sets `anchorID` and sends no scroll, because `anchorID` is `private(set)`. The rail scrolls with the `ScrollViewProxy`. With no proxy, the rail sends `.item(id)` to `onScroll`.
    - The rail gets clicks and drags from a clear AppKit view (`ScrubSurface`), not from a SwiftUI `DragGesture`. A SwiftUI gesture did not get the mouse events that the hosted test sends. An AppKit view gets them from `NSWindow.sendEvent`.
    - The rail element has the static text trait, because an element with no role gives no value.
    - The narrow window rule is in the modifier `View.threadMinimap(thread:anchors:proxy:minimumItemCount:minimumWidth:)`. It measures the width of the conversation. Defaults: 10 items, 480 points.
    - Tick kinds: system, user, assistant, reasoning, tool-call, structured, compaction, error, unknown. A tool call tick uses the status color of the theme.
    - `AgentThreadView` does not show the rail yet. The later `ConversationView` task owns the `ScrollViewReader` and applies `.threadMinimap`.
    - evidence: `timeout 900 swift test --filter AgentViewKitTests`: 611 tests in 51 suites passed, 0 warnings from the package.
    - next: commit, then review HEAD~1..HEAD.
  timestamp: 2026-09-16T19:23:44.056398+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: doing
position_ordinal: '8180'
title: 'ThreadMinimapView: scrubbable rail of turns, tool calls, and errors (plan §9 A)'
---
## What
Create `Sources/AgentViewKit/Thread/ThreadMinimapView.swift`, per plan.md §9 A.

- A thin vertical rail beside the conversation. One tick per item, tinted by kind (user, assistant, reasoning, tool call by status, error). The current viewport is a translucent band computed from `ScrollAnchorManager.visibleIDs`.
- Click or drag on the rail scrolls the conversation to the item under the pointer, through `ScrollViewProxy`, and sets `ScrollAnchorManager.anchorID`.
- Hidden below a configurable item count and when the window is narrow.
- Accessibility: the rail is one element with identifier `thread-minimap` and value "Item N of M", with an adjustable action that steps items. Under `#if DEBUG`, each tick is also an element with identifier `minimap-tick-<kind>` so tests can count them.

## Acceptance Criteria
- [x] Twenty items produce twenty `minimap-tick-*` elements, and the count per kind equals the count of items per kind.
- [x] A click at the vertical middle of the rail sets `anchorID` to the middle item's id.
- [x] The value reads "Item 5 of 20" when `visibleIDs` starts at the fifth item.

## Tests
- [x] `Tests/AgentViewKitTests/Thread/ThreadMinimapViewHostedTests.swift`: the three cases with a seeded `ScrollAnchorManager`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.