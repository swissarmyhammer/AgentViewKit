# Code block source

Status: decided. Source: plan.md §4.1, §4.2, §8. Task ^3m70z7f.

Revision of 2026-11-17 (AVK-9.8, D185): the kit does not use Textual any
more. A fenced code block of an answer shows in the rendered form of
EditorKit (`RenderedMarkdownView`), in the same text layout as the prose.
The kit removed `EditorKitCodeBlockStyle`, the `Mirror` read of the raw
code, the `\.codeBlockID` environment value and the
`codeBlockModelCache(_:blockID:)` modifier. "The raw code" and the parts of
"The model cache" about Textual are history. `CodeBlockView` stays: a tool
call, a resource and a source attachment show their code in it, and
`CodeBlockModelCache` keeps the model of each `ResponseView`.

This file records how `EditorKitCodeBlockStyle` gets the code of a fenced
block from Textual, and the related decisions of `CodeBlockView`.

## The raw code

- Textual 0.5.0 gives `CodeBlockStyleConfiguration` with `label`,
  `indentationLevel`, `languageHint`, `codeBlock`, and `highlighterTheme`.
  No public member gives the raw code.
- `StructuredText.CodeBlockProxy` keeps the code in the private stored
  property `content: AttributedSubstring`. Textual removes the last newline
  before it makes the proxy.
- `EditorKitCodeBlockStyle.code(of:)` reads `content` with `Mirror`. When the
  read fails, the style shows an empty block.
- The manifest pins Textual to the exact version 0.5.0. The hosted test
  `aFencedBlockInATextualDocumentMountsACodeBlock` copies the code of a real
  Textual block. When a Textual update changes the property, that test fails.
- Rejected: a second Markdown parse in the kit. It duplicates the Textual
  parse and can disagree with it.
- Follow-up: ask Textual for a public `code` member on `CodeBlockProxy`. When
  it exists, remove the `Mirror` read.

## The pasteboard

- The `Pasteboard` protocol of the test-support task (^he8kkt1) has the
  requirement `copyText(_:)`. The task text says `setString(_:)`. The kit
  keeps `copyText(_:)`, because the views and their tests use it, and
  because `NSPasteboard` already has a `setString(_:forType:)` method. The
  tests copy to an isolated `NSPasteboard` of EditorKit
  (`NSPasteboard.withIsolated`).
- `EnvironmentValues.pasteboard` defaults to `NSPasteboard.general`.

## The label and the header

- The accessibility label is "<language> code block". The language is the
  language hint with no whitespace at the start or the end. When the hint is
  missing or empty, the label is "plain text code block".
- The label uses the hint also when EditorKit has no grammar for it. A
  "python code block" label is more useful than "plain text code block".
  The grammar controls only the syntax colors.
- The header shows the filename, or the language, or "plain text".

## The model cache

- `CodeBlockID` is the message id plus the paragraph id of the splitter.
  A fenced block is one paragraph.
- `codeBlockModelCache(_:blockID:)` puts the cache and the id in the
  environment of one paragraph. `EditorKitCodeBlockStyle` reads them.
- A cached model keeps its text. `CodeBlockView` calls
  `EditorModel.syncStreaming(to:)` when its code changes. That call appends
  the new suffix, or replaces the full text when the old text is not a
  prefix.
- A streaming edit does not go into the undo history.
