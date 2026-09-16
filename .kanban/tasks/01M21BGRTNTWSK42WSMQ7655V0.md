---
comments:
- actor: claude-code
  id: 01m2nfm7k2hx5z0fpbwzh7xre2
  text: |-
    ### implement — changed
    - Decision: no screen captures. The agent has no screen recording permission, and a capture of the screen can show private content. The Claude Desktop 1.34493.1 values come from the Claude Design System token sheet in its app.asar (exact values; the window uses data-density="comfortable"). The Xcode 27.0 text sizes (body 13 pt, SF Mono 13 pt) and the accent come from AppKit. The Xcode 27 bundle has no metric file, so the Xcode spacing and radii are not measured; the kit uses the Claude Desktop values. Docs/decisions/visual-audit.md records this. A person can add captures later.
    - Changed defaults: spacing.l 20 -> 16, radii 4/8/12 -> 6/8/10. Other tokens stay the same. DefaultTokens.json has the same values.
    - Tool row height and usage ring size get no theme token (the CDS sheet has no token for them).
    - Moved the name lookup of AgentThemeTests to Theme/ThemeTokenNames.swift, so that the golden test and the JSON test use one lookup.
    - evidence: swift test: 377 tests in 33 suites pass; no new build warnings.
    - next: commit, then review HEAD~1..HEAD.
  timestamp: 2026-09-16T16:08:33.634716+00:00
depends_on:
- 01M21ABMYXZQRNRDGB3DR6RK73
position_column: doing
position_ordinal: '8180'
title: 'Research R12: visual audit of Xcode 27 and Claude Desktop, recorded as the AgentTheme default token table (plan §5, §14)'
---
## What
Settle research R12 from plan.md §14 and record it where the code can check it.

- Measure the Xcode 27 beta Coding Intelligence assistant and Claude Desktop: row padding, message inset, corner radii, fonts and sizes for prose and code, tool row height, the usage ring size, and the accent use. Record the measurements with screenshots under `Docs/decisions/visual-audit/` and the chosen values in `Docs/decisions/visual-audit.md`.
- Encode the decision: `AgentTheme.default` values match the table. `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift` parses the table from the decision file and asserts every token equals the default.

## Acceptance Criteria
- [x] `Docs/decisions/visual-audit.md` exists with a token table.
- [x] `AgentThemeGoldenTests` passes against `AgentTheme.default`.

## Tests
- [x] `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.