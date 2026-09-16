---
comments:
- actor: claude-code
  id: 01m2n4kdpy9f60svwzbya2yxm3
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the task cannot start. The code part needs types that do not exist yet.
    - `PermissionPresentation.order(for:)` and `isSecondary(_:)` need `PermissionOption.Kind`. Task 01M21BD0YVS2J4MD6VXDM317W6 (Pending request types) makes that type. It is in todo.
    - `showsSwitchToAuto(configOptions:)` needs `ConfigOption` and `ConfigOption.Category`. Task 01M21BYFK7KVCKXYXJFCJW7FSM (TerminalRecord and ConfigOption types) makes that type. It is in todo.
    - This task depends only on 01M21A8RWGWE533JR6GQ4DNN06. Add the two tasks above to `depends_on`, then start this task again.
    - test: not run. commit: none. review: not run.
  timestamp: 2026-09-16T12:55:52.798676+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BD0YVS2J4MD6VXDM317W6
- 01M21BYFK7KVCKXYXJFCJW7FSM
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