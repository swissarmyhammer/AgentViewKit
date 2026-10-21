---
assignees:
- claude-code
depends_on:
- 01M5E8SRKB36TVJNFAE2F1ARB7
position_column: todo
position_ordinal: ad80
title: 'AVK-8aj Accent in content, part 1: decorative symbols use a semantic style, not editorTheme.accent (AgentInfoHeader.swift:51, ConversationEmptyState.swift:142, StatusBar.swift:62) (D113 answer 5)'
---
## Why

D113 answer 5 and `style.md` "Tint": "In content, the theme accent marks only a link, the selection or the current item." These three symbols are decoration. They are not a link, the selection or the current item.

## Files and lines

- `Sources/AgentViewKit/Connections/AgentInfoHeader.swift:51`: the agent symbol, `.foregroundStyle(editorTheme.accent)`.
- `Sources/AgentViewKit/Thread/ConversationEmptyState.swift:142`: the empty-state symbol, `.foregroundStyle(editorTheme.accent)`.
- `Sources/AgentViewKit/Status/StatusBar.swift:61-63`: `symbolColor(for:in:)` gives `theme.accent` for a message that is not a failure.

## What to do

- [ ] `AgentInfoHeader.swift:51`: use `.foregroundStyle(.secondary)`.
- [ ] `ConversationEmptyState.swift:142`: use `.foregroundStyle(.secondary)`.
- [ ] `StatusBar.swift:61-63`: a failure keeps `theme.severityError` (a status color of the theme, D112). Other messages use `Color.secondary`. Change the return type or the doc comment if necessary.
- [ ] Remove `@Environment(\.editorTheme)` from a view when it has no other use.

## Acceptance

- A unit test: `StateBanner.symbolColor(for:in:)` (or its new name) gives `theme.severityError` for a failure message and `Color.secondary` for each other message, with `DistinctRolesTheme`.
- A render test of `AgentInfoHeader` and of `ConversationEmptyState` with `DistinctRolesTheme` finds no pixel of the accent role (`RenderedPixels`, light mode).
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8