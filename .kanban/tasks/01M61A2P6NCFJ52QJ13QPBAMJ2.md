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
- actor: claude-code
  id: 01m61azxbjrqscs9sskv1dye5m
  text: |-
    Research (implement pass 1):
    - No .docc catalog exists in AVK; plan.md §11 decision 1, Docs/decisions/acp-client-kit.md, dependencies.md, Package.swift comments and ManifestTests all state "one library product". All need the second product.
    - Dependency fan-out of the moved views (each must move too, public, or the view cannot leave AVK): StatusBar needs StatusSymbolImage + LiveSymbolEffect; DiffFileChip needs DiffSummary (already public, ACP-free) plus Operation.label / changeAccessibilityLabel (ACP-free, live in DiffSummary+Changes) and DiffView.symbolName(for:)/fileChipRadius/identifier(for:); EditorKitDiffRenderer needs DiffLayout and DiffView.unreadablePatchIdentifier; ToolCallLocationChips needs a location model (ACP ToolCallLocation today) and ACPLocationText's text(path:line:).
    - ACP-bound, stays in AVK: ToolKindSymbol / ToolStatusSymbol (switch over ACP ToolKind / ToolCallStatus — only the symbol constants move), DiffSummary.files(of: ACP Diff)/gitPatchText/hasPath, DiffView (init(diff:) is ACP), the tool call scope subject (ToolCallEntry) and AgentScopeKind's other kinds (request takes PendingPermissionRequest.ID, attachment takes AttachmentID).
    - StatusBar's button carries .requestActionStyle (RequestDeckPlace/floating glass, AVK) and .agentControlScope (AVK command scope). Plan: a ButtonStyle-shaped StatusBarActionStyle protocol set through the environment (EditorKit precedent: EditorCommandsUI JumpLabelStyle / AnyJumpLabelStyle); AVK applies its AgentStatusBarActionStyle where it uses StatusBar. Same mechanism for the location chips (InspectorSelectable + agentAttachmentScope are AVK-side).
    - StateBanner.Message.isOngoing also compares symbol names (inProgress + replaying); replaying is an AVK-only symbol, so Message gets an explicit isOngoing too, beside the explicit severity.
    - Clock symbols per EditorKit style.md "clock and each clock.* symbol, timer, alarm": replaying, partialHistory ("clock.badge.questionmark" — not named on the card, but the same rule), activity "clock", entryTime "timer". Replacements checked in CoreGlyphs name_availability.plist.
    - Many PackageStructureTests scan only Sources/AgentViewKit (KitSourceFiles.kitPath); the style sources must be scanned by the same rules.
  timestamp: 2026-10-28T13:25:32.146921+00:00
- actor: claude-code
  id: 01m61canwmwax758k1sbq7km9b
  text: |-
    Implementation progress (pass 1):
    - New product/target AgentViewKitStyle (Sources/AgentViewKitStyle), links EditorStyle/EditorTheme/EditorSwiftUI/EditorDiff/EditorCommands only. AgentViewKit depends on it and re-exports it (`@_exported import AgentViewKitStyle` in AgentViewKitModule.swift), so AVK files and hosts read the moved types with no second import.
    - StatusBar/action mechanism: ButtonStyle-shaped `StatusBarActionStyle` set through the environment (`.statusBarActionStyle(_:)`, default `GlassStatusBarActionStyle`). AVK's `AgentStatusBarActionStyle` applies `.requestActionStyle(.secondary)` + `.agentControlScope(identifier)`; StateBanner, SessionStreamBanner and AgentConnectionBanner set it. Same pattern for location chips: `ToolCallLocationChipStyle`, AVK's `AgentLocationChipStyle` (inspector + attachment scope).
    - Coordinator API request: `StateBanner.Message(...)` could NOT keep that name in the ACP-free product — `StateBanner` is the ACP-bound AVK view (takes SessionModel), so a Style type of that name would collide. The message is `StatusBar.Message(title:explanation:symbolName:identifier:severity:isOngoing:)`; Severity has .neutral (default, secondary color — keeps today's pixels for every non-failure message), .information, .warning, .failure; colour comes from severity. `isOngoing` is explicit too (the old symbol-set check referenced AVK's replaying symbol). `StatusBar.Action(title:systemImage:identifier:isEnabled:hint:perform:)` with `hint: String? = nil` → accessibility hint. SharedSymbol has error, warning, information, reload, dismiss, delete, move (doc widened to the Move action of a selection), link, binary ("01.square"), plus tool kinds and file ops.
    - Clock symbols replaced (style.md: clock, clock.*, timer, alarm): replaying → arrow.trianglehead.counterclockwise, partialHistory (clock.badge.questionmark, also a clock.* symbol) → questionmark.text.page, activity → waveform.path.ecg, entryTime → hourglass.
    - Stays in AVK (ACP-bound): ToolKindSymbol/ToolStatusSymbol (switch over ACP enums; only the symbol constants moved), DiffSummary.files(of: ACP Diff)/gitPatchText/hasPath, DiffView (init(diff:)), AgentScopeKind's thread/message/request/attachment/control kinds and segment factories (subjects/ids are SessionModel, PendingPermissionRequest.ID, AttachmentID) — an AVK extension of the Style `AgentScopeKind`; agent-only symbols — an AVK extension of the Style `SharedSymbol`.
    - Moved because the card's items need them: StatusSymbolImage + LiveSymbolEffect (StatusBar draws with them), DiffSummary (DiffFileChip's model; ACP part stays as an AVK extension), ACPLocationText removed (Location.text in Style).
  timestamp: 2026-10-28T13:48:53.524977+00:00
