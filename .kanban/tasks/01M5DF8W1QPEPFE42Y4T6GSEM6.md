---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dqfbn7cbbcfqy6gftp6kgz
  text: |-
    Research done.
    - `StatusBar.body` puts the bar on `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`. The action button uses `.buttonStyle(.glass)`. Keep the button style.
    - The users of the bar are `StateBanner`, `SessionStreamBanner` and `AgentConnectionBanner`. They do not change.
    - The test uses the shared probe `ContentSurfaceHostedProbe` (Tests/AgentViewKitTests/Theme/ContentSurfaceHostedProbe.swift), as `SessionNoticeBannerSurfaceHostedTests` (^ar6mvjr) does. The bar shows `SessionStreamBanner.missedUpdatesMessage` with a Reload action, so the glass button is in the render.
    - Open question of the card: the instruction of the dispatcher applies the D110 (b) rule to the state banners. This work follows that instruction.
  timestamp: 2026-10-20T22:38:52.583300+00:00
- actor: claude-code
  id: 01m5dqqsg590dcx5601a6thw0n
  text: |-
    Implementation landed.
    - `StatusBar.body` now uses `.agentContentSurface()` in place of `.glassEffect(...)`. The action button keeps `.buttonStyle(.glass)`. `symbolColor(for:in:)` did not change.
    - The doc comment of `StatusBar` tells that the bar is content on the content surface (D110 (b)), and names `AgentConnectionBanner` as a user. The doc comment of `StateBanner` said "A glass bar"; it now tells that the bar is a `StatusBar` on the content surface.
    - New test `Tests/AgentViewKitTests/Status/StatusBarSurfaceHostedTests.swift` uses `ContentSurfaceHostedProbe`. It shows the bar with `SessionStreamBanner.missedUpdatesMessage` and a Reload button, so the glass button is in the render. RED before the change: `noPixelOfTheBackdropShowsInsideTheBar` failed for Reduce Transparency off and on (2 issues). The control test `theBackdropShowsWhenItIsInFrontOfTheBar` passed. GREEN after the change.
    - Note: a failed pixel expectation prints the full pixel buffer (several MB of output). Filter the output of `swift test` when you read it.
  timestamp: 2026-10-20T22:43:28.901877+00:00
- actor: claude-code
  id: 01m5dqqvh7grth77we82ckspjf
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Status/StatusBar.swift, Sources/AgentViewKit/Status/StateBanner.swift (doc comment), Tests/AgentViewKitTests/Status/StatusBarSurfaceHostedTests.swift (new). `swift test`: 1402 tests in 168 suites passed with 2 known issues; 137 tests in 19 suites passed; mlx bundle warning only (all existed before).
    - next: /review
  timestamp: 2026-10-20T22:43:30.983700+00:00
- actor: claude-code
  id: 01m5dqx0ze8ber7vedwxk5r4em
  text: |-
    ### test — green
    - evidence: swift test — 1402 tests in 168 suites passed, 0 failed, 0 skipped, 2 known issues (existed before). Only warning: the mlx bundle build warning (existed before).
    - next: review
  timestamp: 2026-10-20T22:46:20.398910+00:00
- actor: claude-code
  id: 01m5dqx1p40s03eqvnehzz73dc
  text: 'testudoapp-4c confirmed (AVK-8 Decisions for the plan, item 4): status banners, errors, compaction entries and the sign-in view are content. They use materials, not glass.'
  timestamp: 2026-10-20T22:46:21.124487+00:00
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
position_column: doing
position_ordinal: '80'
title: 'AVK-8e StatusBar: change the state banners from glass to the content surface'
---
## Why

D110 (b). `StatusBar` draws the banners of `StateBanner`, `SessionStreamBanner` and `AgentConnectionBanner`. These banners show in the thread with the transcript, as the session notice does. They are content, so they have no glass. Only their action button can use a glass button style.

## Files

- `Sources/AgentViewKit/Status/StatusBar.swift` line 83: `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`.
- Keep line 77: the action button keeps `.buttonStyle(.glass)`.
- Users of the bar (no change): `Status/StateBanner.swift:184`, `Status/SessionStreamBanner.swift:92`, `Connections/AgentConnectionBanner.swift:42`.

## What to do

- [x] Replace line 83 with `agentContentSurface()` (AVK-8b).
- [x] Keep `symbolColor(for:in:)` (lines 56-58). It reads `\.editorTheme`.

## Acceptance

- `StatusBar.swift` has no `.glassEffect`.
- A test renders a `StatusBar` over a backdrop of one unique color with `RenderedPixels`. No pixel of the backdrop color shows inside the bar.
- All tests in `Tests/AgentViewKitTests/Status/` and `Tests/AgentViewKitTests/Connections/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest.

## Open question

AVK-8 names only `PermissionView` and `SessionNoticeBanner`. This card applies the same rule to the state banners because they are in the same place. Confirm that this is correct. #avk-8