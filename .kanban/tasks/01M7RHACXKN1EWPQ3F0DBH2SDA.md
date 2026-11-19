---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7rmscdx80y3rbr22s15cx02
  text: |-
    ### implement — changed
    - EditorKit pin is now 8a5a1c2f (fix f3dd0d7b) in the root, IntegrationTests and ScreenshotTests (Package.resolved is not tracked).
    - CodeBlockAnswerFixture: new `fenceEndingMarkdown` (no line break after the closing fence). `markdown` is now `fenceEndingMarkdown + "\n"`. The note about this bug is removed.
    - AnswerCodeBlockItemMenuTests: `mount` takes `markdown`. New test `copyCodeBlockOfAnAnswerThatEndsWithItsFenceCopiesNoFence`. RED on 8a5d8bae (the pasteboard had the code and "```"). GREEN on 8a5a1c2f.
    - evidence: swift test: 1400 Swift Testing tests in 164 suites pass, 54 in 11 pass, 0 XCTest. IntegrationTests and ScreenshotTests: swift build --build-tests complete. swift format lint -s: 0 findings. No other test needed a change.
    - Note: SwiftPM shows the warning "missing creator for mutated node" for the mlx-swift_Cmlx bundle. It comes from the build system and the mlx dependency, not from this change.
    - next: review
  timestamp: 2026-11-19T00:54:57.725508+00:00
- actor: claude-code
  id: 01m7rmwaztr3mpygn8gfysygt4
  text: |-
    ### test — green
    - evidence: swift test at package root. "Test run with 1400 tests in 164 suites passed after 30.734 seconds." and "Test run with 54 tests in 11 suites passed after 0.011 seconds." swift format lint -s on the 2 changed Swift files: no findings. swift build --build-tests in IntegrationTests: Build complete. IntegrationTests and ScreenshotTests were not run.
    - next: review
  timestamp: 2026-11-19T00:56:34.554296+00:00
position_column: doing
position_ordinal: '80'
title: Copy Code Block copies the closing fence when the answer ends with the fence and no line break (EditorKit)
---
Found in ^4h5jq7h.

Now: EditorKit 8a5d8bae. When the closing fence of a code block is the end of the document, with no line break after it, `FencedCodeBlock.content` includes the closing fence. Thus `EditorModel.codeBlockContext(atUTF8Offset:)` and `CommandContext.codeBlock?.text` give the code AND the fence line. AVK `copyCodeBlock` then copies "```" at the end of the code. An agent answer often ends with a closing fence and no line break.

Repro (rendered model, Markdown grammar, parse done):
- "```swift\nlet a = 1\n```" gives text "let a = 1\n```", content 9..<22.
- "```swift\nlet a = 1\n```\n" gives text "let a = 1", content 9..<19.
- "P.\n\n```swift\nlet a = 1\n```" gives text "let a = 1\n```".

Do:
- Ask editorkit-7a to fix the content range (or the code text) of a block whose closing fence ends the document.
- Update the EditorKit pin in AVK, and add an AVK unit test: Copy Code Block of the item menu of an answer that ends with "```" copies the code with no fence. The suite `AnswerCodeBlockItemMenuTests` can take a second answer for it.