- actor: claude-code
  id: 01m61e1ky62gn8ngvxk23c9e02
  text: |-
    ### implement — changed
    - New product and target `AgentViewKitStyle` (Sources/AgentViewKitStyle). It links only EditorStyle, EditorTheme, EditorSwiftUI, EditorDiff and EditorCommands. AgentViewKit depends on it, re-exports it with `@_exported import`, and keeps no copy. No shims or typealiases, and every call site is updated.
    - Public in Style, each with a doc comment and a #Preview:
      - ContentTile, `.contentTile()`, ContentTileStack.
      - `.selectableSurface(_:radius:)` and `(_:corners:)`, with SurfaceCorners (`.rounded`, `.square`, `radius(in:)`). The contentShape `[.interaction, .focusEffect]` is kept.
      - StatusBar, StatusBar.Action (with a new `hint`), and StatusBar.Message with `severity` and `isOngoing`.
      - StatusBarActionStyle and ToolCallLocationChipStyle.
      - SharedSymbol, with a new `binary` = "01.square".
      - StatusSymbolImage and LiveSymbolEffect.
      - ChipFlowLayout, ToolCallLocationChips and their Location, DiffFileChip, DiffSummary.
      - EditorKitDiffRenderer, DiffLayout and `\.diffLayout`.
      - AgentScopeKind.toolCall and its segment factory.
    - Mechanism: AVK applies `.requestActionStyle` and `.agentControlScope` through `AgentStatusBarActionStyle`, set with `.statusBarActionStyle(_:)` in StateBanner, SessionStreamBanner and AgentConnectionBanner. AVK applies the inspector and attachment scope through `AgentLocationChipStyle`.
    - Clock symbols replaced at every use:
      - replaying → arrow.trianglehead.counterclockwise
      - partialHistory → questionmark.text.page
      - activity → waveform.path.ecg
      - entryTime → calendar. hourglass was dropped because SymbolConceptTests found it is the pending symbol.
    - Naming deviation: the coordinator asked for `StateBanner.Message`. It is `StatusBar.Message`, because StateBanner is the ACP-bound AVK view. Severity has `.neutral` (the default), `.information`, `.warning` and `.failure`.
    - Stays in AVK, because it is ACP-bound:
      - ToolKindSymbol and ToolStatusSymbol mappings.
      - DiffSummary.files(of: Diff), gitPatchText and hasPath.
      - DiffView.
      - The other scope kinds and the ToolCallEntry subject.
      - The agent-only symbols, as an extension of SharedSymbol.
    - The 10 moved catalog keys were removed from AVK's Localizable.xcstrings.
    - Tests:
      - New AgentViewKitStyleTests (no `@testable import`): 37 tests.
      - New AgentViewKitStyleClosureTests. The closure has no FoundationModelsACP, Textual or SwiftUIMath, and KanbanViewKit stays forbidden.
      - ManifestTests, KitSourceFiles and the other PackageStructureTests now cover both targets.
    - Docs: a docc catalog (AgentViewKitStyle.docc), ARCHITECTURE.md ("AgentViewKit is the shared visual layer", with the products table), plan.md, acp-client-kit.md, dependencies.md and the README.
    - Evidence:
      - `swift test` is green: PackageStructureTests 274 passed, AgentViewKitTests 1899 passed (7 known issues), AgentViewKitStyleTests 37 passed. No warnings except the existing mlx-swift_Cmlx one.
      - Scripts/test-examples.sh (it takes the UI-test lock): 9 UI tests and 0 unexpected failures. The only failure is the known `The composer editor is not hittable` (EditorKit ^sva41w0).
      - Snapshots: no pixel change and none re-recorded.
    - Nothing is staged or committed. The card stays in doing.
  timestamp: 2026-10-28T14:18:53.766309+00:00
position_column: doing
position_ordinal: '8480'
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