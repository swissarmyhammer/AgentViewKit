---
assignees:
- claude-code
position_column: todo
position_ordinal: '8880'
title: Adopt EditorKit choice and toggle (^bbffx3s) in PermissionModePicker, ConfigOptionsView, ToolToggles
---
**Blocked** on EK card ^bbffx3s (on EK origin at 2524005e). It lands EK's choice and toggle controls, harvested from the controls inside AVK's pickers. editorkit-b5 sends the SHA. Don't start before then.

Boundary (user, 2026-11-04): single-value controls are EK's. `PermissionModePicker` (Sources/AgentViewKit/Config/PermissionModePicker.swift), `ConfigOptionsView` and `ToolToggles` stay in AVK as compound views.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Replace the single-value choice and toggle controls inside those three views with EK's. Delete AVK's own copies of those controls.
- Keep each view's menu and form styles working.

## Acceptance Criteria
- [ ] No AVK copy of a choice or toggle control is left in the three views.
- [ ] The three views are built from EK's controls, with EK's theming.
- [ ] The review gallery shows each view in each of its styles, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.
- [ ] Hosted tests: a choice and a toggle in each view still send the change to the session.