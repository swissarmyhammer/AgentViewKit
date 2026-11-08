---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6xxxdwdsqyewngwg4b88qrw
  text: |-
    Research results:
    - EditorSwiftUI of EK already depends on EditorCommandsUI. Thus the EditorCommandsUI product in AgentViewKitStyle adds no new package to the closure of the style target (no ACP product). It is acceptable: step 1 uses the first way (`.selectableSurface` wraps `.selectableItem`).
    - EK scope: `showsRing = holdsFocus && !hasItemSurface`. The `ScopeItemSurfaceKey` preference goes to the NEAREST enclosing scope. Thus a `.selectableItem` on a part with no scope of its own (the file chips of DiffView, the tab chips of an elicitation) goes to the scope around it (for example a tool call), removes the ring of that scope, and fills each chip with the focus fill of that scope. These parts must show the selection only: they use a selection-only form (EK `.selectionSurface` with the hit shape), not `.selectableItem`.
    - Items with no surface (no edge, no fill): message rows, tool call tiles, the attachment inspector panel. They keep the scope ring.
    - Items with a surface: AgentRowList rows, the permission card (edge), the AttachmentChip (base fill), file views with `InspectorSelectable` (AttachmentView, ImageView, location chips). ArtifactView (edge) holds an AttachmentView of the same attachment with no scope of its own: that file view is the item surface of the shared scope. A second fill on the artifact card would stack on it.
    - The permission card is focusable (`@FocusState`, `.focusEffectDisabled()`): a landing gives the focus to the card, not to the beacon, so `\.commandScopeHoldsFocus` is false and the card shows `.editorFocusRing`. EK permits this ring for a focusable card. EK has no public API to draw the focused fill from the focus of a focusable view (`selectableItemSurface(isSelected:isFocused:cornerRadius:)` is `package`).
  timestamp: 2026-11-08T15:54:57.805146+00:00
- actor: claude-code
  id: 01m6xybcstaq1bqkfwtdy7r74h
  text: |-
    Implementation landed (not committed):
    - Package.swift: `EditorCommandsUI` in `styleEditorKitProducts`.
    - SelectableSurface.swift: `.selectableSurface(_:corners:)`/`(_:radius:)` wrap EK `.selectableItem(isSelected:cornerRadius:)`. New `.selectionSurface(_:corners:)` (EK `.selectionSurface` + hit shape) for a part with no scope of its own (DiffView file chips, ElicitationTabChip). Reason: `.selectableItem` on such a part tells the scope AROUND it (for example a tool call) that it shows the focus; that scope then loses its ring and every chip shows the focus fill.
    - AgentItemScope: `focusRingCorners: SurfaceCorners` became `focusLook: AgentItemFocusLook` (`.ring(corners)`, `.fill(corners)`, `.contentSurface`). Ring only for `.ring`. `.fill` puts `.selectableSurface(false, corners:)` inside the scope.
    - Sites: messages and tool calls `.ring(.card)` (default); attachment inspector `.ring(.card)`; permission card `.fill(.card)`; AttachmentChip `.fill`; AttachmentView, ImageView, location chips, ArtifactView `.contentSurface`.
    - AttachmentChip base fill reads `\.isItemStateFillShown` (`AttachmentChipFill`).
    - AgentRowList row: `.scopeFocusRing` removed. The list area keeps its ring.
    - AgentControlScope: no change (native controls).
    - Tests (IntegrationTests): new `aFocusedViewWithASurfaceShowsNoScopeRing` (5 surfaces), `theFocusedInspectorShowsItsScopeRing`, `aFocusedRowShowsNoScopeRing`, `aFocusedItemWithNoSurfaceShowsItsScopeRing` (message, tool call), `DiffViewFocusLookHostedTests.aFocusedScopeAroundADiffShowsItsRing`. They read `ScopeFocusIndicator.showsRing` through `@testable import EditorCommandsUI`. RED before the change, GREEN after.
    - Note: the DiffView guard must use a diff with no patch text: the patch editor is a focusable view and takes the focus from the beacon, so the scope never shows a ring.
  timestamp: 2026-11-08T16:02:35.450469+00:00
