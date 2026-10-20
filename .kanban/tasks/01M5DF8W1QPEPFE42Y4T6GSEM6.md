---
assignees:
- claude-code
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
position_column: todo
position_ordinal: 8c80
title: 'AVK-8e StatusBar: change the state banners from glass to the content surface'
---
## Why

D110 (b). `StatusBar` draws the banners of `StateBanner`, `SessionStreamBanner` and `AgentConnectionBanner`. These banners show in the thread with the transcript, as the session notice does. They are content, so they have no glass. Only their action button can use a glass button style.

## Files

- `Sources/AgentViewKit/Status/StatusBar.swift` line 83: `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`.
- Keep line 77: the action button keeps `.buttonStyle(.glass)`.
- Users of the bar (no change): `Status/StateBanner.swift:184`, `Status/SessionStreamBanner.swift:92`, `Connections/AgentConnectionBanner.swift:42`.

## What to do

- [ ] Replace line 83 with `agentContentSurface()` (AVK-8b).
- [ ] Keep `symbolColor(for:in:)` (lines 56-58). It reads `\.editorTheme`.

## Acceptance

- `StatusBar.swift` has no `.glassEffect`.
- A test renders a `StatusBar` over a backdrop of one unique color with `RenderedPixels`. No pixel of the backdrop color shows inside the bar.
- All tests in `Tests/AgentViewKitTests/Status/` and `Tests/AgentViewKitTests/Connections/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest.

## Open question

AVK-8 names only `PermissionView` and `SessionNoticeBanner`. This card applies the same rule to the state banners because they are in the same place. Confirm that this is correct. #avk-8