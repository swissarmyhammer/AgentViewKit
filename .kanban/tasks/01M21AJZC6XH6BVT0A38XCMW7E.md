---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: 9a80
title: ConfigOptionsView and PermissionModePicker (plan §9 D, §9 E, §11#16)
---
## What
Create `Sources/AgentViewKit/Config/ConfigOptionsView.swift` and `PermissionModePicker.swift`, per plan.md §9 D and decision 16.

- `ConfigOptionsView(options:)`: groups by `category` in the order mode, model, thought level, model config, then uncategorized. A `select` option renders a `Picker` (with sections when the options are grouped); a `boolean` renders a `Toggle`. Each change calls `AgentThreadActions.setConfigOption`. The view is a menu for the toolbar and a `Form` for a settings sheet, chosen by a style parameter.
- `PermissionModePicker(options:)`: the `mode` category option as a segmented `Picker` for the composer accessory. Hidden when no mode option exists.
- Both read `thread.configOptions` and update when the list is replaced.

## Acceptance Criteria
- [ ] A select with groups renders sections with the group names.
- [ ] Changing a toggle calls `setConfigOption` with `.boolean`.
- [ ] `PermissionModePicker` is absent when no `mode` option exists.

## Tests
- [ ] `Tests/AgentViewKitTests/Config/ConfigOptionsViewHostedTests.swift`: grouping, sections, and the calls through `NoopThreadActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.