---
assignees:
- claude-code
position_column: todo
position_ordinal: aa80
title: Drop the AVK leak workarounds now that EditorKit ^jmq52v6 fixed the onEditCommit leak
---
EditorKit ^jmq52v6 is on main at 3cb4805. The view now holds the edit-commit callback and the model reaches it only through a weak receiver, so a callback can capture view state or the model without leaking. `EditorModel.onEditCommit` no longer exists. No public API changed.

## Work
- [ ] Bump the EditorKit pin to 3cb4805 or later (`swift package update EditorKit`)
- [ ] AgentOneLineField.swift: remove the `SubmitRelay` weak-relay workaround (^nth5f7e) and pass the submit callback straight through. Fix the doc comment at :128, which names `EditorModel.onEditCommit`.
- [ ] ElicitationFieldViews.swift: remove the static `run(_:for:)` workaround and fix the doc comment at :279
- [ ] Check that ElicitationNumberField no longer leaks with no change
- [ ] Keep the release tests `PermissionCommentFieldHostedTests.anAnsweredCardTakesTheTypingOfItsCommentFieldOffTheWindowUndoStack` and `ElicitationTextFieldEditingHostedTests.aSubmittedFormTakesTheTypingOfItsFieldOffTheWindowUndoStack`, and they must still pass. Where it fits, use EditorTestSupport's new `WeakHold` / `ReleasedEditorBed` instead of AVK-local helpers.
- [ ] `swift test` is green