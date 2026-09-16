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
- actor: claude-code
  id: 01m2nv1a7s35d16n23whwmfk0p
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ThreadMinimapView.swift, ScrollAnchorManager.swift, two test files
    - test: green — `timeout 900 swift test --filter AgentViewKitTests`, 611 passed
    - commit: d8db892
    - review: findings — Sources/AgentViewKit/Thread/ThreadMinimapView.swift:316 (duplication/duplication)

    ### implement — changed (fix for the finding)
    - The ToolCallStatus to Color mapping is now `AgentTheme.StatusColors.color(for:)`. ThreadMinimapView calls it. The private `statusTint` function is removed. New test: `Tests/AgentViewKitTests/Theme/StatusColorsTests.swift`.
    - The other matches (ConnectionStatusChip, SubagentTreeView, Plan, SessionEventMapping, SubagentMapping) do not map ToolCallStatus to Color. They map ConnectionState, SubagentRun state, or wire strings. Thus they cannot call a ToolCallStatus function. The later ToolCallView task must call `color(for:)`.
    - test: green — 612 tests in 52 suites passed.
  timestamp: 2026-09-16T19:27:56.665167+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: review
position_ordinal: '80'
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

## Review Findings (2026-09-16 14:23)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Thread/ThreadMinimapView.swift:316` `duplication/duplication` — The statusTint function replicates a ToolCallStatus-to-Color mapping that exists in multiple places. Very high similarity (0.92) to ConnectionStatusChip and similar patterns (0.87) in Plan, SessionEventMapping, and SubagentMapping. Extract to a shared utility to prevent drift across multiple implementations. Extract the ToolCallStatus-to-Color mapping to a shared utility function (e.g., on AgentTheme or a dedicated StatusColorMapping helper). Call it from ThreadMinimapView:316-326 and update the four existing similar implementations to use the shared version.
