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

The symbols of a tool kind, a file kind and a status are EditorKit's
`EditorSymbol`, and the library and AgentViewKit draw each symbol with
EditorKit's `EditorSymbolImage`, in a tone of the theme, with its live effect
and its Reduce Motion rule. ``SharedSymbol`` keeps the names of the concepts
that EditorKit does not hold, such as a warning notice or a Reload button.
Its tool-kind and file names and ``StatusSymbolImage`` stay for the view kits
that still read them, until those kits draw EditorKit's symbols.

A view of the library takes the behaviour of a kit through a style protocol
of the environment, in the shape of `ButtonStyle`. AgentViewKit gives the
button of a ``StatusBar`` the focus scope of a bar control with
``SwiftUI/View/statusBarActionStyle(_:)``, and gives each location chip the
inspector of its file with ``SwiftUI/View/toolCallLocationChipStyle(_:)``.

## Topics

### Tiles and surfaces

- ``ContentTile``
- ``ContentTileStack``
- ``SwiftUI/View/contentTile()``
- ``SelectableSurface``
- ``SurfaceCorners``
- ``SwiftUI/View/selectableSurface(_:radius:)``
- ``SwiftUI/View/selectableSurface(_:corners:)``
- ``SwiftUI/View/changeHighlightEdge(corners:isShowing:)``
- ``SwiftUI/View/changeHighlightEdge(radius:isShowing:)``

### Symbols

- ``SharedSymbol``
- ``StatusSymbolImage``

### The status bar

- ``StatusBar``
- ``StatusBarActionButton``
- ``StatusBarActionConfiguration``
- ``StatusBarActionStyle``
- ``GlassStatusBarActionStyle``
- ``SwiftUI/View/statusBarActionStyle(_:)``
- ``StreamBannerContent``
- ``ReloadPhase``

### Rows

- ``CompletionRow``

### Chips

- ``ChipFlowLayout``
- ``ToolCallLocationChips``
- ``ToolCallLocationChip``
- ``ToolCallLocationChipConfiguration``
- ``ToolCallLocationChipStyle``
- ``PlainToolCallLocationChipStyle``
- ``SwiftUI/View/toolCallLocationChipStyle(_:)``
- ``DiffFileChip``
- ``DiffFileLabel``

### Diffs

- ``DiffSummary``
- ``EditorKitDiffRenderer``
- ``DiffContentView``
- ``DiffLayout``
- ``SwiftUI/EnvironmentValues/diffLayout``
- ``SwiftUI/View/diffLayout(_:)``

### Command scopes

- ``AgentScopeKind``
