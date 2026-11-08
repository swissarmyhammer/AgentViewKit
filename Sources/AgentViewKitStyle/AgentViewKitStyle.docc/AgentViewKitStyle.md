# ``AgentViewKitStyle``

The shared look of the view kits: AgentViewKit is the shared visual layer.

## Overview

AgentViewKit is the shared visual layer of the view kits. SnapshotViewKit
and KanbanViewKit link this library, and keep no copy of the views and the
symbols in it. The AgentViewKit library builds its agent thread views on it,
and re-exports it.

The library links EditorKit only. Its dependency closure holds no ACP
package, no Textual and no math engine, so a view kit that must not link ACP
links it.

The inspector of the view kits is EditorKit's `EditorInspector`: the
`Inspectable` protocol, `InspectorView`, the grouped `InspectorForm`, the
`InspectorActionRow` and `.inspectorPreviewFrame()`. The library keeps no
copy of them, and a view kit imports `EditorInspector` itself.

Each symbol the view kits share is EditorKit's `EditorSymbol`: a tool kind,
a file kind, a status, the severity of a notice, a closed session, and the
Reload, Dismiss, link and disclosure marks. The library and AgentViewKit draw
each symbol with EditorKit's `EditorSymbolImage`, in a tone of the theme,
with its live effect and its Reduce Motion rule, and keep no symbol table of
their own for those concepts. The change to a file of a diff is
EditorKit's `FileDiff.Operation`, which ``DiffSummary/FileSummary`` holds, and
the kind of the file is EditorKit's `EditorSymbol.FileKind(diffOperation:)`.
The library adds only the word of an operation, such as "Added", for a
view kit that names a change in its own words. A status, its symbol and its label, is EditorKit's
`EditorStatus`, which EditorKit's `EditorStatusLabel` draws.

Each chip of a file or a folder path is EditorKit's `PathChip`: the file
chips of a diff, the location chips of a tool call and the path rows of the
inspector. The library keeps no chip of its own for a path. A kit that
selects a path chip puts its selection surface in
``SurfaceCorners/pathChip``.

An item that a kit draws itself, such as a card, a chip, a row or a tile,
shows its selection and its focus as a fill in its own shape, never as an
outline (EditorKit style.md, "Selection and focus"):
``SwiftUI/View/selectableSurface(_:corners:)``, inside the `.commandScope` of
the item, wraps EditorKit's `.selectableItem`, so the scope draws no focus
ring around the item. A part with no scope of its own inside another item,
such as a tab chip, shows its selection only with
``SwiftUI/View/selectionSurface(_:corners:)``.

A view of the library takes the behaviour of a kit through a style protocol
of the environment, in the shape of `ButtonStyle`. AgentViewKit gives the
button of a ``StatusBar`` the focus scope of a bar control with
``SwiftUI/View/statusBarActionStyle(_:)``.

## Topics

### Tiles and surfaces

- ``ContentTile``
- ``ContentTileStack``
- ``SwiftUI/View/contentTile()``
- ``SelectableSurface``
- ``SurfaceCorners``
- ``SwiftUI/View/selectableSurface(_:radius:)``
- ``SwiftUI/View/selectableSurface(_:corners:)``
- ``SwiftUI/View/selectionSurface(_:corners:)``
- ``SwiftUI/View/changeHighlightEdge(corners:isShowing:)``
- ``SwiftUI/View/changeHighlightEdge(radius:isShowing:)``

### The status bar

- ``StatusBar``
- ``StatusBarActionButton``
- ``StatusBarActionConfiguration``
- ``StatusBarActionStyle``
- ``GlassStatusBarActionStyle``
- ``SwiftUI/View/statusBarActionStyle(_:)``
- ``StreamBannerContent``
- ``ReloadPhase``

### Diffs

- ``DiffSummary``

### Command scopes

- ``AgentScopeKind``
