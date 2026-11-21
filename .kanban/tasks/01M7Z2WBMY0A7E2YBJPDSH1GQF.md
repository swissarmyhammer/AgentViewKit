---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m805hgr1y5betwzre82ws3d9
  text: |-
    Implementation done (TDD).
    - RED: CodeBlockSymbolTests did not compile ("type 'AgentSymbol' has no member 'codeBlock'"). GREEN: 3 tests pass.
    - AgentSymbol.codeBlock = "chevron.left.forwardslash.chevron.right" is in the Content section. EditorKit has no symbol for this name, so the symbol is not a copy.
    - CodeBlockView.header: the title part of BlockHeader now holds `Image(systemName: AgentSymbol.codeBlock).symbolColumn().accessibilityHidden(true)` before the Text. BlockHeader already puts its title parts in an HStack with spacing `editorStyle.spacing.s`, in the font and the `themeSecondary` color of the title. Thus the symbol gets the spacing and the color with no more modifiers.
    - Hosted tests (compile only): an `#if DEBUG` extension of CodeBlockViewHostedTests, because TerminalEntry comes only from a scripted session (TerminalViewHostedTests.openTerminal, which is DEBUG only). Two tests compare the leading x of the title ("swift", and "plain text") with the x of TerminalView.commandIdentifier, each relative to its hosting view. The title node is found by its label (ResponseTextChecks.node(labeled:in:)), because the title has no identifier.
    - The two acceptance items about the same x and "plain text" stay open: only a hosted run can prove them, and hosted runs are not permitted now.
    - The code-block snapshot test needed no change. The PNG is not made again (that needs a hosted run).
  timestamp: 2026-11-21T23:02:26.817065+00:00
- actor: claude-code
  id: 01m805hkz79xnbdvepq9ykhrv1
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Items/AgentSymbol.swift, Sources/AgentViewKit/Code/CodeBlockView.swift, Tests/AgentViewKitTests/Code/CodeBlockSymbolTests.swift (new), IntegrationTests/Tests/IntegrationTests/Code/CodeBlockViewHostedTests.swift. `swift test`: 1608 tests in 183 suites passed, plus 54 tests in 11 suites passed, 0 failures. `swift build --build-tests` passes in IntegrationTests and in ScreenshotTests. `swift format lint --strict` passes on the 4 files.
    - next: /review. A hosted run must prove the two open acceptance items (the same x as the terminal command, and the symbol before "plain text"), and the code-block PNG must be made again for the user.
  timestamp: 2026-11-21T23:02:30.119324+00:00
depends_on:
- 01M7YZJF2WT82MEFW3DACB63ES
position_column: doing
position_ordinal: '80'
title: The header of a code block shows a code symbol in the symbol column, as the terminal header does
---
## What
The header of ``TerminalView`` (`Sources/AgentViewKit/Terminal/TerminalView.swift`, `header`) starts with a single-color SF Symbol in the symbol column: `EditorSymbolImage(.tool(.execute)).symbolColumn().accessibilityHidden(true)`. The header of ``CodeBlockView`` (`Sources/AgentViewKit/Code/CodeBlockView.swift`, `header`) shows only the title (the filename or the language) and the Copy button, with no symbol. The user decided (2026-11-21): a code block shows one SF Symbol, the same for each language, in the symbol column, so that it matches the terminal and shell headers.

This task depends on the shared ``BlockHeader`` task (01M7YZJF2WT82MEFW3DACB63ES), because that task moves the header of ``CodeBlockView`` into ``BlockHeader``. Put the symbol in the title part of the ``BlockHeader`` of ``CodeBlockView``.

- [x] Add `static let codeBlock = "chevron.left.forwardslash.chevron.right"` to `AgentSymbol` (`Sources/AgentViewKit/Items/AgentSymbol.swift`), with a doc comment.
- [x] In the header of ``CodeBlockView``, show `Image(systemName: AgentSymbol.codeBlock)` before the title, with `.symbolColumn()` and `.accessibilityHidden(true)`, in the color of the title (`themeSecondary`), at the spacing `editorStyle.spacing.s` (the spacing of the terminal header).
- [x] The VoiceOver label of the block (`CodeBlockView.accessibilityLabel`, for example "swift code block") does not change.

## Acceptance Criteria
- [x] `NSImage(systemSymbolName: AgentSymbol.codeBlock, accessibilityDescription: nil)` is not `nil` (the symbol exists on this macOS).
- [ ] A ``CodeBlockView`` and a ``TerminalView`` of the same width, with the same frame, start the text of their header title at the same x (the symbol column makes them align).
- [ ] The header of a code block with no language and no filename also shows the symbol, before "plain text".
- [x] The current tests of ``CodeBlockView`` pass with no change.

## Tests
- [x] `Tests/AgentViewKitTests/Code/CodeBlockSymbolTests.swift` (new): the symbol name exists (`NSImage(systemSymbolName:)` is not `nil`), and `CodeBlockView(code:language:).accessibilityLabel` does not change.
- [x] `IntegrationTests/Tests/IntegrationTests/Code/CodeBlockViewHostedTests.swift`: add a test that mounts a ``CodeBlockView`` and a ``TerminalView`` with a command at the same width, and compares the x of the accessibility frame of the code block title and of the terminal command (`TerminalView.commandIdentifier`). Only compile it (`cd IntegrationTests && swift build --build-tests`).
- [x] The `code-block` snapshot in `ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift` (`theCodeBlock`) shows the symbol; compile only (`cd ScreenshotTests && swift build --build-tests`), for the user to review.
- [x] Run `swift test` in the repo root. Expected: all tests pass, 0 failures.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Run only the headless `swift test`. Do not run the IntegrationTests or ScreenshotTests suites (they take the screen focus); a build of them is allowed.