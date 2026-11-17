---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7nvtzvwftj98a29fzx94dat
  text: |-
    ### implement — changed
    - evidence: commit a92da599 (with AVK-9.7). MathView, MathMarkdownParser, MathSpanScanner, the spoken math text and MathMarkdownParserTests are removed. swiftui-math is out of Package.swift (Textual 0.5.0 still links it). Unit tests: ThreadAccessibilityTests checks the TeX source of each math span through EditorKit MathSpans. Hosted test: the math element has the label "Math" and the value "x^2" (compiles, not run).
    - next: review. Docs/decisions/math-engine.md is left for AVK-9.8.
  timestamp: 2026-11-17T23:00:27.132467+00:00
depends_on:
- 01M7NEPK3QHB30W786RBDV6CER
position_column: done
position_ordinal: ffffffe580
title: 'AVK-9.3: Math in chat Markdown uses EditorKit math; remove MathMarkdownParser'
---
D185. EditorKit has math built in (iosMath 2.5.0): `$…$`, `\(…\)` inline; `$$…$$`, `\[…\]`, ```` ```math ```` block. A copy gives the TeX source.

Remove `MathMarkdownParser`, `MathSpanAttachment` and the spoken-math text of `MarkdownProse`. Keep `MathView` only if a view outside Markdown still needs it. Then check whether the `swiftui-math` package (`@_spi(Textual)`) can leave Package.swift.

Acceptance: unit tests for the VoiceOver text of math through EditorKit; MathMarkdownParserTests are removed or rewritten.

#avk-9