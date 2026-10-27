---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5zr8hs1ew8dce330n6k8vwe
  text: 'Blocked on EditorKit card ^8zwzkda: the inline DiffView gets one right-aligned number column. EditorKit''s queue: ^yb2p8xe, then ^jmq52v6, then ^8zwzkda.'
  timestamp: 2026-10-27T22:38:57.825020+00:00
position_column: todo
position_ordinal: a780
title: Diff line numbers sit in one right-aligned column on every row (after EditorKit fixes its inline gutters)
---
User review of the screenshot gallery: "line numbers on diffs are insonsistently spaced between + and - lines -- i'd expect them to all right align consistently".

## Cause
The inline diff comes from EditorKit's `DiffView` (../EditorKit/Sources/EditorSwiftUI/Diff/DiffView.swift:235). It uses `.withLineGutters([.old, .new], …)`, which adds two line-number columns. A removed row shows its number only in the old column, an added row only in the new column, and a context row in both. So the numbers on `-` and `+` rows sit at different horizontal positions.

## Fix (EditorKit, with AVK picking it up)
- In EditorKit, the inline layout gets one line-number column, right-aligned. It shows the new line number on added and context rows, and the old line number on removed rows. The `+`/`-` marker column stays and tells the sides apart. The side-by-side layout keeps one column per side, as it already does.
- In AVK, bump the EditorKit pin, re-record the diff snapshots, and re-generate the review gallery.

## Acceptance
- [ ] EditorKit card landed on main; SHA recorded here
- [ ] EditorKit pin bumped in AVK
- [ ] A hosted test checks that the number on an added row, a removed row and a context row has the same right edge
- [ ] Diff snapshots and the review gallery are re-recorded (light and dark)
- [ ] `swift test` is green

#cross-repo