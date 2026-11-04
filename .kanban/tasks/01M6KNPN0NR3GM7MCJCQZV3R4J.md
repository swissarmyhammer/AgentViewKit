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
- actor: claude-code
  id: 01m6m1gbh8s4fns4qd3cf4mwgf
  text: |-
    Implementation notes (worktree-agent-a55801328dec1ae19):
    - PermissionModePicker: segmented ChoiceField over `SessionConfigSelectOption.choiceOption()`. `segmentIdentifierPrefix` / `segmentIdentifier(for:)` deleted. AX: the picker is an AXRadioGroup carrying `permission-mode-picker` and custom actions ["Ask","Auto"]; segments are AXRadioButtons labelled by value, value 1/0, no id.
    - ConfigOptionsView menu: ConfigOptionControl draws ChoiceField(.menu) with group sections (`ConfigSelectChoices.choiceOptions`, section = group name) and ToggleField. `choiceIdentifier(for:value:)` and `choiceIdentifierInfix` deleted. The control id `controlIdentifier(for:)` and the section-header id stay (they are per-control, not per-value).
    - Form: `Field<SessionModel, SessionConfigValueId>` with `.options`. `ConfigChoice` deleted along with its "%@ (%@)" catalog entry: grouped values now show under section headers instead of "Name (Group)".
    - ToolToggles menu: new internal `ToolToggleMenuItem` (ToggleField), so a hosted test can show the menu's toggle (a hosted window cannot open a Menu). The list uses EK's Bool row.
    - Grep of KVK, SVK and Testudo origin mains: no code uses ConfigChoice, segmentIdentifier*, choiceIdentifier* or LiveSymbolEffect (Testudo mentions only PermissionModePicker/ConfigOptionsView in docs). Nothing kept for later removal.
    - ThreadBarControlJump hit test: over the picker the window hit test answers AppKit's NSAccessibilitySegment, whose parent is the NSSegmentedCell radio group with NO SwiftUI identifier. So the test now checks for a radio button labelled with one of the fixture mode values, not an id prefix.
    - Merged main daa111f4 (inspector ids, InspectorDriver, InspectorRowID); kept main's scheme and helpers, with the ChoiceField/ToggleField tests on top.
  timestamp: 2026-11-04T19:45:19.400201+00:00
- actor: claude-code
  id: 01m6m22bxy9wnkh3svtscr6df2
  text: |-
    ### implement — changed
    - evidence: branch worktree-agent-a55801328dec1ae19 at df491059 (98e03c15 feature + merge of main daa111f4). Root `swift test`: 946 + 67 tests passed, no AVK warnings. `swift test --package-path IntegrationTests`: 944 tests in 123 suites passed (5 known issues, ^6y6ydyb passes now with main's scroll fix), no AVK warnings. ScreenshotTests: 21 tests passed once; new HostedSnapshotTests `config-controls-{light,dark}.png` (picker, both menu buttons, the controls the menus hold); form and list styles stay in the inspector gallery.
    - Hosted tests added: a choice in the picker, the form row, the menu control; a toggle in the form row, the menu control, the list row, the ToolToggles menu item; all send the change.
    - Deleted: ConfigChoice, PermissionModePicker.segmentIdentifierPrefix/segmentIdentifier(for:), ConfigOptionsView.choiceIdentifier(for:value:)/choiceIdentifierInfix, AVK's LiveSymbolEffect. No sibling kit uses them.
    - Note: root/IntegrationTests resolved EK a2ae6249; ScreenshotTests resolved EK 0cbc4834 (main moved during the run).
    - next: /review
  timestamp: 2026-11-04T19:55:09.630064+00:00
- actor: claude-code
  id: 01m6m32xfezzp0g44b1pw8kmtk
  text: |-
    ### implement — changed
    - evidence: 8ef21362 on worktree-agent-a55801328dec1ae19. Finding "code-hygiene/missing-docs-swift: AllPublicDeclarationsHaveDocumentation: add a documentation comment for 'body'" fixed at PermissionModePicker.swift, and the same cause removed in every changed file: body of ConfigOptionsView, ToolToggles, ToolCallView, StatusBar (public) and ConfigOptionControl, ToolToggleMenuItem (internal). A scan of the changed source files finds no other undocumented public declaration. Root swift test: 946 + 67 pass, 0 AVK warnings (doc-only change; no package update run, so the CodeContext pin did not apply).
    - next: merge into main, then full review
  timestamp: 2026-11-04T20:12:56.174626+00:00
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