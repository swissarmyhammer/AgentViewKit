---
assignees:
- claude-code
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