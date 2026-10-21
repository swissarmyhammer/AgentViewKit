---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5e7m3a8s4frmn30t876n4my
  text: |-
    Research done. The sources now differ from the card text in three points:
    - No file calls `agentFloatingGlass()` except `Input/PromptInputView.swift`. `Theme/AgentSurfaces.swift` holds its definition and the one `.glassEffect(` call. The pill (`Thread/ScrollToBottomPill.swift`) uses `.buttonStyle(.glass)`.
    - Only `Theme/FloatingGlassContainer.swift` writes `GlassEffectContainer`. `Input/PromptInputView.swift` and `Thread/AgentThreadView.swift` (the pill container of AVK-8l) write `FloatingGlassContainer`. Thus the container rule is two rules: `GlassEffectContainer` only in `Theme/FloatingGlassContainer.swift`, and `FloatingGlassContainer` only in that file, the composer and the thread view.
    - In `Input/`, the text `.glassProminent` shows three times since AVK-8m: `style(of:for:)` of `DefaultPromptAccessory.swift` selects the prominent action (Send, or Stop while the agent runs), and one `.buttonStyle(.glassProminent)` applies it. The rule "exactly once" thus reads the `.buttonStyle(.glassProminent)` call: one call in `Input/`, in `DefaultPromptAccessory.swift`.
    Plan: move the "blank comments and strings, then scan lines" walk of `FixedColorTests` into `SourceLineScanner`, so that the new scan and the fixed color scan share it. The new `ComposerGlassStructureTests` test that "only the shared container makes a GlassEffectContainer" moves into `GlassPlacementTests`, because the new scan holds the same rule and also skips the comments and strings.
  timestamp: 2026-10-21T03:21:05.096326+00:00
- actor: claude-code
  id: 01m5e80tm0y3fb4ab6qykb7qnm
  text: |-
    Implementation done.
    - New `Tests/PackageStructureTests/GlassPlacementTests.swift`: the enum `GlassForm` holds each glass form (`.glassEffect(`, `agentFloatingGlass(`, `GlassEffectContainer`, `FloatingGlassContainer`, `.buttonStyle(.glass|.glassProminent)`), its pattern (built on `WordPattern.wholeWord`) and its allow list. A test scans `Sources/AgentViewKit` for each form. A test holds one `.buttonStyle(.glassProminent)` in `Input/`, in `Input/DefaultPromptAccessory.swift`. A test checks that each allowed file exists.
    - Fixtures in `Tests/PackageStructureTests/Fixtures/GlassPlacement/`: `Violating/Placement/ContentView.swift` (one line for each form, the scan reports file and line), `Violating/Input/TwoProminentActions.swift` (two prominent styles, the scan reports both lines), `Clean/GlassInText.swift` (each form only in comments and strings, the scan reports nothing).
    - Shared walk: new `SourceLineScanner.codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)` blanks comments and strings (`SwiftLiteralLexer.blankingCommentsAndLiterals(in:)`) and then scans the lines. `FixedColorTests.fixedColorUses(inSwiftFilesBelow:relativeTo:allowing:)` now calls it. Three new tests in `SourceLineScannerTests`.
    - Merge: `ComposerGlassStructureTests.onlyTheSharedContainerMakesAGlassEffectContainer` and its helpers `kitFiles(holding:)`, `containerCall`, `sharedContainerFile` are removed. The `glassEffectContainer` form of `GlassPlacementTests` holds the same rule and skips comments and strings.
    - Decision: the allow list of `agentFloatingGlass()` is `Theme/AgentSurfaces.swift` (the definition) and `Input/PromptInputView.swift`. `Thread/AgentThreadView.swift` is not in it, because `ComposerGlassStructureTests.theThreadViewWritesNoGlassOfItsOwn` forbids the modifier there, and the pill uses `.buttonStyle(.glass)`.
    - Not changed: `Tests/AgentViewKitTests/Theme/ContentButtonStyleTests.swift` is in another target, so it cannot share the code. Its content files are not in the glass button allow list, so `GlassPlacementTests` also covers them.
    - The subtask boxes of the description are checked.
  timestamp: 2026-10-21T03:28:02.176625+00:00
