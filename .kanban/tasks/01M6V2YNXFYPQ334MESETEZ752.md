---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Gallery page shows stale timing and config-controls images
---
The review gallery page is written from `ReviewGalleryScreenTests.recordSnapshots()`; a snapshot test run on its own writes only to the `generated/` staging folder. The list left out `HostedSnapshotTests.theThreadWithTheTimeOfEachRow` and `theConfigAndToolControls`, so `snapshots/HostedSnapshotTests/thread-timing-*.png` and `config-controls-*.png` on the page stayed from Nov 6 while the other 194 images were regenerated.

- [x] recordSnapshots records both tests, in the order of the suite
- [x] A ScreenshotTests run regenerates all 198 images (none older than the run)