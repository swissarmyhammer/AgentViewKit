---
assignees:
- claude-code
depends_on:
- 01M7YZJF2WT82MEFW3DACB63ES
position_column: todo
position_ordinal: '8580'
title: The header of a code block shows a code symbol in the symbol column, as the terminal header does
---
## What
The header of ``TerminalView`` (`Sources/AgentViewKit/Terminal/TerminalView.swift`, `header`) starts with a single-color SF Symbol in the symbol column: `EditorSymbolImage(.tool(.execute)).symbolColumn().accessibilityHidden(true)`. The header of ``CodeBlockView`` (`Sources/AgentViewKit/Code/CodeBlockView.swift`, `header`) shows only the title (the filename or the language) and the Copy button, with no symbol. The user decided (2026-11-21): a code block shows one SF Symbol, the same for each language, in the symbol column, so that it matches the terminal and shell headers.

This task depends on the shared ``BlockHeader`` task (01M7YZJF2WT82MEFW3DACB63ES), because that task moves the header of ``CodeBlockView`` into ``BlockHeader``. Put the symbol in the title part of the ``BlockHeader`` of ``CodeBlockView``.

- [ ] Add `static let codeBlock = "chevron.left.forwardslash.chevron.right"` to `AgentSymbol` (`Sources/AgentViewKit/Items/AgentSymbol.swift`), with a doc comment.
- [ ] In the header of ``CodeBlockView``, show `Image(systemName: AgentSymbol.codeBlock)` before the title, with `.symbolColumn()` and `.accessibilityHidden(true)`, in the color of the title (`themeSecondary`), at the spacing `editorStyle.spacing.s` (the spacing of the terminal header).
- [ ] The VoiceOver label of the block (`CodeBlockView.accessibilityLabel`, for example "swift code block") does not change.

## Acceptance Criteria
- [ ] `NSImage(systemSymbolName: AgentSymbol.codeBlock, accessibilityDescription: nil)` is not `nil` (the symbol exists on this macOS).
- [ ] A ``CodeBlockView`` and a ``TerminalView`` of the same width, with the same frame, start the text of their header title at the same x (the symbol column makes them align).
- [ ] The header of a code block with no language and no filename also shows the symbol, before "plain text".
- [ ] The current tests of ``CodeBlockView`` pass with no change.

## Tests
- [ ] `Tests/AgentViewKitTests/Code/CodeBlockSymbolTests.swift` (new): the symbol name exists (`NSImage(systemSymbolName:)` is not `nil`), and `CodeBlockView(code:language:).accessibilityLabel` does not change.
- [ ] `IntegrationTests/Tests/IntegrationTests/Code/CodeBlockViewHostedTests.swift`: add a test that mounts a ``CodeBlockView`` and a ``TerminalView`` with a command at the same width, and compares the x of the accessibility frame of the code block title and of the terminal command (`TerminalView.commandIdentifier`). Only compile it (`cd IntegrationTests && swift build --build-tests`).
- [ ] The `code-block` snapshot in `ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift` (`theCodeBlock`) shows the symbol; compile only (`cd ScreenshotTests && swift build --build-tests`), for the user to review.
- [ ] Run `swift test` in the repo root. Expected: all tests pass, 0 failures.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Run only the headless `swift test`. Do not run the IntegrationTests or ScreenshotTests suites (they take the screen focus); a build of them is allowed.