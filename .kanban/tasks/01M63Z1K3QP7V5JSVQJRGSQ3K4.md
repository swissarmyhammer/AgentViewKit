---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m63zeprckfe15zd0r22sekgs
  text: 'When this lands, send the commit hash and the list of changed views to testudoapp-af, for Testudo card ^j5t8dxr (Testudo uses the full AgentViewKit). KVK doesn''t need it: it links only AgentViewKitStyle. Requested by kanbanviewkit-07 on 2026-10-29.'
  timestamp: 2026-10-29T14:01:37.292729+00:00
- actor: claude-code
  id: 01m64nxeemy8j3v184kkkx179x
  text: |-
    ### implement — changed
    - evidence: commit c7f668e on wt/no-outer-padding (worktree AgentViewKit-wt/no-outer-padding). swift build --build-tests clean (only the known mlx warning); swift test --filter PackageStructureTests 297/297 green incl. new OuterPaddingTests; demo xcodebuild build SUCCEEDED.
    - not run (by instruction: another agent records snapshots): hosted tests, snapshot/capture tests, Examples UI tests. To run after merge: ThreadBarInsetHostedTests (header now measured +2·spacing.s; test updated), ConversationViewHostedTests, ThreadTopBarHostedTests, ConnectionModelViewsHostedTests, SessionListView*/Sources*/TaskList hosted suites, then re-record snapshots.
    - discoveries: SwiftUI gives .contentMargins to the NSScrollView as contentInsets, so ConversationView keeps its row padding (its contentInsets must equal the bar heights). contentMargins does not leak into a nested ScrollView. EditorKit has no theme-aware scroll-margin wrapper; added .scrollContentMargins(_:) in AgentViewKitStyle — candidate to move to EditorStyle.
    - look changes vs before (default theme): badge padding 6/2 → 8/4; completion row inset 2 → 4; session row line spacing 2 → 4; plan tile loses the trailing rowPadding below the last entry; AgentInfoHeader accessibility frame no longer includes the glass inset.
    - next: /review; snapshots re-recorded after merge; send hash + view list to testudoapp-af for ^j5t8dxr.
  timestamp: 2026-10-29T20:34:08.980381+00:00
position_column: todo
position_ordinal: b280
title: 'No outer padding on controls: AVK views carry no default margin; the containing layout spaces them with theme values'
---
User rule (relayed by kanbanviewkit-07 on 2026-10-29, for every view kit): "padding and margin should be modifiers or wrappers that are theme aware for defaults. i don't want to fight padding and margin 'between' controls. inside a control - icon text in a button for example of course you need to pad or margin, but a control itself should not have a margin or pad by default, that is a containing layout concern." EditorKit's matching fix is ^zycpt0j (SingleLineField lineFragmentPadding).

Start after ^x7z136m merges, because both change the same views and their reference PNGs.

## Outer violations (from a read-only audit of main at 4e33394)
- [ ] Status/SessionNoticeBanner.swift:70: `.padding(tile.margin)`. Move it to the container that places the banner.
- [ ] Status/SessionStreamBanner.swift:185: `.padding(tile.margin)`. Move it to the parent.
- [ ] Connections/AgentConnectionBanner.swift:45: `.padding(tile.margin)`. Move it to the safeAreaBar VStack (Thread/AgentThreadView.swift:297).
- [ ] Connections/AgentInfoHeader.swift:69-70: horizontal m and vertical s padding. The parent applies it before `.floatingGlass()` (AgentThreadView.swift:304), or a header-glass wrapper does.
- [ ] Status/TaskListView.swift:215: PlanEntryRow `.padding(.vertical, rowPadding)`. Use the row stack's `spacing:` instead.
- [ ] Citations/SourcesView.swift:168: SourceRow `.padding(spacing.xs)`. Use the stack spacing instead.
- [ ] Input/EditorKitPromptEditor.swift:639: PromptCompletionRow `.padding(.horizontal, 2)` after `.selectableSurface`. Move it to the menu container, using a theme value.
- [ ] Lists/AgentRowList.swift:133, Activity/ActivityTimeline.swift:109, Thread/ConversationEmptyState.swift:117 (and check ConversationView.swift:277): the scroll content insets itself. The host applies the margin through a theme-aware wrapper (EditorKit's, if one exists; otherwise ask EditorKit for one) or through contentMargins from the parent.

## Hard-coded spacing → theme
- [ ] Sessions/PendingRequestCountBadge.swift:40,44 (6, 2); EditorKitPromptEditor.swift:612 (2); SessionListView.swift:82 (2); SessionListView.swift:232 `.padding()` and :304 `.padding(.horizontal)` (system defaults). Each becomes a `\.editorStyle` value.

## Keep (internal)
Padding inside a control's own surface stays: AgentOneLineField:193, PromptFieldSurface:391, RequestDeck:392, and the chip content insets and chip shape fills (ToolCallLocationChips, DiffFileChip, ElicitationTabChip, AttachmentChip, PendingRequestCountBadge, InlineCitation). The opt-in wrappers stay too: ContentTile, EditorBlockChrome, and AgentRowList's row padding before selectableSurface.

## Guard and gates
- [ ] A package-structure test (EditorKit's shared style scanner if ^3q7j9nd has landed, otherwise SourceScanning) fails when a public kit view's body ends with `.padding`, `.safeAreaPadding` or `.contentMargins`, or when a padding or spacing literal other than 0 appears outside an allowlist of internal insets.
- [ ] The demo, thread and gallery look the same as before. Any spacing that moved now comes from the parent. Re-record the snapshots from real capture, and the review gallery shows the result.
- [ ] `swift test` and Scripts/test-examples.sh are green.