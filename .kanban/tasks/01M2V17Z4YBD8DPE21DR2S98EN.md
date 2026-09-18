---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m2v1ve7wx2askr0pptar7we3
  text: |
    ### finish iteration 1 — done

    - implement: `Package.swift` had the exact pin `exact: "0.1.0"` already, thus no change there. Added the section "The SPI symbols" to `Docs/decisions/math-engine.md`. It names the two files that import the `Textual` SPI (`Sources/AgentViewKit/Content/MathView.swift` and `Sources/AgentViewKit/Content/MathMarkdownParser.swift`), each SPI symbol that they use (`Math.typographicBounds(for:fitting:font:style:)`, `Math.TypographicBounds`, and its `width`, `descent`, and `size` members), and the public symbols. A `review:` paragraph tells a person to read the SPI of a new version, compare it with the table, and record the result, before the pin moves. Added three tests to `MathEngineDecisionTests`.
    - test: `swift test` passed. AgentViewKitTests 1283 (1280 before, three new tests), AgentViewKitACPTests 102, AgentViewKitRouterTests 74, PackageStructureTests 23, AgentViewKitFoundationModelsTests 48. Only the accepted mlx-swift build warning.
    - commit: 3da9619 `docs(math): record each SPI symbol of the math engine (^r2s98en)`.
    - review: `review sha HEAD~1..HEAD` gave zero findings.
  timestamp: 2026-09-18T20:03:16.348965+00:00
position_column: done
position_ordinal: ca80
title: Pin swiftui-math to the exact version and record the SPI symbols
---
MathView draws through the SPI of swiftui-math, not through its public API. An update of that package can break the view with no warning.

## Acceptance criteria
- [x] Package.swift pins swiftui-math to the exact version 0.1.0 (`.exact("0.1.0")`), not to a range.
- [x] `Docs/decisions/math-engine.md` names each SPI symbol that MathView uses, and says that a person must look at a new version before the pin moves.
- [x] All tests pass, and no test count goes down.

## Tests
- [x] The existing MathView tests still pass.

## Review Findings (2026-09-18)
- [x] No finding. `review sha HEAD~1..HEAD` gave zero findings.
