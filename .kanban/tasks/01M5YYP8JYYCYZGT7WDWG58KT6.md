---
assignees:
- claude-code
position_column: todo
position_ordinal: a880
title: 'Tests: GlassAccessibilityTests walks the pixel columns of a row by hand; reuse RegionColors'
---
Found while fixing the reuse finding of ^sbx2q4h. `RegionColors` (Tests/AgentViewKitTests/Snapshots/RegionColors.swift) is now the one walk over the pixels of a region in the test target: `contains(_:in:of:tolerance:)` and `columns(of:in:)` sit on the same pixel enumeration as `colors(of:in:)`.

`Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift` still strides by hand over the pixel centers of one row (`stride(from: step / 2, to: view.size.width, by: step)`, where `step` is `1 / RenderedPixels.renderScale`) and tests each one with `RenderedPixels.contains(_:at:)`. Replace that walk with the `RegionColors` enumeration, for example `RegionColors.columns(of:in:)` over a one-row region plus `RegionColors.contains`, so that region sampling lives in one place. Do not modify Sources/AgentViewKitTestSupport, because EditorKit is moving those helpers.

Test: the existing GlassAccessibilityTests stay green with the same counts.
#avk-8