- actor: claude-code
  id: 01m5e80xf76g4sq73jhyazv236
  text: |-
    ### implement — changed
    - evidence: 4 files changed (Tests/PackageStructureTests/ComposerGlassStructureTests.swift, FixedColorTests.swift, SourceLineScanner.swift, SourceLineScannerTests.swift), 4 files new (Tests/PackageStructureTests/GlassPlacementTests.swift, Fixtures/GlassPlacement/Violating/Placement/ContentView.swift, Fixtures/GlassPlacement/Violating/Input/TwoProminentActions.swift, Fixtures/GlassPlacement/Clean/GlassInText.swift). `swift test`: 1446 tests in 176 suites passed with 2 known issues (these existed before); PackageStructureTests 163 tests in 22 suites passed. The only warning is the mlx bundle warning, which existed before.
    - next: review
  timestamp: 2026-10-21T03:28:05.095682+00:00
- actor: claude-code
  id: 01m5e863c1gj22q863w1stj897
  text: |-
    ### test — green
    - evidence: swift test (exit 0, 114 s). Swift Testing: 1446 tests in 176 suites passed, 2 known issues (known before). PackageStructureTests ran: 163 tests in 22 suites passed, with GlassPlacementTests (3.086 s), ComposerGlassStructureTests, FixedColorTests and SourceLineScannerTests. 0 failures, 0 skipped. Only warning: the mlx Cmlx.bundle build warning (known before).
    - next: review
  timestamp: 2026-10-21T03:30:54.977164+00:00
depends_on:
- 01M5DF8JJZ3JT3Q6XB30047RNQ
- 01M5DF8PPC1R7XN9M4SAR6MVJR
- 01M5DF8W1QPEPFE42Y4T6GSEM6
- 01M5DF911BGXPB97KE073V151H
- 01M5DF9554SMT439RB23DS9WV4
- 01M5DF9B6T1N6JXDM0BB4A7PDR
- 01M5DF9SKZ4BRGBD6BFG5XY664
- 01M5DF9Z1D6E1VEHSXTMS64VBV
- 01M5DFA593MWNN971T9F2GCJ20
- 01M5DFADQHSHCRAQW0709TVAPV
position_column: doing
position_ordinal: '80'
title: 'AVK-8n Structure test: glass only on the floating controls and the request card buttons'
---
## Why

D110 (b), (c). After AVK-8c to AVK-8l, a test must keep the glass rules true. A source scan is deterministic and fast.

## Files

- New: `Tests/PackageStructureTests/GlassPlacementTests.swift`, with fixtures in `Tests/PackageStructureTests/Fixtures/GlassPlacement/`.
- Pattern to copy: `Tests/PackageStructureTests/ImportBoundaryTests.swift`.

## Rules that the test checks in `Sources/AgentViewKit`

- [x] `.glassEffect(` shows only in `Theme/AgentSurfaces.swift` (the body of `agentFloatingGlass()`).
- [x] `agentFloatingGlass()` shows only in the floating control files: `Input/PromptInputView.swift` and the file that draws the pill container of AVK-8l.
- [x] `GlassEffectContainer` shows in `Input/PromptInputView.swift` and in the container of AVK-8l.
- [x] `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` show only in an allow list: the floating controls (`Input/DefaultPromptAccessory.swift`, `Input/SuggestionsView.swift`, `Input/SpeechInputButton.swift`, `Thread/ScrollToBottomPill.swift`) and the action buttons of request cards and notices (`HumanInTheLoop/PermissionView.swift`, `Elicitation/ElicitationView.swift`, `Elicitation/ElicitationURLConsentView.swift`, `Connections/AgentAuthView.swift`, `Status/SessionNoticeBanner.swift`, `Status/StatusBar.swift`).
- [x] In `Sources/AgentViewKit/Input/`, `.glassProminent` shows exactly once: the Send button.
- [x] The scanner ignores comments and string literals.

## Acceptance

- `GlassPlacementTests` passes on the sources after the cards this card depends on.
- Fixture tests prove that the scanner reports a `.glassEffect` in a content file, a `.buttonStyle(.glass)` outside the allow list, and a second `.glassProminent` in `Input/`, each with the file and the line.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8