---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6kx0yk4jw4y96sbmx8fqqyv
  text: |-
    Unblocked: EK ^bbffx3s is on origin at bcce50e4 (editorkit-b5, 2026-11-04). `swift package update` all deps together. EK grepped AVK: nothing breaks, and `.choices { session in … }` in ConfigOptionFields still compiles.
    EditorSwiftUI:
    - `ChoiceField` takes `ChoiceOption`s (label, optional SF Symbol, optional menu section), which covers grouped choices. The host sets `.pickerStyle` (menu by default, or `.segmented`). With no value it shows a "no selection" item, which the inspector labels "Mixed". Each option is a named accessibility action, in the right order: EK fixes SwiftUI's reversed `.accessibilityActions` order.
    - `ToggleField` is a check box on macOS.
    - `ChoiceOptionLabel` shows an option read-only.
    - Both use the theme's font and accent, never a host `.tint`.
    Inspector: the `.choice` kind with `.options { object in [ChoiceOption] }`; every Bool row is a ToggleField; a read-only choice shows the option's label. Driver: `options(in:)`, `isOn(_:)`, `choose(_:in:)`.
    To do: delete PermissionModePicker's own control and AVK's `ConfigChoice` wrapper, and build ConfigOptionsView and ToolToggles from these. AVK's per-option accessibility ids have no EK equivalent, so tests reach options through their named actions or the driver.
    Push sequencing: before removing public API (`ConfigChoice`, PermissionModePicker members), grep the KVK, SVK and Testudo origin mains for them.
  timestamp: 2026-11-04T18:27:00.324273+00:00
position_column: doing
position_ordinal: '8380'
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