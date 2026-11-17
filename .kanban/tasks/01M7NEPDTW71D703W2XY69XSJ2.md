---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'AVK-9.5: Selection and context menu on EditorView; replace SelectableText'
---
D185. `EditorView` already joins `ThreadTextSelection` (the EditorKit `TextSelectionRegion`).

- Replace `SelectableText` (about 12 call sites: PermissionView, ElicitationView, ElicitationWhoAsks, ElicitationURLConsentView, TerminalView, DiffView, TaskListView, SessionMessageView, CompactionEntryView, ThreadSelectableTextStyle) with a read-only EditorView (plain text, `.source`, intrinsic).
- Check that a right click in `EditorView` shows the item menu of the kit (D193 (f)). Then remove `TextualSelectionRegion`, its probe and `TextualContextMenu`.

Acceptance: unit tests; the hosted tests for the selection and the context menu are updated and compile.

#avk-9