---
comments:
- actor: claude-code
  id: 01m2p2mtbss1eb81y6cmejahbe
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Config/{ConfigOptionsView,PermissionModePicker}.swift; Tests/AgentViewKitTests/Config/ConfigOptionsViewHostedTests.swift; HostedViewHarness reads label, title, and identifier with no String cast (a Menu button gives an attributed string, and the typed read stopped the process), with a new harness test.
    - Decisions:
      - Both views take `options:` and do not read the thread. The host passes `thread.configOptions`, as for ContextUsageView and StateBanner. A host view that reads the thread updates both views when the list is replaced (hosted test).
      - An option with a category that the kit does not know goes to the last section ("Other"). An option with an unknown type is not shown.
      - `.menu` style: a Menu with menu pickers; grouped choices use `Section(group.name)`. `.form` style: a grouped Form. A select shows its values as an inline picker. An inline picker shows a Section header as a value that the user can select, so each choice group is its own inline picker with the group name as its label.
      - A boolean in the form is a checkbox Toggle. A press on a switch in a grouped Form fails in the harness.
      - The controls show the value from the source and do not keep a local value. A new value comes back through `setConfigOptions`.
      - A press on a segment of a segmented Picker stops the test process (as a stepper does). The mode picker test sets the shared binding. The harness doc now says this.
    - next: test
  timestamp: 2026-09-16T21:40:55.801497+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: doing
position_ordinal: '8180'
title: ConfigOptionsView and PermissionModePicker (plan §9 D, §9 E, §11#16)
---
## What
Create `Sources/AgentViewKit/Config/ConfigOptionsView.swift` and `PermissionModePicker.swift`, per plan.md §9 D and decision 16.

- `ConfigOptionsView(options:)`: groups by `category` in the order mode, model, thought level, model config, then uncategorized. A `select` option renders a `Picker` (with sections when the options are grouped); a `boolean` renders a `Toggle`. Each change calls `AgentThreadActions.setConfigOption`. The view is a menu for the toolbar and a `Form` for a settings sheet, chosen by a style parameter.
- `PermissionModePicker(options:)`: the `mode` category option as a segmented `Picker` for the composer accessory. Hidden when no mode option exists.
- Both read `thread.configOptions` and update when the list is replaced.

## Acceptance Criteria
- [x] A select with groups renders sections with the group names.
- [x] Changing a toggle calls `setConfigOption` with `.boolean`.
- [x] `PermissionModePicker` is absent when no `mode` option exists.

## Tests
- [x] `Tests/AgentViewKitTests/Config/ConfigOptionsViewHostedTests.swift`: grouping, sections, and the calls through `NoopThreadActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.