---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dq60xg0gk6r07mqfgxmmmj
  text: |-
    Implementation done. Notes for the next agent:

    - `NoticeRow` (in SessionNoticeBanner.swift) now uses `.agentContentSurface()` and not `.glassEffect`. The Dismiss button keeps `.buttonStyle(.glass)`. The symbol color from `editorTheme.tint(for:)`, the labels, the identifiers and the dismiss action did not change.
    - `WithdrawnNoticeRow` in RequestDeckWithdrawn.swift also shows `NoticeRow`. Thus the notice of a withdrawn request in the request deck is also on the content surface now. Its doc comment said "glass row". The comment is now correct.
    - The shared helpers of ^0047rnq moved to `Tests/AgentViewKitTests/Theme/ContentSurfaceHostedProbe.swift`: `ContentSurfaceHostedProbe` (Reduce Transparency values and `pixels(of:backdrop:reducesTransparency:size:)`), `BackdropPlacement`, and the generic `SurfaceWithBackdrop`. `PermissionCardWithBackdrop` is gone. PermissionViewSurfaceHostedTests uses the shared probe.
    - The new test shows `NoticeBanner`, not `SessionNoticeBanner`, because `SessionNoticeBanner` puts a margin (`spacing.m`) with no surface around its banners. The backdrop in that margin would show.
    - RED: `noPixelOfTheBackdropShowsInsideTheBanner` failed for both Reduce Transparency values with the glass. GREEN after the change.
  timestamp: 2026-10-20T22:33:46.672099+00:00
- actor: claude-code
  id: 01m5dq63t70djmd7pfs63rhnf9
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Status/SessionNoticeBanner.swift, Sources/AgentViewKit/HumanInTheLoop/RequestDeckWithdrawn.swift (doc comment), Tests/AgentViewKitTests/Status/SessionNoticeBannerSurfaceHostedTests.swift (new), Tests/AgentViewKitTests/Theme/ContentSurfaceHostedProbe.swift (new, shared helpers), Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewSurfaceHostedTests.swift (uses shared helpers). `swift test`: 1400 tests in 167 suites passed with 2 known issues (existed before); the mlx bundle warning existed before.
    - next: review
  timestamp: 2026-10-20T22:33:49.639741+00:00
- actor: claude-code
  id: 01m5dqb7cpfzfea4bcmtf3jswx
  text: |-
    ### test — green
    - evidence: swift test — 1400 tests in 167 suites passed, 0 failed, 0 skipped, 2 known issues (as before). Only the old mlx bundle warning is present. No new warnings.
    - next: review
  timestamp: 2026-10-20T22:36:37.142321+00:00
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
position_column: doing
position_ordinal: '80'
title: 'AVK-8d SessionNoticeBanner: change the notice from glass to the content surface'
---
## Why

D110 (b). A session notice shows in the thread above the transcript. It is content, so it has no glass. Only its Dismiss button can use a glass button style.

## Files

- `Sources/AgentViewKit/Status/SessionNoticeBanner.swift` line 195: `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`.
- Keep line 191: the Dismiss button keeps `.buttonStyle(.glass)`.

## What to do

- [x] Replace line 195 with `agentContentSurface()` (AVK-8b).
- [x] Keep the severity symbol color from `editorTheme.tint(for:)` (line 167).
- [x] Do not change the accessibility label, the identifiers or the dismiss action.

## Acceptance

- `SessionNoticeBanner.swift` has no `.glassEffect`.
- A test renders a notice over a backdrop of one unique color with `RenderedPixels`. No pixel of the backdrop color shows inside the notice.
- All tests in `Tests/AgentViewKitTests/Status/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8