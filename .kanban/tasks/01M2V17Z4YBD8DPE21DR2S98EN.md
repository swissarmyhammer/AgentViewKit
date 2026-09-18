---
assignees:
- claude-code
position_column: doing
position_ordinal: '80'
title: Pin swiftui-math to the exact version and record the SPI symbols
---
MathView draws through the SPI of swiftui-math, not through its public API. An update of that package can break the view with no warning.

## Acceptance criteria
- [ ] Package.swift pins swiftui-math to the exact version 0.1.0 (`.exact("0.1.0")`), not to a range.
- [ ] `Docs/decisions/math-engine.md` names each SPI symbol that MathView uses, and says that a person must look at a new version before the pin moves.
- [ ] All tests pass, and no test count goes down.

## Tests
- [ ] The existing MathView tests still pass.