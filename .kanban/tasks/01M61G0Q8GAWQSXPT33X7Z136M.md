---
assignees:
- claude-code
position_column: todo
position_ordinal: b180
title: 'Snapshots capture the real window from the window server: drop the compositing renderer, LayerTreeRenderer and VibrantLabelFilters (after EditorKit''s real-capture helper)'
---
User decision, relayed by editorkit-a9, for every view kit: "we need all the view kit sessions to adopt this proper approach, building your own renderer is just a horrible idea, it doesn't prove that our app will really work". The EditorKit gallery, built from AVK's compositing renderer, drew backward text in every screenshot, and the real UI never does that.

## Rule
Screenshots and snapshots capture the real UI. The view is mounted in a real on-screen window, key and frontmost. The window's actual pixels come from the window server, through ScreenCaptureKit `SCScreenshotManager.captureImage` with `SCContentFilter(desktopIndependentWindow:)`, or through XCUITest screenshots for the demo app. Nothing rebuilds the image: no CARenderer layer-tree compositing, LayerTreeRenderer, VibrantLabelFilters, ImageRenderer, or cacheDisplay stand-ins. EditorKit style.md "Review gallery" and rule 9 will say this.

## Work, after EditorKit's revised ^p9rqatc lands with its real-capture helper
- [ ] Move every AVK snapshot and gallery test (HostedSnapshotTests, GlassSnapshotTests, the review gallery screens and the pixel checks such as RegionColors and the CompositedSnapshotTests family) to the shared real-capture helper
- [ ] Delete ViewSnapshot's composited path (path C), the cacheDisplay and ImageRenderer paths used as stand-ins, LayerTreeRenderer.swift, VibrantLabelFilters.swift and their tests, with no shims. Delete tests that only existed to prove the stand-in renderers.
- [ ] Real windows come to the front, so every test that captures takes the shared UI-test lock. Check that the full `swift test` runs under it.
- [ ] Screen Recording permission for the test runner: record how it's granted on this machine, and fail clearly, never skip, when it's missing.
- [ ] Re-record every reference PNG from real captures, light and dark only, and regenerate the gallery
- [ ] A package-structure test forbids CARenderer, `cacheDisplay(`, `ImageRenderer(` and LayerTreeRenderer in the test support and tests
- [ ] `swift test` is green

Blocked on the EditorKit ^p9rqatc revision (real-capture helper).