---
assignees:
- claude-code
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
position_column: todo
position_ordinal: a980
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

- [ ] Add `.buttonBorderShape(.capsule)` after `.buttonStyle(.glass)` in `SuggestionsView.swift:52`.
- [ ] Add a structure test in `Tests/PackageStructureTests/` (code lines only, with `SourceLineScanner.codeMatches`): in each file of `Sources/AgentViewKit/Input/` and `Sources/AgentViewKit/Thread/ScrollToBottomPill.swift`, each `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)` has a `.buttonBorderShape(.capsule)` or `.buttonBorderShape(.circle)` in the same modifier chain. If one chain check is too hard for a line scan, check the count: the number of border shape calls in a file is at least the number of glass button style calls in that file. The `actionStyle` helper of `DefaultPromptAccessory.swift:169-175` counts as one style call: its callers set the shape.
- [ ] Add a fixture with a glass button and no border shape. The test reports its file and line.

## Acceptance

- The structure test passes on the sources and reports the fixture.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8