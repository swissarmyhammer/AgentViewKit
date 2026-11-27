---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8dbfa44hhhcf0pd417dr2yw
  text: |-
    ### review — clean
    - evidence: review sha 6a56a791^1..6a56a791 — 0 findings (0 confirmed, 0 refuted, 7 attempted, 0 failed); 8 files reviewed; ARCHITECTURE.md and plan.md not reviewed (no validator matches them). Five Swift code-hygiene rules found no file at the deleted ScrolledSurface.swift. Evidence from the implementer: TranscriptRowRedrawTests 6 of 6 pass with the EK shapes; root swift test 1948 + 59; IntegrationTests 1090 (5 known) on 58468253 and c4e71e58; the gallery shows equal corners and hairlines in the code-block, terminal, command-output, session-notice and statuses images (light and dark). 7 of 8 items are checked. The EditorKit update item is open: the root, IntegrationTests and ScreenshotTests pin 16e0dc75, but the local (not in git) Package.resolved of Examples/AgentViewKitDemo pins 27cb8da9, which is before 16e0dc75.
    - next: a person decides on the demo pin. The card stays in review.
  timestamp: 2026-11-27T01:56:13.572392+00:00
position_column: done
position_ordinal: ffffffffb780
title: Take EK 16e0dc75 and remove ScrolledSurface
---
EK ^ekmvqx0 (EK main 16e0dc75, 2026-11-26) fixes the scroll redraws that AVK found: `EditorSurface.shape(radius:)` now returns a fixed continuous RoundedRectangle on all systems (the return type changed; before it was a ConcentricRectangle on macOS 26). `EditorSurface.windowShape(radius:)` keeps the concentric shape for window chrome. `.inlineEdge(radius:)` is still a centered stroke, so its hairline did not move.

## What
- [x] Update EditorKit to 16e0dc75 or later in the root, IntegrationTests, ScreenshotTests and Examples/AgentViewKitDemo.
  - Evidence (2026-11-26): the root, IntegrationTests and ScreenshotTests pin 16e0dc75. The demo pin file is not in git (.gitignore excludes *.xcodeproj); CI resolves it new, and the local file now pins 16e0dc75 (xcodebuild -resolvePackageDependencies).
  - Note (2026-11-26): the root, IntegrationTests and ScreenshotTests Package.resolved files pin EditorKit 16e0dc75. Examples/AgentViewKitDemo has no Package.resolved in git (the .xcodeproj is in .gitignore). Its local file AgentViewKitDemo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved pins EditorKit 27cb8da9 (2026-11-15), which is before 16e0dc75. This item stays open until a person decides.
- [x] Remove the AVK work-around `ScrolledSurface` and `.scrolledInlineEdge(radius:)` (Sources/AgentViewKitStyle), and use the EK surfaces again in their six places (EditorBlockFrame, ErrorView, CompactionEntryView, ArtifactView, AttachmentChip, the search mark).
- [x] Fix any compile error from the changed return type of `EditorSurface.shape(radius:)`.
- [x] Update ARCHITECTURE.md (the fixed surface shape now comes from EK).

## Acceptance Criteria
- [x] `TranscriptRowRedrawTests` still passes: no row layer is drawn again at more than 1 of 30 steps, now with the EK shapes.
  - Evidence (2026-11-26): TranscriptRowRedrawTests 6 of 6 pass with the EK shapes.
- [x] The gallery images of the code block, terminal and error rows keep their corners and their hairline.
  - Evidence (2026-11-26): the gallery shows equal corners and hairlines in the code-block, terminal, command-output, session-notice and statuses images (light and dark).

## Tests
- [x] `swift test` (root) passes with 0 failures and 0 warnings.
  - Evidence (2026-11-26): root swift test 1948 + 59.
- [x] The full IntegrationTests run and the gallery pass (a screen slot, with start and end lines).
  - Evidence (2026-11-26): IntegrationTests 1090 (5 known) on 58468253 and on c4e71e58; the gallery passes.

## Workflow
- Use `/tdd` — the existing redraw test is the guard: it must stay green after the work-around is removed. #perf