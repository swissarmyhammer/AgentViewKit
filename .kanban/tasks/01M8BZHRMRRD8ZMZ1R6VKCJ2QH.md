---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: The review gallery shows the session jump list
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-26): check that AVK chip and row labels do not overlap (EK ^frjgqyz found overlapping labels on the Testudo Skills list). The AVK gallery shows the file chips and the diff chips (chip-rows-narrow: no overlap on EK f2ed9109). But it has no image of the `SessionJumpList` (Sources/AgentViewKit/Sessions/SessionJumpList.swift), which now uses EK `EditorSelectionList` (^tvjsqzp).

## What
- [ ] Add a gallery fixture to `ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift` (and its register in `ReviewGalleryScreenTests.recordSnapshots()`): the jump list with about 8 sessions with long paths, at a narrow width and at a normal width, light and dark.
- [ ] Add a headless test in `Tests/AgentViewKitTests/Sessions/SessionJumpListFieldTests.swift` that lays out the list at a narrow width in a window that is never ordered in, and checks that no two row frames overlap and that each label frame stays inside its row.

## Acceptance Criteria
- [ ] The gallery has `session-jump-list-narrow` and `session-jump-list` images, light and dark.
- [ ] The overlap test passes. If it fails, the card records the defect and the fix.

## Tests
- [ ] The new headless test fails when two rows overlap (prove it with a fixed row height that is too small, for one run).
- [ ] `swift test` (root) passes with 0 failures and 0 warnings. The gallery passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #test