---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: todo
position_ordinal: be80
title: 'Research R8: permission and mode option sets from Claude Code, Cursor, and Codex, mapped to ACP (plan §14)'
---
## What
Settle research R8 from plan.md §14 and record it where the code can check it.

- Survey the permission option sets and permission modes in Claude Code, Cursor, and Codex from their current docs. Record them in `Docs/decisions/permission-ux.md` with URLs and dates.
- Map each product option onto the four ACP `PermissionOptionKind`s and the `mode` config option category. Decide the kit's option order, which options are visually secondary, when "switch to auto" appears, and whether a fifth directory-scoped option exists in v1 and which source supplies it. Write the decision table in the same file.
- Encode the decision: `Sources/AgentViewKit/HumanInTheLoop/PermissionPresentation.swift` with `PermissionPresentation.order(for kinds:)`, `isSecondary(kind)`, and `showsSwitchToAuto(configOptions:)`. `PermissionView` reads these.

## Acceptance Criteria
- [ ] `Docs/decisions/permission-ux.md` exists with the survey and the decision table.
- [ ] `PermissionPresentation` matches the decision table (a test parses the table rows from the file and compares).

## Tests
- [ ] `Tests/AgentViewKitTests/HumanInTheLoop/PermissionPresentationTests.swift`: the decision-file match and the three functions.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.