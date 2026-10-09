---
assignees:
- claude-code
position_column: todo
position_ordinal: bc80
title: Decide if ScrollAnchorManager.visibleIDs must be correct after a long jump in ConversationView
---
## What
^vyqyvwv found this behavior. After a long jump in `ConversationView` (for example the Show Error button, the thread minimap, or the jump command), the LazyVStack can do a first layout pass in which a row that SwiftUI kept alive still has an old position. `onScrollTargetVisibilityChange` reports the rows in view for that pass. The next layout pass moves the row to its correct position, but the content offset and the content size do not change. SwiftUI then does not call `onScrollTargetVisibilityChange` again. Thus `ScrollAnchorManager.visibleIDs` stays stale until the next scroll. The list itself shows the correct rows.

Evidence (from ^vyqyvwv): after the jump to the first row, the clip origin was at the top of the content, and the accessibility frame of the error row was in the list frame. But `visibleIDs` was `[m0, m1, m2, m3, m4]` and did not include the error row for 5 seconds.

Effects: `saveAnchor()` uses `visibleIDs.first`, so a Load Earlier press after such a jump can keep the wrong row as the anchor. A view that shows the rows in view from `visibleIDs` can show the wrong rows until the next scroll.

- [ ] Decide if the kit must correct `visibleIDs` after a jump, or if the stale value until the next scroll is acceptable.
- [ ] If the kit must correct it, find a way that does not add a geometry callback to each row (the observation benchmarks measure the cost of the list).

## How to reproduce
Run 6 test-bundle processes at the same time with `swiftpm-testing-helper`, `--filter theShowErrorButtonMovesToTheErrorEntry --repetitions 30 --repeat-until fail`, and an assertion on `anchors.visibleIDs.contains(errorKey)` after the press. See the comments on ^vyqyvwv.