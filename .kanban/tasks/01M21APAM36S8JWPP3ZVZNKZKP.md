---
comments:
- actor: claude-code
  id: 01m2nxtzpnfrgmcy2bhzckrhqr
  text: 'Note from ^r061h51: `ResponseView` makes `StructuredText(markdown:)` in two places: `ParagraphView.body` (Sources/AgentViewKit/Content/ParagraphView.swift) and the private `StreamingTail` (Sources/AgentViewKit/Content/ResponseView.swift). Add the `.math` syntax extension in both places, so that settled paragraphs and the streaming tail parse math the same way.'
  timestamp: 2026-09-16T20:16:54.997308+00:00
- actor: claude-code
  id: 01m2p0m5ehmqpq24p4qr9stkj1
  text: |-
    ### Decisions (R9)
    - engine: `swiftui-math` 0.1.0, pinned exact. Textual 0.5.0 already links it. SwiftMath 1.7.3 is the same iosMath code with the same 7.1 MB fonts, an NSView, and tools 5.7, so it adds a second copy. Docs/decisions/math-engine.md has the table and the measurements.
    - The kit does not use Textual `.math`: the Markdown parse removes the backslash of `\,` and `\\` before `.math` runs. `MathSpanScanner` finds spans in the raw text; `MathMarkdownParser` puts markers in their place, parses with Textual, and puts a `MathSpanAttachment` (a `MathView`) at each marker. Inline math follows the Pandoc rule, so "$5 and $10" is not math. ParagraphView and the streaming tail both use `MarkdownProse` (the note from ^r061h51 is done this way).
    - A paragraph that is only `$$…$$` shows a centered block `MathView`.
    - Parse errors: `Math.typographicBounds` (SPI `Textual`) is zero. Malformed spans in a paragraph become inline code with the source.
    - Canvas attachments have no accessibility children, so `MathSpanAccessibility` adds one element for each span. A note for the reading order is on ^6vztrss.

    ### implement — changed
    - evidence: MathView.swift, MathMarkdownParser.swift, MathSpanScanner.swift, MarkdownProse.swift, Package.swift, 2 decision files, 3 test files.
    - next: test, commit, review.
  timestamp: 2026-09-16T21:05:37.233132+00:00
depends_on:
- 01M21AH4QCEFEBPTZ8GR061H51
position_column: doing
position_ordinal: '8180'
title: MathView on a Core Text engine, wired to Textual math spans (plan §9 B, §11#7, research R9)
---
## What
Create `Sources/AgentViewKit/Content/MathView.swift`, per plan.md decision 7. This task settles research R9.

- Evaluate Textual's `.math` syntax extension (backed by `gonzalezreal/swiftui-math` 0.1.0) against `SwiftMath` (Core Text). Measure: inline and block rendering, Dynamic Type, Reduce Motion, and re-render cost inside a streaming paragraph. Record the measurements and the decision in `Docs/decisions/math-engine.md` with an `engine:` line. Add the chosen package to `Package.swift` with an exact version.
- `MathView(latex:display:)`: renders inline or block LaTeX with the chosen engine. Falls back to the raw source in monospace when parsing fails, never a blank. `static let engineName: String`.
- Enable the Textual math extension in `ResponseView` and route its spans to `MathView`. If Textual's own math view is chosen, this is a style hook; if SwiftMath is chosen, the extension's span view is replaced.
- Accessibility identifier `math-inline` or `math-block`, label the LaTeX source.

## Acceptance Criteria
- [x] `$E = mc^2$` inside a paragraph mounts one `math-inline` element; `$$\int_0^1 x\,dx$$` mounts one `math-block` element.
- [x] Malformed LaTeX mounts an element whose value is the source text.
- [x] `MathView.engineName` equals the `engine:` line in `Docs/decisions/math-engine.md` (a test parses it).

## Tests
- [x] `Tests/AgentViewKitTests/Content/MathViewHostedTests.swift`: inline, block, malformed, label.
- [x] `Tests/AgentViewKitTests/Content/MathEngineDecisionTests.swift`: the decision-file match.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.