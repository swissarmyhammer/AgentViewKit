---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ekqcqfvfwb3nsnb8faaf2t
  text: |-
    Implementation landed (not committed).

    What changed:
    - `EditorBlockChrome.swift`: `EditorBlockBar` / `editorBlockBar()` are now `EditorBlockHeader` / `editorBlockHeader()`. The modifier draws no background. It puts a system `Divider` under the row in a `VStack(spacing: 0)`. The DocC says: the header row is content, not a bar (D113); it has no fill; a separator line marks it.
    - `CodeBlockView`, `TerminalView`, `CommandOutputView`: use `.editorBlockHeader()`. Each view had a `Divider()` after `header` in its body. I removed that `Divider()`, because the modifier now draws it. The layout is the same. The terminal output body keeps the TerminalPalette background (^mz0nfka). The frame fill also shows behind the header of a terminal, because the header has no fill of its own.
    - `statusBarBackground` now has no user in `Sources/AgentViewKit`. I did not remove the EditorKit theme token. `Docs/decisions/visual-audit.md` still has a row "header bar of a code block, terminal, or command output | statusBarBackground". That row is now out of date, the same as the earlier row "frame of a code block | editorBackground". I did not change the decision record.

    Tests:
    - `EditorThemeViewsTests`: `theCodeBlockHeaderHasNoStatusBarBackground` and `theCommandOutputFrameUsesTheTerminalBackgroundAndTheHeaderHasNoFill` forbid `Role.statusBarBackground`. New `aSeparatorLineIsUnderTheHeaderRow`: a clear header row with `.editorBlockHeader()` over clear content, on the `SurfaceWithBackdrop` backdrop. In the middle column, a row that does not show the backdrop must be between rows that show it. This test failed with the old modifier (fill and no line) and passes with the new one.
    - `TerminalViewHostedTests.theFrameUsesTheTerminalBackgroundAndTheHeaderHasNoFill` forbids `Role.statusBarBackground` (the terminal needs a scripted session, so its check stays in that suite).
    - `CodeBlockViewSurfaceHostedTests`: changed only the doc comment, which said "until AVK-8ac".

    What did not work:
    - First I wrote the separator check on a real `CodeBlockView` in a window (`ContentSurfaceHostedProbe.pixels`, `.behindToTheEdge`). It cannot work. In the window cache, the text area of the EditorKit editor draws pure white (with SystemTheme and with DistinctRolesTheme). Only the gutter shows the backdrop. At x = 1.5 the rounded top corner and its stroke give a false "line". Thus I test the modifier on clear content, the same way as the `clearBlock` frame tests.

    Discoveries:
    - The EditorKit text area shows opaque white in `cacheDisplay`. It is not `editorBackground` (`theCodeBlockFrameHasNoEditorBackground` still passes). This can be a real fill of the editor text view (for example `NSTextView.drawsBackground`), which D113 does not permit for a code block, or a limit of the cache. Someone must examine it on another card.
    - `AgentSurfacesTests.theFloatingGlassIsTheSameForEachMaterialLevel` (`.clear` case, `glass == regular`) is flaky in the full suite: it failed in 2 full runs and passed in 2 full runs with the same logic. It passes alone. `isClose(to:)` also failed, so the difference is large and not one byte of anti-aliasing. `AgentFloatingGlass` does not read `materialLevel`, so the two renders are of the same view. The cause is probably the render state of the process during parallel tests. I did not change that test. It needs its own card (^sdkm4qt made it).
  timestamp: 2026-10-21T06:52:35.951607+00:00
