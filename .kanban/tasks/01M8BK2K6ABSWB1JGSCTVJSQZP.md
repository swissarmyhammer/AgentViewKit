---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: No raw control in Examples, the demo, the doc samples, or the last places in Sources
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-26). EK style.md has a "Controls" rule (EK a4bfc1dc, ^cf06nzr): each control is an EK component or an EK wrapper, with no raw SwiftUI or AppKit control in a kit or an app. ^8sdsx64 checked only `Sources/`. SnapshotViewKit found raw controls in its Examples.

A scan found:
- `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPSettingsSheet.swift:38`: `ScrollView`.
- `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoStartView.swift:54`: `ProgressView`.
- `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryLook.swift:129`: `Form` with 4 `Picker`s.
- `Sources/AgentViewKit/Sessions/SessionJumpList.swift`: a SwiftUI `List` (EK `EditorSelectionList` exists).
- The `PathChip` file chip: a plain SwiftUI `Button` (EK `EditorPlainButton` exists).
- `Sources/AgentViewKitStyle/Theme/SelectableSurface.swift:182`: a doc sample with a raw `List`.

## What
- [ ] Change each place above to the EK component (`EditorScrollView`, `EditorProgressView`, `ChoiceField` in an EK form layout, `EditorSelectionList`, `EditorPlainButton`). Change the doc sample to an EK control.
- [ ] Scan again: Examples (all targets, the app, its tests), `Sources/AgentViewKitDemoSupport`, `Sources`, the README and each DocC file and doc comment with a Swift sample. List each result in `Docs/decisions/focus-audit.md`, "Raw controls".
- [ ] The only raw control that stays is the `AttachmentView` `.accessibilityActions` Button (by decision).

## Acceptance Criteria
- [ ] No raw SwiftUI or AppKit control from the ^8sdsx64 list (and `ScrollView`, `List`, `Form`) is in Examples, the demo, the doc samples or Sources, except the decided one.
- [ ] The demo app builds, and its tests pass.

## Tests
- [ ] Behavior tests for each changed view: it mounts the EK component (view tree or accessibility element), in a window that is never ordered in. No source-scan test.
- [ ] `swift test` (root) and the demo tests pass with 0 failures and 0 warnings. A temp HOME is not possible, because the harness refuses the HOME override. Gallery images after the change.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #bug