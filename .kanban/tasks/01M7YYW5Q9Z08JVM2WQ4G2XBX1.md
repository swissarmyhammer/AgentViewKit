---
assignees:
- claude-code
position_column: todo
position_ordinal: '8380'
title: A response in the thread shows each fenced code block in CodeBlockView
---
## What
In the chat stream, a fenced code block of a response does not use ``CodeBlockView``. ``ResponseView`` (`Sources/AgentViewKit/Content/ResponseView.swift`, the `editor` property) shows all of the Markdown of a response in one ``RenderedMarkdownView`` (`Sources/AgentViewKit/Content/RenderedMarkdownView.swift`). EditorKit draws each fence inside that editor, with its own header (`editorCodeBlockHeader`). That header is a bad near duplicate of the header of ``CodeBlockView`` (`Sources/AgentViewKit/Code/CodeBlockView.swift`): the grey language label does not align with the left edge of the code, the space above it is not the same as the space below it, and it has no line numbers and no Copy button. The user decided (2026-11-21): use the ``CodeBlockView`` that is there, for each fence of a response.

- [ ] Add `Sources/AgentViewKit/Content/MarkdownCodeFences.swift`: `nonisolated enum MarkdownCodeFences` with `static func segments(in markdown: String) -> [MarkdownSegment]`. `MarkdownSegment` is `.prose(String)` or `.code(code: String, language: String?, filename: String?)`. Use the CommonMark fence rules (3 or more backticks or tildes, up to 3 spaces of indent; the closing fence uses the same character and is not shorter). Read the language and the file name from the info string as EditorKit `FencedCodeBlock` does (`../EditorKit/Sources/EditorText/Syntax/FencedCodeBlocks.swift`). A fence with no closing line (a response that still streams) is a `.code` segment up to the end of the text. Follow the style of `Sources/AgentViewKit/Content/MarkdownParagraphs.swift`.
- [ ] In ``ResponseView``, show the segments in a `VStack(alignment: .leading)`: each `.prose` segment in ``RenderedMarkdownView``, each `.code` segment in ``CodeBlockView``(code:language:filename:). Key each segment by its index, so a streamed chunk updates only the last segment.
- [ ] A text with no fence keeps the current single ``RenderedMarkdownView`` path with no change.

## Acceptance Criteria
- [ ] `MarkdownCodeFences.segments(in: "Intro.\n\n```swift\nlet a = 1\n```\n\nEnd.")` returns `.prose("Intro.")`, `.code(code: "let a = 1", language: "swift", filename: nil)`, `.prose("End.")`.
- [ ] A fence with no closing line gives a `.code` segment with all the lines after the opening fence.
- [ ] A text with no fence gives exactly one `.prose` segment that is equal to the text.
- [ ] A response with one fence shows one ``CodeBlockView`` (accessibility identifier `CodeBlockView.identifier`, "code-block") with the language label of the fence, and the prose before and after it in ``RenderedMarkdownView``.
- [ ] A response with no fence shows one ``RenderedMarkdownView`` and no ``CodeBlockView``.
- [ ] The current tests in `Tests/AgentViewKitTests/Content/` pass with no change.

## Tests
- [ ] New `Tests/AgentViewKitTests/Content/MarkdownCodeFencesTests.swift`: backtick and tilde fences, a longer closing fence, an indented fence, an info string with a language and a file name, an unclosed fence at the end, two fences one after the other, and a text with no fence.
- [ ] `Tests/AgentViewKitTests/Content/ResponseViewTests.swift`: a response with one fence makes prose, ``CodeBlockView``, prose; a response with no fence makes one ``RenderedMarkdownView``.
- [ ] `ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift`: add a snapshot of a response with prose and one Swift fence, for the user to review. Only compile it (`cd ScreenshotTests && swift build --build-tests`).
- [ ] Run `swift test` in the repo root. Expected: all tests pass, 0 failures.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Run only the headless `swift test`. Do not run the IntegrationTests or ScreenshotTests suites (they take the screen focus); a build of them is allowed.