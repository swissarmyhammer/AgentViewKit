---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: 'Scroll perf 4: a row that leaves the live range keeps its editor mounted'
---
User request (2026-11-25): "scrolling is still way too slow", stay with SwiftUI. The scroll profile found that the live range (`Sources/AgentViewKit/Thread/LiveRowRange.swift`, `margin` 8, `slack` 4) moves about once each 480 pt. At each move, `ResponseView` puts a placeholder in place of about 2 editors and mounts about 2 new editors. A frame with a mount has a median of 80 ms. A frame with no mount has 14.5 ms. These are the long hitches (95th percentile 75–86 ms).

## What

- `Sources/AgentViewKit/Content/ResponseView.swift`, `content` (about line 284): `placeholderHeight(isLive:laidOutHeight:holdsSelection:)` gives a height when the row is not live, and then `placeholder(height:)` replaces `editor`. So the `EditorView` goes away and a new one mounts when the row comes back.
- [ ] Measure first: with the scratch profile harness, compare (a) now, (b) `margin` 16 and `slack` 8, (c) keep the editor mounted and let the cache drop only the parsed model of a far row. Write the numbers on the card.
- [ ] Use the best option that keeps memory bounded. Preferred: keep the `EditorView` of a row mounted while the row is in the lazy stack, and drop only its model when it is far (EditorKit ^59ykv6h makes the first layout cheaper; take it when it is on main).
- [ ] Keep the selection rule (`holdsSelection`) and the laid-out height rule.

## Acceptance Criteria

- [ ] A scroll back and forth over the same rows mounts no new editor on the second pass.
- [ ] The number of parsed models stays bounded by `CodeBlockModelCache.threadLimit` and the live range rule.

## Tests

- [ ] New test in `Tests/AgentViewKitTests/Thread/`: a package counter of editor mounts. Mount a thread of 60 agent messages in a window that is never ordered in, move the clip down and back up by fixed steps with one `layoutSubtreeIfNeeded()` each, then do the same pass again, and expect 0 new mounts in the second pass.
- [ ] A test that the model count stays at or below the limit after a scroll over all rows.
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings.

## EditorKit design (editorkit-7a, 2026-11-25): card ^8vgmyc7, after ^59ykv6h

- A new modifier `.editorMountCache(cache)` keeps the realized coordinator of an `EditorView` when SwiftUI removes the view. The next `EditorView` over the SAME model uses it again: the laid-out text, the lanes and the `RowGrid` stay, and the first layout does not run again.
- AVK puts the cache above the transcript list, and keeps its models cached (`CodeBlockModelCache` and the others).
- A model swap under one view identity is not supported. Keep one `EditorView` for each model.
- So the preferred option of this card becomes: keep the placeholder swap, and put `.editorMountCache` above the list, so that a row that comes back gets its realized host again. Wait for the ^8vgmyc7 sha. Bound the mount cache the same as the model cache.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- After the change, run the scratch profile harness again and add the frame-time numbers to the card. #perf