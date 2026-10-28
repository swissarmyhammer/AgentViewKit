---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5zr8hs1ew8dce330n6k8vwe
  text: 'Blocked on EditorKit card ^8zwzkda: the inline DiffView gets one right-aligned number column. EditorKit''s queue: ^yb2p8xe, then ^jmq52v6, then ^8zwzkda.'
  timestamp: 2026-10-27T22:38:57.825020+00:00
- actor: claude-code
  id: 01m618424w7rhagkp529hj0gv3
  text: |-
    Picked up; EditorKit blockers are in. Findings:
    - The pin AVK resolves (Package.resolved, EditorKit f588cb5d) holds both ^8zwzkda fb4ef5b and ^xc9zq15 a044349 (`git merge-base --is-ancestor` on the checkout). Package.resolved needed no change.
    - AVK's renderer (Sources/AgentViewKit/Diff/DiffRendererSlot+EditorKit.swift) passes the patch straight to EditorSwiftUI.DiffView. It has no gutter code of its own, so it picks up the single `diff.line` column without an edit.
    - No AVK test read the `diff.old` / `diff.new` line-number columns. `editor.diff.old` / `editor.diff.new` in DiffRendererDefaultHostedTests are the accessibility ids of the side-by-side editor columns, not gutter columns, so they stay.
    - EditorKit's own glyph seam is public: `GutterLaneView.preparedGlyphText/preparedGlyphRowRect/preparedGlyphRunRect` (EditorText). The AVK hosted test finds the lane with `NSView.descendants` under the `editor.diff` root. It needs no `@testable import` of EditorKit and no new helper. `harness.render()` alone prepares the rows, so no settle is needed.
    - To keep the name `DiffView` unambiguous, the `diff.line`, `diff.old` and `diff.new` ids now live in Tests/AgentViewKitTests/Diff/EditorDiffIdentifier.swift. That file imports EditorSwiftUI and not AgentViewKit.
    - The four new tests passed on their first run, because the behavior shipped in EditorKit before this card. There was no RED run against the old pin; re-resolving to the pre-fb4ef5b EditorKit would have meant changing Package.resolved.
    - No reference PNG under Snapshots/__Snapshots__ draws a diff: the thread fixture of HostedSnapshotTests has no edit. So no reference snapshot changed. The full run regenerated the review gallery at ~/Library/Caches/AgentViewKit/screenshot-check (thread--light.png and thread--dark.png show the diff). A note in ReviewGalleryNotes.thread says the new image is not judged yet.
  timestamp: 2026-10-28T12:35:22.396754+00:00
- actor: claude-code
  id: 01m61847hrak10tthg6cfdnsyx
  text: |-
    ### implement — changed
    - evidence: 4 files — Tests/AgentViewKitTests/Diff/DiffLineNumberHostedTests.swift (new: 4 hosted tests — one `diff.line` column with numbers 8,9,9,10,11,1001,1001,1002,1003; no `diff.old`/`diff.new` in inline; one right edge for added/removed/context rows; each run inside its cell), Tests/AgentViewKitTests/Diff/EditorDiffIdentifier.swift (gutter column ids), Tests/AgentViewKitTests/Snapshots/ReviewGalleryNotes.swift (thread note), Docs/decisions/diff-renderer.md (line-number columns section with EditorKit SHAs fb4ef5b, a044349, pin f588cb5). `swift test` under Scripts/ui-test-lock.sh: 1893 tests in 236 suites passed, 7 known issues (the existing withKnownIssue sites), 0 failures. The only warning is the existing mlx-swift_Cmlx "missing creator" packaging warning. No reference PNG changed. The gallery regenerated.
    - next: /review
  timestamp: 2026-10-28T12:35:27.928973+00:00
position_column: doing
position_ordinal: '8380'
title: Diff line numbers sit in one right-aligned column on every row (after EditorKit fixes its inline gutters)
---
User review of the screenshot gallery: "line numbers on diffs are insonsistently spaced between + and - lines -- i'd expect them to all right align consistently".

## Cause
The inline diff comes from EditorKit's `DiffView` (../EditorKit/Sources/EditorSwiftUI/Diff/DiffView.swift:235). It uses `.withLineGutters([.old, .new], …)`, which adds two line-number columns. A removed row shows its number only in the old column, an added row only in the new column, and a context row in both. So the numbers on `-` and `+` rows sit at different horizontal positions.

## Fix (EditorKit, with AVK picking it up)
- In EditorKit, the inline layout gets one line-number column, right-aligned. It shows the new line number on added and context rows, and the old line number on removed rows. The `+`/`-` marker column stays and tells the sides apart. The side-by-side layout keeps one column per side, as it already does.
- In AVK, bump the EditorKit pin, re-record the diff snapshots, and re-generate the review gallery.

## Acceptance
- [x] EditorKit card landed on main; SHA recorded here — ^8zwzkda `fb4ef5b` (one `diff.line` column, `DiffLineNumbers.Side.inline`), ^xc9zq15 `a044349` (each number column as wide as its widest number); AVK resolves EditorKit `f588cb5d7fa1e4e0a25d0635a800ff44de696d5b`, which holds both
- [x] EditorKit pin bumped in AVK (Package.resolved already resolves `f588cb5`)
- [x] A hosted test checks that the number on an added row, a removed row and a context row has the same right edge (Tests/AgentViewKitTests/Diff/DiffLineNumberHostedTests.swift, with a hunk past line 1000)
- [x] Diff snapshots and the review gallery are re-recorded (light and dark) — no reference snapshot under Snapshots/__Snapshots__ draws a diff, so none changed; the full run regenerated the gallery (thread--light.png, thread--dark.png) and ReviewGalleryNotes has the new note
- [x] `swift test` is green

#cross-repo