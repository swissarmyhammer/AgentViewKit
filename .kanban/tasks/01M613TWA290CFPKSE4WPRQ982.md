---
assignees:
- claude-code
position_column: todo
position_ordinal: ab80
title: Review gallery shows every recorded snapshot, not only the full screens
---
User: "we actually need a COMPLETE gallery of all taken snapshots, not just these full screens".

Today ~/Library/Caches/AgentViewKit/screenshot-check/index.html shows only the 7 full screens from ReviewGalleryScreen (thread, scrolled, request-deck, banners, sign-in, inspector, gallery), in light and dark. The 66 reference PNGs under Tests/AgentViewKitTests/Snapshots/__Snapshots__/ (GlassSnapshotTests: 20, HostedSnapshotTests: 46) aren't in it.

## Work
- [ ] The gallery page gets a section for every snapshot suite, after the full screens. It discovers every reference PNG under `__Snapshots__/**` by itself, so a new snapshot shows up with no registration step. Group by suite and by snapshot name, with light and dark side by side.
- [ ] Copy each reference image into the gallery folder, or link it by absolute file URL, so the page works when opened from the caches folder
- [ ] Every snapshot entry shows its name and the test that records it. A note is optional; ReviewGalleryNotes can hold notes keyed by snapshot name.
- [ ] A test fails if a reference PNG under `__Snapshots__` is missing from the generated page
- [ ] The writer stays generic (package name, snapshot root), because EditorKit is taking it into EditorTestSupport. Say so on the card if EditorKit lands first, and then do this in EditorKit's helper instead.
- [ ] `swift test` is green, and the regenerated page lists all snapshots

Order: after the Reduce Transparency and Increase Contrast removal card, so those variants never appear.