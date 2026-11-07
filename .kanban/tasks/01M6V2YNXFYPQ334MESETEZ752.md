---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6v30vrzq167056cctebsw7b
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (52f8bae4) — 0 findings, 0 confirmed, 0 refuted; 7 validator passes attempted, 0 failed; 1 file reviewed (ScreenshotTests ReviewGalleryScreenTests), .kanban/ files excluded by .reviewignore
    - next: none — task moved to done
  timestamp: 2026-11-07T13:26:29.919049+00:00
position_column: done
position_ordinal: ffffffc680
title: Gallery page shows stale timing and config-controls images
---
The review gallery page is written from `ReviewGalleryScreenTests.recordSnapshots()`; a snapshot test run on its own writes only to the `generated/` staging folder. The list left out `HostedSnapshotTests.theThreadWithTheTimeOfEachRow` and `theConfigAndToolControls`, so `snapshots/HostedSnapshotTests/thread-timing-*.png` and `config-controls-*.png` on the page stayed from Nov 6 while the other 194 images were regenerated.

- [x] recordSnapshots records both tests, in the order of the suite
- [x] A ScreenshotTests run regenerates all 198 images (none older than the run)