---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: Transcript search marks in plan entries and diffs (D207 f)
---
Follow-up of ^yxxnx1f. That task marks the matched words of a search hit in the EditorKit editors of a row (`RenderedMarkdownView`, `CommandOutputView`, `TerminalView`) and in the title of a tool call (`TranscriptSearchMatches.highlighted`). Two text parts of an entry have no marks yet:

- The text of each plan entry (`PlanEntryRow` in `Status/TaskListView.swift`, an EditorKit `EditorLabel`). Find out if `EditorLabel` draws the SwiftUI `backgroundColor` of an `AttributedString`. If it does not, ask editorkit-7a for a mark hook on `EditorLabel`.
- The patch text of a diff of a tool call (`Diff/DiffView.swift`). D207 (a) puts the patch text in the chunk of the tool call. Find out if the EditorKit diff view takes mark decorations (`.editorMarks(_:)`).

Use the same match rule (`TranscriptSearchMatches.ranges(of:in:)`: no case, no diacritics, at the start of a word) and the row mark of the environment (`\.transcriptSearchMark`).

Tests (unit, no window): the marks of a plan entry with a matched word.