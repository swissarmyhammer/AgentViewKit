---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m2q44djf45exnqj2sb2028wm
  text: |-
    ### finish iteration 1 — done
    - implement: Updated EditorKit to 38d05a4 (Package.resolved and Benchmarks/Package.resolved). Removed `DiffView.editorRendererIdentifier` and its container element, because only tests used it. Added `HostedViewHarness.views(withAccessibilityIdentifier:)` in AgentViewKitTestSupport; it walks the NSView tree. EditorKit does not vend `EditorTestSupport` as a product, so the kit cannot import `HostedWindow.views(withAccessibilityIdentifier:in:)`. Added the test file `EditorDiffIdentifier.swift`, which imports only EditorSwiftUI, so that the name `DiffView` is the EditorKit view. The diff tests now find `editor.diff`, and the side-by-side test finds `editor.diff.old` and `editor.diff.new`. Updated Docs/decisions/diff-renderer.md.
    - test: `timeout 1500 swift test` passed. AgentViewKitTests 1182, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. No new warnings.
    - commit: 2264d7c
    - review: `review sha HEAD~1..HEAD`: zero findings.
  timestamp: 2026-09-17T07:26:09.999668+00:00
position_column: done
position_ordinal: c480
title: 'DiffView: use the EditorKit DiffView accessibility identifiers'
---
EditorKit main (commit 11ad7d1, origin 38d05a4) now gives the EditorSwiftUI `DiffView` public accessibility identifiers:
- `DiffView.accessibilityIdentifier` = "editor.diff" (the root, in both layouts)
- `DiffView.oldColumnAccessibilityIdentifier` = "editor.diff.old"
- `DiffView.newColumnAccessibilityIdentifier` = "editor.diff.new"

EditorKit sets these identifiers on the AppKit host views (`NSView.accessibilityIdentifier()`), not through the SwiftUI modifier. EditorTestSupport has `HostedWindow.views(withAccessibilityIdentifier:in:)` to find them.

Today `EditorKitDiffRenderer` puts its own identifier `diff-editor-renderer` on the EditorKit view, because EditorKit had none.

## Work
- Update the EditorKit pin (`swift package update EditorKit`) so that the new identifiers are available.
- In the diff tests, find the EditorKit view by its EditorKit identifiers (the root, and the two columns in the side-by-side layout).
- Decide if `DiffView.editorRendererIdentifier` (`diff-editor-renderer`) is still necessary. Remove it if no code needs it.

## Acceptance
- [x] The hosted diff tests find the EditorKit view by `editor.diff`.
- [x] A test of the side-by-side layout finds `editor.diff.old` and `editor.diff.new`.
- [x] `swift test` passes with no new warnings.

## Review Findings (2026-09-17 02:24)

Scope: `review sha HEAD~1..HEAD` (commit 2264d7c). 6 files reviewed. Zero findings.