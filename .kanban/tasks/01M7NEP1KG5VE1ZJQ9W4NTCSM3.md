---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffdf80
title: 'AVK-9.1: RenderedMarkdownView — read-only EditorKit rendered Markdown for static text'
---
D185, EK-14 (EditorKit fa62a572). First step of AVK-9.

Add an internal `RenderedMarkdownView(text:)`. Recipe from editorkit-7a:
- `EditorModel(text)`, `isReadOnly = true`.
- `EditorView(model:)` with `.editorSyntax(.markdown)`, `.editorPresentation(.rendered)`, `.editorSizingMode(.intrinsic)`, `.editorWrapMode(.viewportWidth)`, `.editorFontRole(.display)`.
- Keep the model in `@State`. When the text changes, replace the text of the model.

Use it in `AttachmentTextContent` (Markdown type) and in `ConversationEmptyState`. This removes `StructuredText(markdown:)` from AttachmentPreview.swift.

Acceptance: unit tests for the configuration; hosted tests compile; gallery compiles. No streaming.

#avk-9