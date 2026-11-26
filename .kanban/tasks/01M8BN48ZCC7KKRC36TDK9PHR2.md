---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: A headless test target for the views of the demo app
---
Found during ^tvjsqzp (2026-11-26). `Examples/AgentViewKitDemo` has no `Package.swift`, and its generated Xcode project has only an XCUITest bundle (`AgentViewKitDemoUITests`). That bundle launches the app and brings it to the front, and it cannot tell `ChoiceField` from `Picker`. So `ACPSettingsSheet`, `DemoStartView` and `GalleryLookControls` (now EK controls) have no headless behavior test.

## What
- [ ] Add a headless SwiftPM test target for the feature views of the demo, as the EditorKit example generator has now (`<AppName>FeatureTests`). Read the EK generator first.
- [ ] Add behavior tests: `ACPSettingsSheet` mounts an `EditorScrollView`, `DemoStartView` mounts an `EditorProgressView`, and `GalleryLookControls` mounts 4 `ChoiceField`s in an `InspectorForm`. Mount each in a window that is never ordered in.
- [ ] Make the CI Examples job run the new target.

## Acceptance Criteria
- [ ] The new target runs headless, with no window and no focus change.
- [ ] Each test fails when its view uses a raw SwiftUI control in place of the EK control.

## Tests
- [ ] `swift test` in the new target passes with 0 failures and 0 warnings.
- [ ] The CI Examples job is green.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #test