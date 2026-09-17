# Diff renderer

Status: decided. Source: plan.md §4.1, §11 decision 12, §14 research R3.
Task ^x1cgc24.

This file records how `DiffView` gets its default renderer from EditorKit.

## The EditorKit product

- EditorKit shipped the unified diff feature (the spec is
  `../EditorKit/diff_plan.md`) on its `main` branch. The package resolves
  EditorKit at commit `38d05a4` ("chore(kanban): record the close of task
  ^0tg00ms"). The `EditorDiff` product came in commit `f521c2d`. The
  `DiffView` accessibility identifiers came in commit `11ad7d1`.
- The feature has two parts:
  - `EditorDiff` is the kernel: `UnifiedDiff.parse(_:)`, `FileDiff`, `Hunk`,
    `DiffDocument`, and `UnifiedDiffError`.
  - `EditorSwiftUI` has the view: `DiffView(patch: UnifiedDiff)`, with the
    modifiers `diffLayout(_:)`, `diffContextLines(_:)`, `diffSizingMode(_:)`,
    and `diffHunkActions(_:)`.
- The manifest adds the `EditorDiff` product to the kit target.
  `EditorSwiftUI` was already there.

## The default renderer

- `Sources/AgentViewKit/Diff/DiffRendererSlot+EditorKit.swift` has
  `EditorKitDiffRenderer`. When `EnvironmentValues.diffRenderer` is `nil`,
  `DiffView` uses it. A host replaces it with `.diffRenderer { patch, file in }`.
- The environment value stays optional. A non-optional `@Entry` with a
  closure default gives the compiler warning "Storing a closure in '@Entry
  var diffRenderer' may invalidate dependents on every update".
- The renderer parses the patch with `UnifiedDiff.parse(_:)`. It keeps only
  the file whose new path, or the old path of a deleted file, is the selected
  path. This is the path that `DiffSummary` gives. When no file matches, the
  renderer shows each file.
- The renderer applies `.editorTheme(theme.editorTheme)`, the `AgentTheme`
  bridge.
- The "diff renderer not installed" row is removed. When EditorKit cannot
  parse the patch, a row shows "Cannot read the patch at line N", with the
  identifier `DiffView.unreadablePatchIdentifier`. This row is not a stand-in
  renderer. It shows no diff lines.

## The layout setting

- The kit had no layout setting. The kit adds `DiffLayout` (`inline`,
  `sideBySide`), `EnvironmentValues.diffLayout` (default `inline`), and the
  modifier `.diffLayout(_:)`.
- `DiffLayout` is a kit type, so the public API of the kit does not show the
  EditorKit type `DiffDocument.Layout`. `DiffLayout.documentLayout` maps the
  value.

## The accessibility identifier

- The EditorKit `DiffView` puts its own identifiers on its AppKit views
  (EditorKit 38d05a4): `DiffView.accessibilityIdentifier` (`editor.diff`) on
  the root in both layouts, and `DiffView.oldColumnAccessibilityIdentifier`
  (`editor.diff.old`) and `DiffView.newColumnAccessibilityIdentifier`
  (`editor.diff.new`) on the two columns of the side-by-side layout.
- These identifiers are on `NSView`s, not on SwiftUI accessibility elements.
  The hosted tests find them with
  `HostedViewHarness.views(withAccessibilityIdentifier:)`, which walks the
  `NSView` tree.
- The kit identifier `diff-editor-renderer` is removed. No code needs it.
