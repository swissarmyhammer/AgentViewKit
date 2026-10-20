---
assignees:
- claude-code
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
position_column: todo
position_ordinal: 8b80
title: 'AVK-8d SessionNoticeBanner: change the notice from glass to the content surface'
---
## Why

D110 (b). A session notice shows in the thread above the transcript. It is content, so it has no glass. Only its Dismiss button can use a glass button style.

## Files

- `Sources/AgentViewKit/Status/SessionNoticeBanner.swift` line 195: `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`.
- Keep line 191: the Dismiss button keeps `.buttonStyle(.glass)`.

## What to do

- [ ] Replace line 195 with `agentContentSurface()` (AVK-8b).
- [ ] Keep the severity symbol color from `editorTheme.tint(for:)` (line 167).
- [ ] Do not change the accessibility label, the identifiers or the dismiss action.

## Acceptance

- `SessionNoticeBanner.swift` has no `.glassEffect`.
- A test renders a notice over a backdrop of one unique color with `RenderedPixels`. No pixel of the backdrop color shows inside the notice.
- All tests in `Tests/AgentViewKitTests/Status/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8