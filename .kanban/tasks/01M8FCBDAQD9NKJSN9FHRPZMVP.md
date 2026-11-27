---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: 'Static rows at rest: check and fix the drag selection that starts on static text'
---
From ^7625j1b (2026-11-27). A row that came into the list in a live motion now keeps its static form at rest, until an interaction. A press on its static text makes the row real (StaticEditorSlot, DragGesture of minimum distance 0). The mouse-down of that press went to the SwiftUI still view, before the EditorKit text view was in the view tree. Thus that same drag probably selects no text, and the user must press and drag again. Before ^7625j1b, the queue made the rows real within a few frames at rest, so a later drag reached the editor.

## What
- [ ] A hosted test (IntegrationTests, a `PointerHostedTests` suite, as TranscriptWaitingRowClickPointerHostedTests) that presses on the static text of a waiting row, drags over the text, and releases. It reads the selection of the editor after the drag.
- [ ] If the test shows no selection: find a SwiftUI or EditorKit path that gives the drag to the new editor (for example, an EditorKit API that starts a selection at a point of the text, which the slot calls from its gesture). No AppKit rewrite.

## Acceptance Criteria
- [ ] One press and drag on the static text of a row at rest selects the text under the drag.

## Workflow
- Use `/tdd`. #perf