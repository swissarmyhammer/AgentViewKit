# Math engine

Status: decided. Source: plan.md §9 B, §11 decision 7, §14 research R9.
Task ^vznkzkp. Date: 2026-09-16.

This file records the math engine of `MathView` and how `ResponseView` routes
math spans to it. `Tests/AgentViewKitTests/Content/MathEngineDecisionTests.swift`
reads the `engine:`, `url:`, and `version:` lines. It compares them with
`MathView.engineName`, `Package.swift`, and `Package.resolved`. Keep the form of
these three lines.

engine: `swiftui-math`
url: `https://github.com/gonzalezreal/swiftui-math`
version: `0.1.0`

## Candidates

| candidate | version | typesetting | view | in the build now | parse error API |
|---|---|---|---|---|---|
| Textual `.math` | Textual 0.5.0 | swiftui-math | internal `MathAttachment`, drawn in a canvas | yes | none |
| `swiftui-math` | 0.1.0 | Core Text (`CTLine`, OpenType MATH table) | SwiftUI `Math` view | yes, Textual depends on it | `Math.typographicBounds` (SPI `Textual`) is zero |
| `SwiftMath` | 1.7.3 | Core Text (a Swift port of iosMath) | `MTMathUILabel`, an `NSView` | no | `MTMathListBuilder.build(fromString:error:)` |
| `iosMath` | not maintained | Core Text, Objective-C | `MTMathUILabel`, a `UIView` | no | yes |

- iosMath is Objective-C and has no maintained macOS build. It is rejected.
- SwiftMath and swiftui-math use the same code base (iosMath) and the same
  font bundle (7.1 MB, twelve OpenType math fonts). Textual 0.5.0 already
  links swiftui-math. SwiftMath adds a second copy of the engine and of the
  fonts to each app. It also needs an `NSViewRepresentable`, and its package
  uses tools version 5.7 with no `Sendable` annotations.
- Textual `.math` uses swiftui-math, but the kit cannot change its view, its
  accessibility, or its parse (see "The span parse").

Decision: the kit uses swiftui-math directly, pinned `exact` because it is a
0.x package. `MathView` shows a `Math` view.

## Measurements

Measured on macOS 27, debug build, in the `swift test` process, with the kit
parse and the kit view. The measurement test is not kept.

| measurement | result |
|---|---|
| typeset 50 new inline expressions (`canTypeset`) | 17 ms, 0.34 ms each |
| typeset 50 new block expressions | 10 ms, 0.20 ms each |
| typeset the same 50 inline expressions again (engine cache) | 0.03 ms |
| parse a 580-character paragraph with 10 inline spans, 200 times: kit parser | 54 ms, 0.27 ms each |
| the same, Textual Markdown with no math | 10 ms, 0.05 ms each |
| the same, Textual Markdown with `.math` | 142 ms, 0.71 ms each |
| parse each prefix of the paragraph in 8-character chunks (72 chunks): kit parser | 9.6 ms, 0.13 ms each |
| the same, Textual Markdown with no math | 1.9 ms |

- Inline and block rendering: inline math uses the text style of the
  engine, block math uses the display style. A paragraph that is only one
  `$$…$$` block shows a block `MathView`, centered. Other math is an inline
  attachment in the Textual text.
- Dynamic Type: the math font size is the point size of the environment
  font times 1.2, the default of the Textual math properties. On macOS 27
  the `dynamicTypeSize` environment value does not change the resolved size
  of `.body` (13 pt at `.large`, `.xxxLarge`, and `.accessibility3`), for
  Textual and for the kit. Both follow the preferred text style size, so
  the math size follows the text size.
- In a heading, Textual sizes the attachment from its own font provider, and
  `MathView` draws from the resolved environment font. The two sizes differ
  by less than 0.3 % (h1: 36.71 pt and 36.60 pt; h2: 29.36 pt and 29.40 pt).
- Reduce Motion: `MathView` has no animation and no transition. Nothing
  changes.
- Streaming: the engine caches each parsed expression and each layout. A new
  chunk in the streaming tail parses the tail again (0.13 ms for a short
  tail) and typesets only new expressions. The kit parser is faster than
  Textual `.math`, because the math patterns run one time over the raw text,
  not on each attributed run.

## The span parse

- The Textual `.math` extension finds spans after the Markdown parse. The
  Markdown parse has already removed the backslash of an escape, so
  `\int_0^1 x\,dx` becomes `\int_0^1 x,dx` and the row break `\\` of a
  matrix becomes `\`. Thus the kit does not use `.math`.
- `MathSpanScanner` finds the spans in the raw text. `MathMarkdownParser`
  puts a private use marker (`U+E000`, index, `U+E001`) in place of each
  span, parses the Markdown with Textual, and then replaces each marker.
- Inline math follows the Pandoc rule: no whitespace after the opening `$`,
  no whitespace before the closing `$`, and no digit after the closing `$`.
  Thus "It costs $5 and $10" has no math. Textual `.math` makes math of
  that text.
- `\$` is a literal dollar sign. The scanner does not look in code spans or
  fenced code blocks. A marker that the Markdown parse puts in code (for
  example an indented code block) becomes the span source again.
- A fenced block with the `math` language hint still renders through the
  Textual math code block, because Textual checks that hint before the code
  block style.

## Parse errors

- swiftui-math has no public parse error API. `Math.typographicBounds` has
  zero width when the parse fails. It is marked `@_spi(Textual)`. The kit
  imports it with `@_spi(Textual) import SwiftUIMath`. The `exact` pin keeps
  the SPI stable. `theEngineTypesetsOnlyValidSource` fails when the SPI
  changes.
- `MathView` with source that does not parse shows the source in a
  monospaced font. In a paragraph, the span becomes inline code with the
  source. The kit never shows a blank.

## Accessibility

- Textual draws each attachment in a `Canvas`. A canvas has no
  accessibility children, so the math inside a paragraph has no element of
  its own.
- `MarkdownProse` adds `MathSpanAccessibility` in an overlay of the text.
  It makes one element for each span, with the identifier `math-inline` or
  `math-block`, the static text trait, and the LaTeX source as its label.
- The block `MathView` and the standalone `MathView` are their own
  elements with the same identifier and label. The element of the source
  fallback also has the source as its value.
- Follow-up for the accessibility task ^6vztrss (linked reading groups,
  plan.md §6): the paragraph text element does not read the math, and the
  math elements come after the text. A reading group that puts each math
  element at its place in the text is work for that task.
