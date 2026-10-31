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
- ``LiveSymbolEffect``
- ``SwiftUI/View/liveSymbolEffect(isActive:)``

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

- ``InspectorForm``
- ``SwiftUI/View/inspectorPreviewFrame()``
- ``InspectorActionRow``
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
