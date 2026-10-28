---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m61ccz2n0yyqxaat87085fx3
  text: |-
    ### review — findings
    - evidence: review sha 10f3ff2~1..10f3ff2 — 1 finding (1 confirmed, 4 refuted) — Tests/AgentViewKitTests/Elicitation/ElicitationNumberFieldEditingHostedTests.swift:120 `reuse/reuse`
    - work items: 5 of 6 checked from commit 10f3ff2. Pin: Package.resolved is gitignored, Package.swift tracks EditorKit `main`, and the worktree resolves EditorKit f588cb5, which contains 3cb4805. `swift test` in /Users/wballard/github/swissarmyhammer/AgentViewKit-wt/leak: 1902 tests in 237 suites passed with 7 known issues, 1 skipped (theGeneratedDemoProjectPinsTheRootACPRevisions), 1 SwiftPM build warning (missing creator for mutated node, mlx-swift_Cmlx.bundle). Both release tests and the new number-field test pass. The `swift test` is green item stays unchecked: a skip and a warning are present.
    - next: fold the shared mount/type/Return/fence/undo-stack steps into one helper that both submitted-form tests call, then re-review.
  timestamp: 2026-10-28T13:50:08.469642+00:00
position_column: review
position_ordinal: '8180'
title: Drop the AVK leak workarounds now that EditorKit ^jmq52v6 fixed the onEditCommit leak
---
EditorKit ^jmq52v6 is on main at 3cb4805. The view now holds the edit-commit callback and the model reaches it only through a weak receiver, so a callback can capture view state or the model without leaking. `EditorModel.onEditCommit` no longer exists. No public API changed.

## Work
- [x] Bump the EditorKit pin to 3cb4805 or later (`swift package update EditorKit`)
- [x] AgentOneLineField.swift: remove the `SubmitRelay` weak-relay workaround (^nth5f7e) and pass the submit callback straight through. Fix the doc comment at :128, which names `EditorModel.onEditCommit`.
- [x] ElicitationFieldViews.swift: remove the static `run(_:for:)` workaround and fix the doc comment at :279
- [x] Check that ElicitationNumberField no longer leaks with no change
- [x] Keep the release tests `PermissionCommentFieldHostedTests.anAnsweredCardTakesTheTypingOfItsCommentFieldOffTheWindowUndoStack` and `ElicitationTextFieldEditingHostedTests.aSubmittedFormTakesTheTypingOfItsFieldOffTheWindowUndoStack`, and they must still pass. Where it fits, use EditorTestSupport's new `WeakHold` / `ReleasedEditorBed` instead of AVK-local helpers.
- [ ] `swift test` is green

## Review Findings (2026-10-28 08:47)

> Scope: `review sha 10f3ff2~1..10f3ff2` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 0 not reviewed.

- [ ] `Tests/AgentViewKitTests/Elicitation/ElicitationNumberFieldEditingHostedTests.swift:120` `reuse/reuse` — The new test `aSubmittedFormTakesTheTypingOfItsNumberInputOffTheWindowUndoStack` is a near-copy of the existing text-field test with the same name pattern. It repeats the same mount, type, Return, pending-elicitation check, render check, fence, and undo-stack assertions. Only the typed text and the field differ. Each copy has to be maintained separately. Move the shared steps (mount in the deck, type into the control, assert `canUndo`, press Return, assert the elicitation is gone, fence, assert the stack is empty) into one helper, such as a `SingleLineFieldChecks` function that takes the mounted window, the typed text, and the control identifier. Have both tests call it with their own params and text, so each test keeps only its own setup and expectations.
