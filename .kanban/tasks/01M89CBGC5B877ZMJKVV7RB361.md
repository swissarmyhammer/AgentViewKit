---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m89p24agw46063gvaj6yjvc3
  text: 'EditorKit update (editorkit-7a, 2026-11-25): EK ^59ykv6h (first layout) is stuck and reverted by the user. The first-layout cost of a mount stays. EK ^8vgmyc7 (.editorMountCache) no longer depends on it and is the way to remove the mount hitch. EK order: ^qhvm2bg, then ^8vgmyc7. This card waits for the ^8vgmyc7 sha.'
  timestamp: 2026-11-25T15:44:18.256482+00:00
- actor: claude-code
  id: 01m8b4k0x9pbctzrqep3ha51y3
  text: |-
    ### closed — the EK mount cache does not land
    - evidence: AVK traces (^hkr4anw). spike/mount-cache 20db34ef used 12870 ms of main-thread time in the scroll (round 3), and EK main 44b9f941 used 12762 ms. The cache did not use less main-thread time in rounds 2 and 3. By the EK rule, EK closed ^8vgmyc7 as "not worth it" (editorkit-7a, 2026-11-25).
    - result: this card needed `.editorMountCache`, so it has no path now. It is done with no change.
    - next: the trace shows that EK is about 1.3 to 1.5 s of the 12.8 s. The rest is SwiftUI layout. The AVK ProposalSizedLayout has 1025 ms inclusive. A new card can measure that from a trace on current main.
  timestamp: 2026-11-26T05:17:26.313167+00:00
position_column: done
position_ordinal: ffffffffb380
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