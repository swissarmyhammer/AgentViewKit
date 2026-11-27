---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8djbj11q2pk856wf5m65bg2
  text: |-
    Research and result (EditorKit 1892af46, AVK main 1b3d091e merged):
    - No AVK production gate keeps math not exact. `EditorLayoutTranscriptTextMeasure.isExact` reads `EditorLayoutMeasure.measure(...).unmeasured`, and EditorKit now measures math. Only the type doc said "math is not exact"; I updated it.
    - Contract: a Markdown part with inline or block math is exact. `markdownWithMathIsNotExact` is replaced by `markdownWithInlineMathIsExact` and `markdownWithBlockMathIsExact`.
    - RED: the old test failed (math is exact). The new parity tests failed first with 16 issues: inline math 16 to 32 pt, block math 32 pt, wrapped inline code 16 pt (at 320 and 720) off.
    - Cause of that RED: a defect of `TranscriptRowHeightBed.mount`, not of the measure. The bed read the heights after one run-loop fence, but the first Markdown parse runs off the main thread and no run-loop block waits for it. Before the parse, the view shows no inline styles (math as TeX source, inline code with no chip). A diagnostic over 6 fences showed the mounted height does not change after fence 1, so more fences do not help. Fix: the bed gives the row a `CodeBlockModelCache` and awaits `syntax.ensureParsed` of the response model of block 0 (the same pattern as `StaticRowHost.awaitParse`).
    - GREEN: all parity cases are 0.0 pt.
    - Discovery (new card): the static form (`StaticMarkdownText`) shows Markdown in SwiftUI `Text` and has no math support. Now that math rows are exact, the cache can give a math row its static form, which shows the TeX source in place of the formula while the rows move.
  timestamp: 2026-11-27T03:56:30.625533+00:00
- actor: claude-code
  id: 01m8djcad80m702s2c546yj2fr
  text: |-
    ### implement — changed
    - evidence: commit de460e25. 5 files — Sources/AgentViewKit/Thread/EditorLayoutTranscriptTextMeasure.swift (doc), Tests/AgentViewKitTests/Thread/EditorLayoutTranscriptTextMeasureTests.swift, Tests/AgentViewKitTests/Thread/TranscriptRowFixtures.swift, Tests/AgentViewKitTests/Thread/TranscriptRowHeightBed.swift, Tests/AgentViewKitTests/Thread/TranscriptRowMeasureTests.swift. Height suites: 27 tests in 3 suites passed; parity 9 of 9 cases at 0.0 pt (inline math, block math, wrapped inline code at 320/480/720). Root `swift test`: 1981 tests in 240 suites passed, and 59 tests in 12 suites passed; 0 failures, 0 project warnings. No fence-bound timeout.
    - next: /review. Follow-up card 01M8DJBNT8X5J6640D6HH39BP4 (static form of a math row shows TeX source).
  timestamp: 2026-11-27T03:56:55.592913+00:00
position_column: doing
position_ordinal: '8280'
title: 'Test: markdownWithMathIsNotExact fails after EditorKit measures math'
---
Found on 2026-11-26 during ^7625j1b. Root `swift test` in worktree-agent-a5f3ddbd4f5df14ea (main 45123917, plus test helper edits only) fails `EditorLayoutTranscriptTextMeasureTests.markdownWithMathIsNotExact`. The test also fails when it runs alone (2.6 s).

## Cause
- EditorKit tracks the `main` branch (Package.resolved is not tracked). The resolved EditorKit is 1892af46.
- EditorKit 12be0f5f (`feat(layout-measure): math sizes off the main actor`, ^tg1hnz7) measures math. In `EditorLayoutMeasure.unmeasuredElement(of:)`, a math widget is unmeasured only when `MathLineTypesetter.isAvailable` is `false`. iosMath is linked, so the typesetter is available, and a math part is exact now.
- The AVK test expects `!isExact("The cost is $n^2$ for each row.", .markdown)`, so it fails.

## What
- [x] Decide the contract: with the EditorKit math measure, is a Markdown part with math exact for a static row? Check that the measured height of math is the same as the height of the mounted row (the parity tests `TranscriptRowMeasureTests`).
- [x] Update `markdownWithMathIsNotExact` (and its name and doc) to the new contract, or keep math not exact in `EditorLayoutTranscriptTextMeasure` if the heights do not agree.
- [x] Add parity cases to `TranscriptRowMeasureTests` (0.0 pt at each width of the suite) for inline math, block math, and a wrapped line with inline code (EditorKit ^5b9fdah).

## Tests
- [x] Root `swift test` passes with 0 failures and 0 warnings. #test