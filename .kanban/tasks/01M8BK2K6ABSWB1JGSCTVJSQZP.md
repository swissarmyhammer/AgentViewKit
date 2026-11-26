---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8bpbmnmmf4jjv8xwcq6jdpy
  text: |-
    ### review — findings
    - evidence: review sha 23ce9256..771cb9ed; 1 finding (1 confirmed, 0 refuted) — Sources/AgentViewKit/Sessions/SessionJumpList.swift:58 (code-hygiene/dead-code-swift: var.instance `selection` is unused). Docs/decisions/focus-audit.md is not reviewed, because no validator matches it.
    - next: remove the unused `selection` property from SessionJumpList.swift and remove each other unused property in that file. Then run the review again. The evidence items (root swift test 1835 + 59, IntegrationTests 1090 with 5 known issues, gallery 46, demo build) stay unchecked, because the review is not clean. PathChip waits for EK (editorkit-7a). The demo behavior tests are on ^dk9phr2.
  timestamp: 2026-11-26T10:27:58.772192+00:00
- actor: claude-code
  id: 01m8bpwedm8pnmyj4q5gbmq08m
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (99299f7c); 0 findings (0 confirmed, 0 refuted); 2 files reviewed; 2 `.kanban/` files are excluded by `.reviewignore`. The prior finding (SessionJumpList.swift:58) is checked.
    - items: checked the scan item, the AttachmentView item, the first acceptance criterion and the behavior test item (note: ^dk9phr2). Open: the change item (the PathChip button waits for EK, editorkit-7a), the demo build-and-tests criterion and the swift test item. The evidence has no run of the demo end-to-end tests in `Examples/AgentViewKitDemo/Tests`.
    - next: the card stays in `review`, because more than the PathChip item is open. A person runs the demo end-to-end tests or decides that the demo build is sufficient. If only the PathChip item then stays open, move the card to `todo` with the comment "review clean; the PathChip button waits for EK".
  timestamp: 2026-11-26T10:37:09.428089+00:00
position_column: review
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
  - Note (2026-11-26): each AgentViewKit place is changed. The `PathChip` plain `Button` is in EditorKit (`Sources/EditorSwiftUI/PathChip.swift`). This item waits for EK: editorkit-7a has an EK card for it.
- [x] Scan again: Examples (all targets, the app, its tests), `Sources/AgentViewKitDemoSupport`, `Sources`, the README and each DocC file and doc comment with a Swift sample. List each result in `Docs/decisions/focus-audit.md`, "Raw controls".
- [x] The only raw control that stays is the `AttachmentView` `.accessibilityActions` Button (by decision).

## Acceptance Criteria
- [x] No raw SwiftUI or AppKit control from the ^8sdsx64 list (and `ScrollView`, `List`, `Form`) is in Examples, the demo, the doc samples or Sources, except the decided one.
- [ ] The demo app builds, and its tests pass.
  - Note (2026-11-26): the demo xcodebuild build succeeded. The evidence has no run of the demo end-to-end tests (`Examples/AgentViewKitDemo/Tests`). This item stays open until a person records that run.

## Tests
- [x] Behavior tests for each changed view: it mounts the EK component (view tree or accessibility element), in a window that is never ordered in. No source-scan test.
  - Note (2026-11-26): the demo app has no headless test target, so its 3 changed views have no behavior test. Follow-up card ^dk9phr2 covers them.
- [ ] `swift test` (root) and the demo tests pass with 0 failures and 0 warnings. A temp HOME is not possible, because the harness refuses the HOME override. Gallery images after the change.
  - Note (2026-11-26): root `swift test` passed (1836 + 59). All IntegrationTests passed (1090 tests, 5 known issues). The gallery passed (46 tests). The evidence has no run of the demo end-to-end tests, so this item stays open.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #bug

## Review Findings (2026-11-26 04:23)

> Scope: `review sha 23ce9256..771cb9ed` — reviewed the diffs only — lines this change added or modified. 23 file(s) reviewed, 1 not reviewed.

> 1 file(s) not reviewed — no validator matched:
> - `Docs/decisions/focus-audit.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Sessions/SessionJumpList.swift:58` `code-hygiene/dead-code-swift` — var.instance `selection` is unused.
