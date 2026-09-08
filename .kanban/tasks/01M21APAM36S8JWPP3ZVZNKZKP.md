---
depends_on:
- 01M21AH4QCEFEBPTZ8GR061H51
position_column: todo
position_ordinal: a480
title: MathView on a Core Text engine, wired to Textual math spans (plan §9 B, §11#7, research R9)
---
## What
Create `Sources/AgentViewKit/Content/MathView.swift`, per plan.md decision 7. This task settles research R9.

- Evaluate Textual's `.math` syntax extension (backed by `gonzalezreal/swiftui-math` 0.1.0) against `SwiftMath` (Core Text). Measure: inline and block rendering, Dynamic Type, Reduce Motion, and re-render cost inside a streaming paragraph. Record the measurements and the decision in `Docs/decisions/math-engine.md` with an `engine:` line. Add the chosen package to `Package.swift` with an exact version.
- `MathView(latex:display:)`: renders inline or block LaTeX with the chosen engine. Falls back to the raw source in monospace when parsing fails, never a blank. `static let engineName: String`.
- Enable the Textual math extension in `ResponseView` and route its spans to `MathView`. If Textual's own math view is chosen, this is a style hook; if SwiftMath is chosen, the extension's span view is replaced.
- Accessibility identifier `math-inline` or `math-block`, label the LaTeX source.

## Acceptance Criteria
- [ ] `$E = mc^2$` inside a paragraph mounts one `math-inline` element; `$$\int_0^1 x\,dx$$` mounts one `math-block` element.
- [ ] Malformed LaTeX mounts an element whose value is the source text.
- [ ] `MathView.engineName` equals the `engine:` line in `Docs/decisions/math-engine.md` (a test parses it).

## Tests
- [ ] `Tests/AgentViewKitTests/Content/MathViewHostedTests.swift`: inline, block, malformed, label.
- [ ] `Tests/AgentViewKitTests/Content/MathEngineDecisionTests.swift`: the decision-file match.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.