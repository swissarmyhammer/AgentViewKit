---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8ejcthred8q0767prdcbpq4
  text: |-
    ### review — clean
    - evidence: review sha 3597b8d5^1..3597b8d5: 0 findings (6 files, 1 refuted). All 6 items checked. Limit: the row-overlap check cannot fail from AVK (EK lazy-stack slots); the forced-height proof applies to the label-in-row check.
    - next: none
  timestamp: 2026-11-27T13:16:26.552841+00:00
position_column: done
position_ordinal: ffffffffba80
title: The review gallery shows the session jump list
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-26): check that AVK chip and row labels do not overlap (EK ^frjgqyz found overlapping labels on the Testudo Skills list). The AVK gallery shows the file chips and the diff chips (chip-rows-narrow: no overlap on EK f2ed9109). But it has no image of the `SessionJumpList` (Sources/AgentViewKit/Sessions/SessionJumpList.swift), which now uses EK `EditorSelectionList` (^tvjsqzp).

## What
- [x] Add a gallery fixture to `ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift` (and its register in `ReviewGalleryScreenTests.recordSnapshots()`): the jump list with about 8 sessions with long paths, at a narrow width and at a normal width, light and dark.
- [x] Add a headless test in `Tests/AgentViewKitTests/Sessions/SessionJumpListFieldTests.swift` that lays out the list at a narrow width in a window that is never ordered in, and checks that no two row frames overlap and that each label frame stays inside its row.

## Acceptance Criteria
- [x] The gallery has `session-jump-list-narrow` and `session-jump-list` images, light and dark.
- [x] The overlap test passes. If it fails, the card records the defect and the fix.

## Tests
- [x] The new headless test fails when two rows overlap (prove it with a fixed row height that is too small, for one run).
- [x] `swift test` (root) passes with 0 failures and 0 warnings. The gallery passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #test

## Evidence (2026-11-27)
- Commit 3597b8d5 adds the fixture and the headless tests. CI is green on d94b771d (it contains 3597b8d5).
- Root `swift test`: 1959 + 59 (agent) pass. Later main runs also pass.
- Gallery: it ran on c857a766 and 90dcacfd (47 pass). It wrote session-jump-list-light/dark.png and session-jump-list-narrow-light/dark.png. At 360 pt, the long paths wrap to more lines and no row overlaps (session-jump-list-narrow-light.png, examined).
- Proof of failure: the label-in-row test failed with a forced 12 pt row height and passed without it.
- Limit: the row-overlap check cannot fail from AVK. The row frames are EK `EditorSelectionList` lazy-stack slots, and AVK does not set them. The test documents this. Thus the forced-height proof applies to the label-in-row check only. The row-overlap check is a guard against an EK change.