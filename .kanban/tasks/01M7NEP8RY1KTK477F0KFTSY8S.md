---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: 'AVK-9.3: Math in chat Markdown uses EditorKit math; remove MathMarkdownParser'
---
D185. EditorKit has math built in (iosMath 2.5.0): `$…$`, `\(…\)` inline; `$$…$$`, `\[…\]`, ```` ```math ```` block. A copy gives the TeX source.

Remove `MathMarkdownParser`, `MathSpanAttachment` and the spoken-math text of `MarkdownProse`. Keep `MathView` only if a view outside Markdown still needs it. Then check whether the `swiftui-math` package (`@_spi(Textual)`) can leave Package.swift.

Acceptance: unit tests for the VoiceOver text of math through EditorKit; MathMarkdownParserTests are removed or rewritten.

#avk-9