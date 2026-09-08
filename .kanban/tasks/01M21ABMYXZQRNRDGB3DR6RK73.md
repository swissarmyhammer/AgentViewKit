---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: '8680'
title: AgentTheme tokens, .agentTheme modifier, and the EditorKit Theme bridge (plan §5, §11#11)
---
## What
Create `Sources/AgentViewKit/Theme/AgentTheme.swift`, `AgentThemeEnvironment.swift`, and `AgentTheme+EditorKit.swift`, per plan.md §5 and decision 11.

- `AgentTheme`: `spacing` (xs, s, m, l), `radii` (s, m, l), `materialLevel` (`regular`, `thin`, `clear`), `symbolWeight`, `accent: Color`, `density` (`compact`, `balanced`, `detailed`), `proseFont`, `codeFont`, and the status colors (`running`, `completed`, `failed`, `cancelled`, `pending`).
- `AgentTheme.default`: the initial values live in `Tests/AgentViewKitTests/Theme/DefaultTokens.json` and the code. Research R12 revises both files together later.
- `EnvironmentValues.agentTheme` and `View.agentTheme(_:)`.
- `AgentTheme.editorTheme: any EditorTheme.Theme`: a bridge that maps `accent` to `tokenTint`, the code font to the editor font, and system colors to `editorBackground`, `editorForeground`, `selection`, and `gutterBackground`. Views that host EditorKit apply it with `.editorTheme(_:)`.
- `AgentTheme.rowPadding` is a computed value from `density` and `spacing`.

## Acceptance Criteria
- [ ] A hosted view under `.agentTheme(custom)` reads `custom` from the environment (assert through a probe view that writes the accent into its accessibility value).
- [ ] `AgentTheme.default.editorTheme.tokenTint == AgentTheme.default.accent`.
- [ ] `AgentTheme.default` equals the values in `DefaultTokens.json` field by field.
- [ ] `rowPadding` is strictly increasing from `compact` to `balanced` to `detailed`.

## Tests
- [ ] `Tests/AgentViewKitTests/Theme/AgentThemeTests.swift`: the JSON match, the environment probe with the harness, the bridge mapping, the density order.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.