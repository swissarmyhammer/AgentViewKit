---
assignees:
- claude-code
position_column: todo
position_ordinal: '8880'
title: Take EK 16e0dc75 and remove ScrolledSurface
---
EK ^ekmvqx0 (EK main 16e0dc75, 2026-11-26) fixes the scroll redraws that AVK found: `EditorSurface.shape(radius:)` now returns a fixed continuous RoundedRectangle on all systems (the return type changed; before it was a ConcentricRectangle on macOS 26). `EditorSurface.windowShape(radius:)` keeps the concentric shape for window chrome. `.inlineEdge(radius:)` is still a centered stroke, so its hairline did not move.

## What
- [ ] Update EditorKit to 16e0dc75 or later in the root, IntegrationTests, ScreenshotTests and Examples/AgentViewKitDemo.
- [ ] Remove the AVK work-around `ScrolledSurface` and `.scrolledInlineEdge(radius:)` (Sources/AgentViewKitStyle), and use the EK surfaces again in their six places (EditorBlockFrame, ErrorView, CompactionEntryView, ArtifactView, AttachmentChip, the search mark).
- [ ] Fix any compile error from the changed return type of `EditorSurface.shape(radius:)`.
- [ ] Update ARCHITECTURE.md (the fixed surface shape now comes from EK).

## Acceptance Criteria
- [ ] `TranscriptRowRedrawTests` still passes: no row layer is drawn again at more than 1 of 30 steps, now with the EK shapes.
- [ ] The gallery images of the code block, terminal and error rows keep their corners and their hairline.

## Tests
- [ ] `swift test` (root) passes with 0 failures and 0 warnings.
- [ ] The full IntegrationTests run and the gallery pass (a screen slot, with start and end lines).

## Workflow
- Use `/tdd` — the existing redraw test is the guard: it must stay green after the work-around is removed. #perf