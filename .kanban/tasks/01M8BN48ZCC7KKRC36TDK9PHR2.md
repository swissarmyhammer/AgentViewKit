---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8brm7dwtse54gyxnpc6rbbr
  text: |-
    ### review — clean
    - evidence: review sha f2f2ff00..6d8c4703; 13 files reviewed; findings 0, confirmed 0, refuted 1. ARCHITECTURE.md and Docs/decisions/focus-audit.md have no validator. The Swift tool rules did not read the 4 old paths in Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ because the move removed those files.
    - next: review clean; waits for the CI Examples job. The card stays in review until the CI Examples job is green on the push.
  timestamp: 2026-11-26T11:07:37.276988+00:00
position_column: done
position_ordinal: '8180'
title: A headless test target for the views of the demo app
---
Found during ^tvjsqzp (2026-11-26). `Examples/AgentViewKitDemo` has no `Package.swift`, and its generated Xcode project has only an XCUITest bundle (`AgentViewKitDemoUITests`). That bundle launches the app and brings it to the front, and it cannot tell `ChoiceField` from `Picker`. So `ACPSettingsSheet`, `DemoStartView` and `GalleryLookControls` (now EK controls) have no headless behavior test.

## What
User rule (relayed by testudoapp-9a on 2026-11-26): add no new SwiftPM target or product unless the user asks. So do not add a demo test target.
- [x] Move `ACPSettingsSheet`, `DemoStartView` and `GalleryLookControls` (or the part of each that holds the EK controls) from `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/` into the existing target `Sources/AgentViewKitDemoSupport`, which `Tests/AgentViewKitTests` already tests. The demo app keeps using them through that target.
  - Evidence: commit 535a675f (merge 6d8c4703) moves `ACPSettingsSheet`, `DemoStartView`, `DemoFailureLabel` and `GalleryLook` into `Sources/AgentViewKitDemoSupport`. There is no new target and no new product.
- [x] Add behavior tests in `Tests/AgentViewKitTests`: `ACPSettingsSheet` mounts an `EditorScrollView`, `DemoStartView` mounts an `EditorProgressView`, and `GalleryLookControls` mounts 4 `ChoiceField`s in an `InspectorForm`. Mount each in a window that is never ordered in.
  - Evidence: new tests in `Tests/AgentViewKitTests/DemoSupport/DemoControlTests.swift` and in `ScrollViewControlTests` (`.demoSettingsSheet`).
- [x] If a view cannot move (it depends on the app target), write why on this card and leave the card open.
  - Evidence: not applicable. All the views moved.

## Acceptance Criteria
- [x] The tests run headless in `AgentViewKitTests`, with no window and no focus change.
  - Evidence: the tests are in `AgentViewKitTests` and mount each view in a window that is never ordered in.
- [x] Each test fails when its view uses a raw SwiftUI control in place of the EK control.
  - Evidence (RED): before the move, the test build failed (the types were not in scope). With the raw controls put in for a short time, all 4 new tests failed (names.count 0; ring types [0,0] twice; the spinner frame 118.5 x 52.9, not square).

## Tests
- [x] The root `swift test` passes with 0 failures and 0 warnings.
  - Evidence (GREEN): the root `swift test` on main 6d8c4703 passed, 1839 + 59.
- [x] The demo app builds, and the CI Examples job is green. (CI run 45815164712 on 366d9120: Examples (AgentViewKitDemo), Build & test and Integration are green.)
  - Note: the demo `xcodebuild build` succeeded. Waits for CI on the push.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #test