---
depends_on:
- 01M21ABMYXZQRNRDGB3DR6RK73
position_column: todo
position_ordinal: bf80
title: 'Research R12: visual audit of Xcode 27 and Claude Desktop, recorded as the AgentTheme default token table (plan §5, §14)'
---
## What
Settle research R12 from plan.md §14 and record it where the code can check it.

- Measure the Xcode 27 beta Coding Intelligence assistant and Claude Desktop: row padding, message inset, corner radii, fonts and sizes for prose and code, tool row height, the usage ring size, and the accent use. Record the measurements with screenshots under `Docs/decisions/visual-audit/` and the chosen values in `Docs/decisions/visual-audit.md`.
- Encode the decision: `AgentTheme.default` values match the table. `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift` parses the table from the decision file and asserts every token equals the default.

## Acceptance Criteria
- [ ] `Docs/decisions/visual-audit.md` exists with a token table.
- [ ] `AgentThemeGoldenTests` passes against `AgentTheme.default`.

## Tests
- [ ] `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.