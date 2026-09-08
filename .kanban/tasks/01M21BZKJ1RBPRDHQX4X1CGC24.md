---
depends_on:
- 01M21AMHZJF4YSR0ZFYVV6B45Q
position_column: todo
position_ordinal: c580
title: 'Research R3 follow-through: adopt EditorKit''s EditorDiff product as the DiffRendererSlot default (plan §4.1, §11#12, §14)'
---
## What
Research R3 from plan.md §14 is the EditorKit unified-diff feature. Its spec is written: `../EditorKit/diff_plan.md`. This task consumes the product when EditorKit ships it. The kit builds no stand-in renderer (plan.md decision 12).

- Add the `EditorDiff` product to the EditorKit dependency in `Package.swift`.
- `Sources/AgentViewKit/Diff/DiffRendererSlot+EditorKit.swift`: register `EditorDiff.DiffView(patch:)` as the default renderer, with `.diffLayout` bound to the kit's layout setting and the `AgentTheme` bridge applied.
- Remove the "diff renderer not installed" state from `DiffView`.
- Record in `Docs/decisions/diff-renderer.md` the EditorKit commit that shipped the product.

## Acceptance Criteria
- [ ] `swift package resolve` and `swift build` succeed with the `EditorDiff` product listed.
- [ ] `DiffView(patch:)` with no slot override renders `EditorDiff.DiffView` (assert through the accessibility identifier EditorKit's view carries).
- [ ] No source file in `Sources/AgentViewKit/Diff` contains the string "not installed".

## Tests
- [ ] `Tests/AgentViewKitTests/Diff/DiffRendererDefaultHostedTests.swift`.
- [ ] `Tests/PackageStructureTests/ManifestTests.swift` gains the `EditorDiff` product assertion.
- [ ] `swift test` exits 0.

## Workflow
- Blocked until `../EditorKit` main has the `EditorDiff` product. Check with `swift package describe` in `../EditorKit`.
- Use `/tdd` — write failing tests first, then implement to make them pass.