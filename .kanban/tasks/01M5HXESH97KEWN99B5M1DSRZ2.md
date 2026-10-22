---
assignees:
- claude-code
position_column: todo
position_ordinal: 9f80
title: 'AVK-14a Add #Preview blocks for StatusBar and AgentLoginPrompt'
---
## Goal

The user examines the look of each component in the Xcode canvas. These views have no `#Preview`:

- `Sources/AgentViewKit/Status/StatusBar.swift` — `StatusBar`
- `Sources/AgentViewKit/Connections/AgentLoginPrompt.swift` — `AgentLoginPrompt`

## Change

Add `#Preview` blocks in the same file as each view. Use the shared data in `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`. Add to it if a value is missing. Give each preview a name that tells its state.

Show the states that are hard to get right:

- [ ] `StatusBar`: each status, a long status text, and the bar with its buttons.
- [ ] `AgentLoginPrompt`: each sign-in method, a long agent name, and the card in the bottom bar of `AgentThreadView` over scrolled content (the glass buttons of ^26aevxf).

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- A preview uses no network, no real agent and no file outside a temporary directory.
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14