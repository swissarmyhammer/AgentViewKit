---
assignees:
- claude-code
position_column: todo
position_ordinal: a580
title: 'AVK-8 diff: file chips in a row above, the file content full width below; drop the side-by-side layout (user review of the gallery)'
---
## Why

The user's review of the review gallery (2026-10-27), verbatim: "the file diff display should have the file chips above and the file content below -- the current version with half width diff wastes space needlessly".

Today, `Sources/AgentViewKit/Diff/DiffView.swift:206-217` uses `ViewThatFits(in: .horizontal)`. It prefers an `HStack` with the file list in a fixed column (`fileListWidth`) beside the detail (`rendererMinWidth`), and falls back to a VStack with the full-width list rows on top. In the transcript the HStack wins, so the patch gets only part of the width.

Screens: `~/Library/Caches/AgentViewKit/screenshot-check/thread--light.png` and `thread--dark.png`. Regenerate them with `swift test --filter ReviewGallery`.

## What to do

- [ ] Remove the `ViewThatFits` and the side-by-side layout. The view is always a VStack: the file chips first, then the detail (header plus patch) at full width.
- [ ] Draw the files as chips in a wrapping flow (a SwiftUI `Layout` that wraps to the next line, or an existing kit flow layout if there is one). Each chip shows the operation symbol, the file name (middle truncation, full path in `.help`) and the +/− counts when there is a patch. Keep each chip a plain button that selects its file, with `selectableSurface` for the selected chip. Keep the accessibility identifiers and the jump scopes of the rows.
- [ ] Remove `fileListWidth`, and `rendererMinWidth` if nothing else uses it.
- [ ] Spacing comes from theme tokens: the chip gap and the gap between the chips and the detail. Once ^ey6v778 lands with the EditorStyle tile tokens, use those. Until then, use EditorStyle spacing tokens, no literal numbers.
- [ ] With one file, show the chip row anyway, so the file name and counts stay visible. If an existing header already shows them, drop the duplicate and record which one you dropped.
- [ ] Hosted tests:
  - the detail's width equals the DiffView's width, within layout rounding, at both a narrow and a wide width;
  - the chips are above the detail (chip maxY ≤ detail minY);
  - chips wrap to a second line when they don't fit on one;
  - tapping a chip selects that file.
- [ ] Re-record the `__Snapshots__` images that change, and list them.
- [ ] Regenerate the review gallery and update `ReviewGalleryNotes.swift` for the thread screen.

## Related

^q89x329 (diff lines wrap out of alignment with the gutter) and ^a2dy2gt (the +/− counts are unreadable in light) touch the same view. Check they still apply after this change.

## Acceptance

- The diff always shows the file chips above and the file content at full width below.
- The hosted layout tests pass, and the full `swift test` is green.
- The gallery shows the new layout. #avk-8