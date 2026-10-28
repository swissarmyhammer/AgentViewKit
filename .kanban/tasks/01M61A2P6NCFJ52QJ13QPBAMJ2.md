---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m61a9mmjqh8n5cbjcb476k9x
  text: |-
    Rescoped from kanbanviewkit-2c's audit of both kits (also sent to snapshotviewkit-ec). editorkit-a9 has closed ^qane0e0, and style.md and ARCHITECTURE.md at EditorKit b7b3575 say the view kits build on AgentViewKit for these.

    0. A new library product, `AgentViewKitStyle`, that links no ACP package. The AgentViewKit library links FoundationModelsACP (Package.swift:57-60, 130), and KVK's manifest and import-boundary tests forbid ACP. The `AgentViewKitStyle` target depends only on EditorKit (EditorStyle, EditorTheme, EditorSwiftUI as needed). AgentViewKit depends on it and keeps no copy. A manifest test proves that AgentViewKitStyle's closure contains no FoundationModelsACP or ACP-client product. SVK and KVK depend on this product only.
    1. Into AgentViewKitStyle, public: ContentTile, `.contentTile()`, ContentTileStack.
    2. Into AgentViewKitStyle, public: `.selectableSurface(_:radius:)` / `(_:corners:)` and the corners type, renamed without "Agent" (AgentSurfaceCorners → SurfaceCorners). Update every AVK call site, with no typealias or shim. Keep the contentShape in it.
    3. Into AgentViewKitStyle, public: StatusBar, StatusBar.Action and StateBanner.Message. Message gets a public init. StatusBar no longer needs `.agentControlScope` / `.requestActionStyle`: AVK applies those where it uses StatusBar, through a hook or wrapper on the AVK side, as one clear mechanism. Replace `isFailure`, which compares symbol names, with an explicit severity on Message. KVK replaces its BoardStreamBanner row and BoardNoticeRow with it.
    4. Into AgentViewKitStyle, public: the generic SharedSymbol entries (error, warning, information, reload, edit, delete, move, dismiss), the tool-kind and file-operation symbols, and a new `binary` symbol. Drop the clock symbols that break style.md:107 (replaying, activity "clock", entryTime "timer") and replace them with non-clock symbols at every use. The SymbolNameTests scanner moves to EditorKit's shared scanners (^3q7j9nd), not to AVK. KVK keeps its board-only symbols.
    5. For SVK only, into AgentViewKitStyle: ToolCallLocationChips, ChipFlowLayout and DiffFileChip, plus the diff renderer setup (EditorKitDiffRenderer, `\.diffLayout`), if they can be made ACP-free. If one can't, it stays in AgentViewKit, and SVK's needs are rechecked with snapshotviewkit-ec. KVK takes none of these.
    6. Announcer, AnnouncementPriority, VoiceOverAnnouncer, FocusReporter and the `\.announcer` / `\.focusReporter` keys are identical and public in both AVK and KVK, so they collide as soon as KVK imports AVK. I've asked editorkit-a9 to move them into EditorKit (EditorCommandsUI/Accessibility.swift). AVK then deletes its copy in a separate adoption card. This card doesn't move them.
    7. Stays in KVK: BoardGlassID, BoardTheme, the card glass, AgentHighlight, StubGraphQLEndpoint.
    Order: still after ^gjr9xg. Send the SHA to snapshotviewkit-ec and kanbanviewkit-2c.
  timestamp: 2026-10-28T13:13:22.322825+00:00
- actor: claude-code
  id: 01m61aa0r7ew51bd7v4r83xpqq
  text: |-
    snapshotviewkit-ec supports the `AgentViewKitStyle` product and will link only it. It also needs these in that product:
    - ToolCallLocationChips, ChipFlowLayout and DiffFileChip;
    - EditorKitDiffRenderer and `\.diffLayout`;
    - AgentScopeKind, at least the `toolCall` kind and its segment factory.
    If the command's subject has to be ToolCallEntry (an ACP type), keep that subject in AgentViewKit and move only the scope kind and segment. SVK reads the tool call id from the focus segment. Send the product name with the SHA.
  timestamp: 2026-10-28T13:13:34.727661+00:00
position_column: todo
position_ordinal: ae80
title: 'AVK is the shared visual layer: make the tile, surface, symbols, chips, status bar look and diff renderer setup public for SVK and KVK'
---
User decision, relayed by snapshotviewkit-ec: "I'm very happy for you to make those public from AVK and build on top of AVK. Similar for KVK: collaborate with it to decide what is redundant in KVK and should actually be shared from AVK." AgentViewKit becomes the shared visual layer for the view kits. SnapshotViewKit, and KanbanViewKit where they overlap, depend on AVK. This replaces EditorKit ^qane0e0's lift into EditorStyle; editorkit-a9 has been asked to trim or close it.

## Make public, with doc comments, a docc topic and no shims
- [ ] ContentTile, `.contentTile()` and ContentTileStack (Theme/ContentTile.swift)
- [ ] SelectableSurface, `.selectableSurface` and AgentSurfaceCorners (Theme/SelectableSurface.swift)
- [ ] The tool-kind and file-operation symbols (Items/SharedSymbol.swift, ToolKindSymbol.swift). Add a binary-file symbol. Replace entryTime "timer" and activity "clock", which break style.md's clock rule, with non-clock symbols, and fix every use.
- [ ] ToolCallLocationChips, ChipFlowLayout (Items/ToolCallLocationChips.swift) and DiffFileChip (Diff/DiffFileChip.swift)
- [ ] The StatusBar look (Status/StatusBar.swift), for SVK's stream banner
- [ ] The diff renderer setup: EditorKitDiffRenderer (Diff/DiffRendererSlot+EditorKit.swift) and the `\.diffLayout` environment value
- [ ] AgentScopeKind.toolCall stays public; SVK uses it for "Roll Back to Before This"
- [ ] Every new public symbol has a test through the public API (a test target with no `@testable import`), plus a #Preview
- [ ] The public-API docs (docc) and ARCHITECTURE.md name AVK as the shared visual layer for SVK and KVK
- [ ] `swift test` is green

## Order
After ^gjr9xg, which is changing ToolCallLocationChips, DiffFileChip and DiffView right now. Then send the SHA to snapshotviewkit-ec and kanbanviewkit-2c. A follow-up card, worked out with kanbanviewkit-2c, decides what KVK duplicates and should take from AVK instead.