- actor: claude-code
  id: 01m5ekqveg5dd3dgtbh3shdnp6
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Code/EditorBlockChrome.swift, Sources/AgentViewKit/Code/CodeBlockView.swift, Sources/AgentViewKit/Terminal/TerminalView.swift, Sources/AgentViewKit/Content/CommandOutputView.swift, Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift, Tests/AgentViewKitTests/Terminal/TerminalViewHostedTests.swift, Tests/AgentViewKitTests/Code/CodeBlockViewSurfaceHostedTests.swift. Final `swift test`: 1463 tests in 182 suites passed with 2 known issues (+174 and +1 in the other targets); only the known mlx bundle warning. RED seen for all 5 new or changed checks before the change.
    - note: `AgentSurfacesTests.theFloatingGlassIsTheSameForEachMaterialLevel(.clear)` is flaky in the full suite (2 of 4 full runs failed). It was not changed. It needs its own card.
    - next: /review
  timestamp: 2026-10-21T06:52:51.024458+00:00
- actor: claude-code
  id: 01m5em223qswrgfe9n051k44m5
  text: |-
    ### test - green
    - evidence: Two full runs of `swift test`. Run 1: 1463 tests in 182 suites passed, 2 known issues, 0 failures, about 120 s. Run 2: the same counts, about 119 s.
    - The test theFloatingGlassIsTheSameForEachMaterialLevel passed with 3 cases in run 1 and in run 2.
    - The PackageStructureTests target ran: its 7 suites passed in both runs (174 tests in 23 suites in the run of that target).
    - The only warning is the old mlx bundle build warning. The 2 known issues are the old ones.
    - No code change was made.
    - next: review
  timestamp: 2026-10-21T06:58:25.527951+00:00
- actor: claude-code
  id: 01m5em4qdgqk94j6x6cmpd8rbe
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 6b17070). 0 findings, 0 confirmed, 0 refuted. 7 files reviewed. 2 files in .kanban/ are not reviewed (.reviewignore).
    - next: none. The task moved to done.
  timestamp: 2026-10-21T06:59:52.880438+00:00
- actor: claude-code
  id: 01m5em4yk54c4smn18p3h89mbk
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 7 files
    - test: green — swift test two times, 1463 passed each time, 2 known issues that were there before
    - commit: 6b17070
    - review: clean — 0 findings
  timestamp: 2026-10-21T07:00:00.229416+00:00
depends_on:
- 01M5E8TFNDT9Q9WE6C2D6YW9PP
position_column: done
position_ordinal: ffff9380
title: 'AVK-8ac Header rows of code blocks, terminal and command output: remove the statusBarBackground fill (EditorBlockChrome.swift:54) and put a .separator line under the header (D113 answer 4)'
---
## Why

D113 answer 4 and `style.md` "How the steps apply": "A header row inside content (the header of a code block, a terminal or a command output) is content, not a bar. It has no fill. A `.separator` line under it marks it."

Today `EditorBlockBar` fills the header row with `editorTheme.statusBarBackground` (`Sources/AgentViewKit/Code/EditorBlockChrome.swift:47-56`, `:74-79`).

## Files and lines

- `Sources/AgentViewKit/Code/EditorBlockChrome.swift:47-56` (`EditorBlockBar`), `:74-79` (`editorBlockBar()`).
- Users: `Sources/AgentViewKit/Code/CodeBlockView.swift:113`, `Sources/AgentViewKit/Terminal/TerminalView.swift:220`, `Sources/AgentViewKit/Content/CommandOutputView.swift:230`.
- Test: `Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift:55`, `:63`, `:72` (they expect or forbid `Role.statusBarBackground`).

## What to do

- [x] Change the modifier so that it draws no background. It draws a `.separator` line under the row (for example `.overlay(alignment: .bottom) { Divider() }`, or a 1-point `Rectangle().fill(.separator)` with the height of the display scale). Use a system `Divider` if it gives the separator color.
- [x] Rename the modifier and the function so that the name does not say "bar" (for example `EditorBlockHeader` and `editorBlockHeader()`). Change the three users.
- [x] Change the DocC comment: the header row is content, not a bar; it has no fill; a separator line marks it (D113).
- [x] Change `EditorThemeViewsTests`: the code block, the terminal and the command output show no `Role.statusBarBackground` pixel. Add one check that a row of pixels under the header is not the color of the content above it (the separator line).

## Acceptance

- No `statusBarBackground` in `Sources/AgentViewKit`.
- The changed `EditorThemeViewsTests` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8