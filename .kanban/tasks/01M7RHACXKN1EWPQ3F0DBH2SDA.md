---
assignees:
- claude-code
position_column: todo
position_ordinal: '8380'
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