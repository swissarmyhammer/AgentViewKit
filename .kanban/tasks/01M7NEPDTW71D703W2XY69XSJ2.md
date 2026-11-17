---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7nge8hxh3txw66872mzktnm
  text: 'Decision from testudoapp-75: option (ii). EditorKit adds a light, selectable, read-only label view: no EditorModel, joins TextSelectionRegion, keeps the SwiftUI font and attributes, sizes like Text, uses the theme text color roles, and `menu(for:)` gives the host item menu. Do not build an AppKit wrapper in AVK. Requested from editorkit-7a. BLOCKED until EditorKit gives it.'
  timestamp: 2026-11-17T19:41:15.709237+00:00
- actor: claude-code
  id: 01m7ngfj6nwvh0de9jrtsvgfvb
  text: 'EditorKit task 01M7NGEQT0VKWDQ79RKZ6S8XE8 (EditorLabel). Proposed API: `EditorLabel(_ text: AttributedString)`, `EditorLabel(verbatim: String)` in EditorSwiftUI. No date. editorkit-7a sends the commit after review. Told testudoapp-75 that there is no date.'
  timestamp: 2026-11-17T19:41:58.357294+00:00
position_column: todo
position_ordinal: '8480'
title: 'AVK-9.5: Selection and context menu on EditorView; replace SelectableText'
---
D185. `EditorView` already joins `ThreadTextSelection` (the EditorKit `TextSelectionRegion`).

- Replace `SelectableText` (about 12 call sites: PermissionView, ElicitationView, ElicitationWhoAsks, ElicitationURLConsentView, TerminalView, DiffView, TaskListView, SessionMessageView, CompactionEntryView, ThreadSelectableTextStyle) with a read-only EditorView (plain text, `.source`, intrinsic).
- Check that a right click in `EditorView` shows the item menu of the kit (D193 (f)). Then remove `TextualSelectionRegion`, its probe and `TextualContextMenu`.

Acceptance: unit tests; the hosted tests for the selection and the context menu are updated and compile.

#avk-9