- actor: claude-code
  id: 01m6xyn4ycsm4dc6wywpp5f022
  text: |-
    ### implement — changed
    - evidence: 18 modified + 2 new files (Package.swift, ARCHITECTURE.md, AgentViewKitStyle SelectableSurface.swift + docc, AgentItemScope, AgentAttachmentScope, AgentRowList, AttachmentChip, AttachmentView, ArtifactView, ImageView, ToolCallLocationChips, RequestDeck, DiffView, ElicitationTabChip, ElicitationLayout; tests AttachmentFocusHostedTests, AgentItemFocusHostedTests, AgentRowListCurrentHostedTests, new DiffViewFocusLookHostedTests, new Helpers/CommandSystem+FocusRing). `swift test`: 1074 tests + 50 tests passed, 0 warnings. `swift test --package-path IntegrationTests`: 1037 tests passed, 5 known issues (all FontRoleExpectationsTests, deliberate). `swift test --package-path ScreenshotTests`: 32 tests passed; all 184 PNGs recorded again, 0 PNGs changed in content (md5 same): no snapshot shows a focused item.
    - follow-up tasks: ^ekc1mpb (permission card keeps `.editorFocusRing` because the card's own focusable view takes the focus; EK has no public focused-fill API), ^r3sm8nh (snapshot of the focus look).
    - next: /review. Not committed, not pushed.
  timestamp: 2026-11-08T16:07:55.084949+00:00
- actor: claude-code
  id: 01m6xywve676zyafnkrqewgzyv
  text: |-
    ### test — green
    - evidence: swift test: 1074 tests in 123 suites passed (plus 50 tests in 10 suites passed), 0 failures. swift test --package-path IntegrationTests: 1037 tests in 143 suites passed, 5 known issues (deliberate negative tests in FontRoleExpectationsTests). swift test --package-path ScreenshotTests: 32 tests in 4 suites passed. No compiler warnings in changed code. Each run printed one SwiftPM build-system message, "missing creator for mutated node" for the mlx-swift_Cmlx.bundle. It is not in changed code.
    - next: review
  timestamp: 2026-11-08T16:12:07.494270+00:00
position_column: doing
position_ordinal: '80'
title: 'Selection and focus: AVK items use EK .selectableItem (style.md "Selection and focus")'
---
EditorKit style.md has a new rule, "Selection and focus" (EK 0a95dae6). EK card ^kzr7way adds the modifier, on EditorKit main bab334ea.

## The rule
- A native control keeps the system focus and selection look.
- A kit item (card, chip, row, tile) shows its state as a fill in its own shape, with no outline: a soft accent fill when selected, a stronger accent fill when its scope holds the focus, and grey when the window is not key.
- An item with a surface shows no scope focus ring. An area with no surface (a panel, a list) keeps its ring.
- The reference look is the selected PathChip in the SVK gallery (shared-path-chip-change).

## The EK API (EditorCommandsUI, Sources/EditorCommandsUI/SelectableItem.swift)
- `.selectableItem(isSelected: Bool, radius: EditorStyle.Radius)` and `.selectableItem(isSelected: Bool, cornerRadius: CGFloat)`. Put it INSIDE the `.commandScope` of the item. It draws the fill (selected: accent at `EditorStyle.selectionOpacity`; scope holds focus: accent at `EditorStyle.focusedSelectionOpacity`; window not key: grey), sets the hit and focus shape in the same corners, and tells the enclosing scope to draw no ring.
- `\.commandScopeHoldsFocus` (read only).
- `\.isItemStateFillShown` (EditorStyle, read only): a base fill of an item goes INSIDE `.selectableItem` and draws nothing while it is true.

## Changes in AgentViewKit
Step 0: Update the EditorKit pin to bab334ea or later in the root package, IntegrationTests and ScreenshotTests (`swift package --package-path <p> update EditorKit`). Package.resolved is git-ignored.

1. Keep one way for kits: `.selectableSurface(_:corners:)` and `.selectableSurface(_:radius:)` of AgentViewKitStyle (Sources/AgentViewKitStyle/Theme/SelectableSurface.swift) wrap `.selectableItem(isSelected:cornerRadius:)` with the radius of the corners. They keep working for an item with no scope (a gallery sample). AgentViewKitStyle may need the EditorCommandsUI product: check Package.swift (`styleEditorKitProducts`) and add it if necessary. If the dependency is not acceptable in the style target, record the reason on this card and use the other way (replace `.selectableSurface` with `.selectableItem` at each use site).
2. Every selectable item of AVK must have its surface modifier INSIDE its `.commandScope`, and must not add `.scopeFocusRing` on top. Check each site:
   - Sources/AgentViewKit/Lists/AgentRowList.swift:586-588 (row: `.selectableSurface` is outside the scope now through `wrappedSurface`? check the order; remove `.scopeFocusRing(radius:)` of the row). The list area at :331-332 has no surface: it keeps its ring.
   - Sources/AgentViewKit/Commands/AgentItemScope.swift:59-61 (message rows, permission request cards, tool call cards, attachment items through AgentAttachmentScope). An item with a surface removes `.scopeFocusRing`, and shows focus as the stronger fill (`.selectableItem(isSelected: false, ...)` inside the scope if the item is not selectable). An item with no surface keeps the ring.
   - Sources/AgentViewKit/Elicitation/ElicitationTabChip.swift:43, Sources/AgentViewKit/Diff/DiffView.swift:245, Sources/AgentViewKit/Attachments/AttachmentView.swift:237, Sources/AgentViewKitStyle/Theme/SelectableSurface.swift:117.
   - Sources/AgentViewKit/Commands/AgentControlScope.swift:70-72: native controls keep the system focus look. Do not change unless the control draws its own item surface.
3. A base fill of an item (a card background) goes INSIDE the selection modifier and reads `\.isItemStateFillShown`, so no two fills stack.
4. Update the doc comments that talk about the focus ring of items (for example AgentItemScope, SelectableSurface).
5. Tests: update the tests that check the focus ring of an item. Add a test that a focused item with a surface draws no scope ring. Test rules: no clock/sleep/poll/retry/timeLimit/XCUITest; tests never show a window or take focus.
6. Record all the screenshots again (`swift test --package-path ScreenshotTests`) and give the changed PNG paths to the user.

## Acceptance criteria
- A selected item shows the soft accent fill. A focused item shows the stronger fill. Inactive window: grey. No outline on items with a surface.
- Lists and panels with no surface keep their ring. Native controls do not change.
- All unit, integration and screenshot tests pass.
- The snapshot images are new, and the user has the paths.

Commit only. Do not push: the user of AVK decides the push.