---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5eafdtrz8dfn4nrw9xq9yfk
  text: 'Research: In Input/ and the pill, the glass button style lines are SuggestionsView (no shape), SpeechInputButton (.circle), ScrollToBottomPill (.capsule) and the actionStyle helper of DefaultPromptAccessory (2 lines `self.buttonStyle(...)`; the 2 callers set .circle). A modifier chain is not safe to find with a line scan (multi-line arguments break the chain), so the test uses the count check of the card. A style helper is found as `self.buttonStyle(` with a glass style; all its lines count as one style call. The existing fixture dir GlassPlacement/Clean is scanned for each glass form, so a fixture with real glass code cannot go there. The new test uses its own fixture dir Fixtures/GlassButtonShape (Violating and Clean). The Clean fixture proves the helper rule, because the sources pass also without it (2 helper lines, 2 shapes).'
  timestamp: 2026-10-21T04:10:57.752858+00:00
- actor: claude-code
  id: 01m5eapf8vv44kr7v0289xe5v1
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Input/SuggestionsView.swift (adds `.buttonBorderShape(.capsule)`); new Tests/PackageStructureTests/GlassButtonShapeTests.swift (count check per file, a `self.buttonStyle(` glass helper counts as one style call); new fixtures Tests/PackageStructureTests/Fixtures/GlassButtonShape/Violating/ChipWithoutShape.swift and Clean/ShapedStyleHelper.swift. RED: the source test reported Sources/AgentViewKit/Input/SuggestionsView.swift:52. Full `swift test`: 1448 tests in 176 suites passed with 2 known issues (existed before); PackageStructureTests 166 tests in 23 suites passed. The only warning is the mlx bundle warning that existed before. GlassPlacementTests allow list did not change: SuggestionsView.swift is in it already.
    - next: review
  timestamp: 2026-10-21T04:14:48.603191+00:00
- actor: claude-code
  id: 01m5eav9fr9g2wgr2kk7attwg5
  text: |-
    ### test - green
    - evidence: swift test, 116 seconds, exit 0. PackageStructureTests: 166 tests in 23 suites passed (GlassButtonShapeTests suite passed). Main test run: 1448 tests in 176 suites passed, 2 known issues (as before). 0 failures, 0 skipped.
    - warnings: only the mlx bundle build warning that existed before. No new warning.
    - next: review
  timestamp: 2026-10-21T04:17:26.520393+00:00
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
position_column: doing
position_ordinal: '80'
title: 'AVK-8af Small floating controls use .capsule: give the suggestion chips .buttonBorderShape(.capsule) (SuggestionsView.swift:52) and hold the shapes with a test (D113 answer 3)'
---
## Why

D113 answer 3 and `style.md` "Glass variant and shape": "A small floating control (the pill, a chip) is a `.capsule`. A floating control with more than one line (the composer field) is a `ConcentricRectangle`."

Facts:
- The pill has `.buttonStyle(.glass)` and `.buttonBorderShape(.capsule)` (`Sources/AgentViewKit/Thread/ScrollToBottomPill.swift:51-52`). Correct.
- The suggestion chips have `.buttonStyle(.glass)` with no border shape (`Sources/AgentViewKit/Input/SuggestionsView.swift:52`). The default shape is not a capsule on macOS.
- The icon buttons Send, Stop and dictation use `.buttonBorderShape(.circle)` (`Input/DefaultPromptAccessory.swift:140`, `:156`, `Input/SpeechInputButton.swift:68`). A circle is a capsule with equal sides, for an icon-only button. Keep `.circle`.
- The composer field and the editor menu use `agentFloatingGlass()`, a `ConcentricRectangle` (`Input/PromptInputView.swift:374`, `:422`). Correct.

## What to do

- [x] Add `.buttonBorderShape(.capsule)` after `.buttonStyle(.glass)` in `SuggestionsView.swift:52`.
- [x] Add a structure test in `Tests/PackageStructureTests/` (code lines only, with `SourceLineScanner.codeMatches`): in each file of `Sources/AgentViewKit/Input/` and `Sources/AgentViewKit/Thread/ScrollToBottomPill.swift`, each `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)` has a `.buttonBorderShape(.capsule)` or `.buttonBorderShape(.circle)` in the same modifier chain. If one chain check is too hard for a line scan, check the count: the number of border shape calls in a file is at least the number of glass button style calls in that file. The `actionStyle` helper of `DefaultPromptAccessory.swift:169-175` counts as one style call: its callers set the shape.
- [x] Add a fixture with a glass button and no border shape. The test reports its file and line.

## Acceptance

- The structure test passes on the sources and reports the fixture.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8