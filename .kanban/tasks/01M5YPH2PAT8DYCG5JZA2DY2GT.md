---
assignees:
- claude-code
position_column: todo
position_ordinal: a280
title: 'AVK-8 diff file list: make the added and removed counts readable in light (finding of ^8q34yt8)'
---
Found by the review gallery of ^8q34yt8 (2026-10-27).
- Screen: `thread`. Variant: light. PNG: `~/Library/Caches/AgentViewKit/screenshot-check/thread--light.png`.
- View: the file list of `DiffView` in the expanded "Edit SearchIndex.swift" tool call: the row "SearchIndex.swift +1 −1".

What the image shows: the count `+1` is drawn in `diffAddedText` (RGB 34c759) on the selected row (RGB eeeeee): a contrast of 1.9:1 (2.2:1 on the window background). The count `−1` in `diffRemovedText` (RGB ff383c) is 3.1:1. Both are below the system secondary label color (3.9:1). In dark both counts read well (6.8:1 and more).

File: `Sources/AgentViewKit/Diff/DiffView.swift` (the file row with `Text(verbatim: "+\(file.added)")` and `Text(verbatim: "\u{2212}\(file.removed)")`).

What to change: draw the two numbers in `.secondary`, and keep the added and removed colors on a small mark beside them (for example the plus and minus symbols), so that the numbers reach the contrast of secondary text in light and dark.

Deterministic test: a hosted test renders `DiffView(diff:)` for `PreviewFixtures.smallPatch` with `ViewSnapshot.hostedPixels` in the light variant. In the accessibility frame of the count text, no pixel is close to `diffAddedText` or `diffRemovedText`. No clock and no wait.
#avk-8