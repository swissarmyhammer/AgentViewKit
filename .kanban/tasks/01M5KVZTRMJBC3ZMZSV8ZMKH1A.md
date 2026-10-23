---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5m60y7xpx93y2zr7jgjz3ae
  text: |-
    From editorkit-28 (2026-10-23), for SingleLineField:
    - `.editorTextAccessibilityIdentifier(_:)` (d4c767f) puts the id on the NSTextView; keep each replaced field's accessibility identifier that way.
    - SingleLineField has its OWN nested `editor:` command scope. Landing focus on an OUTER scope around it (a request card's item scope, for example) focuses the outer scope, not the field: that's the user's nested-scope rule. Landing on the field's own scope focuses the field. So a jump onto a permission card or elicitation card no longer puts the caret in its text field; check any AVK tests or behaviour that expect it, and keep the user's rule.
    - EditorKit f913e78 or later is needed.
  timestamp: 2026-10-23T10:48:35.325462+00:00
- actor: claude-code
  id: 01m5mb24ezg8b916anp150xzre
  text: |-
    Research (implement pass 1):
    - `TextField(` in Sources/AgentViewKit: PermissionView.swift:342 (comment field, `.onSubmit` → sendReject), SessionListView.swift:166 (search, no submit), ElicitationFieldViews.swift:340 (number field `TextField(value:format: .number)` inside a Stepper). No others; Examples has none.
    - `ElicitationTextField` already uses `SingleLineField` for the one-line case (since ^hh9wtfm). Its control identifier is a SwiftUI `.accessibilityIdentifier` on the wrapping container, and SingleLineField gets no `onSubmit`, so Return in it is consumed by the text view; the footer documents "Return presses Submit" (`.keyboardShortcut(.defaultAction)`).
    - EditorKit resolved at 37325a2 (contains f913e78 and d4c767f). SingleLineField: `init(model:id:lineHeight:onSubmit:pasteboard:)`, slot modifiers `.editorSizingMode`, `.editorPlaceholder`, `.editorTextAccessibilityIdentifier`. Its own `editor:<id>` scope via EditorContributorScope. Esc = one inverse transaction to the focus-in snapshot, then drill out. No value/format API.
    - Number field gap: SingleLineField edits a String `EditorModel` only. It has no `value:format:` (ParseableFormatStyle) init, so no parse of typed text into a Double, no reformat of the shown text when the value changes from outside (the Stepper), and no revert of unparsable input to the last valid value; and it exposes no public focus-out/commit hook (the controller's focusDidEnd is internal wiring), so a host cannot commit a typed number when focus leaves the field. Keeping the number field on `TextField(value:format:)`.
    - Prevailing pattern for the identifier: EditorKitPromptEditor `.editorTextAccessibilityIdentifier(...)` + `.accessibilityLabel(...)`; tests use `harness.element(identifier:)` / `views(withAccessibilityIdentifier:)`. Window undo tests: ComposerWindowUndoHostedTests (`MountedThread`, `system.registry.perform(.undo, at: path)`).
  timestamp: 2026-10-23T12:16:37.343431+00:00
- actor: claude-code
  id: 01m5mbw387mqwyccs6p99bkgxt
  text: |-
    BLOCKER — two EditorKit gaps (measured at 37325a2; upstream 0e145a8 is the same), plus the number-field gap.

    1. SingleLineField never joins the window undo stack. `EditorView` reads `@Environment(\.undoStack)` and calls `coordinator.join(undoStack)` (EditorView.swift), which makes the `EditorUndoSource`. `SingleLineFieldRepresentable` wraps the same `EditorView.Coordinator` but never reads `\.undoStack` and never calls `join`, so typing in a SingleLineField under a root `.commandScope` leaves `WindowUndoStack.canUndo == false`. EditorCommandsUI.docc/WindowUndo.md says SingleLineField gets "full undo and redo on the window's stack"; the code does not do it. Red tests: PermissionCommentFieldHostedTests.theWindowUndoTakesTheTypingOutOfTheCommentField, SessionListSearchFieldHostedTests.theWindowUndoTakesTheTypingOutOfTheSearchField, ElicitationTextFieldEditingHostedTests.theWindowUndoTakesTheTypingOutOfTheField (each fails at `#require(window.stack.canUndo)` after typing). Fix belongs in EditorKit: SingleLineFieldRepresentable should join `\.undoStack` the way EditorView does.

    2. No way to label the text view. `.editorTextAccessibilityIdentifier` puts the id on the NSTextView, but EditorKit has no matching slot for its accessibility label; SwiftUI `.accessibilityLabel` on the field does not reach the NSTextView (same reason as the identifier). Measured: the element with the field identifier has label `nil` for all three fields (was the TextField title / the "Name" container label). `.editorPlaceholder` does set the AX placeholder value. Red tests: the three `theTextViewOf…AloneCarries…Identifier` tests (label assertion). Fix belongs in EditorKit: an `.editorTextAccessibilityLabel(_:)` slot beside the identifier.

    3. Number field kept on `TextField(value:format: .number)`: SingleLineField edits a String model only — no ParseableFormatStyle/value init (parse typed text, show a changed number when the Stepper moves it, keep the last valid number for text that is not a number) and no public focus-out/commit hook to commit a typed number when focus leaves. Noted in the ElicitationNumberField doc comment.

    Landed in AVK (working tree, not committed): AgentOneLineField (Input/) = SingleLineField + intrinsic sizing + placeholder + text identifier + shared AgentTextInputEdge; EditorModelSlot moved out of ElicitationFieldViews and shared. PermissionView comment → AgentOneLineField, Return sends the reject with the comment, Esc reverts and keeps the request. SessionListView search → AgentOneLineField (Return submits nothing). ElicitationTextField: control identifier moved from the SwiftUI container onto the text view (one element, no duplicate); Return now presses Submit via an internal `elicitationReturnAction` environment value from ElicitationView (it did not before: the field swallowed Return, so the footer's `.defaultAction` never fired). Nested-scope rule: no existing AVK test expected the caret in a field after a card jump; added PermissionCommentFieldHostedTests.aJumpOnTheCardFocusesTheCardAndNotItsCommentField and aJumpOnTheScopeOfTheCommentFieldFocusesItsTextView. Snapshots: none changed, none re-recorded. Demo build not run: xcodebuild package resolution needs ssh to github, which this sandbox blocks.
  timestamp: 2026-10-23T12:30:48.071643+00:00
- actor: claude-code
  id: 01m5mbw9nsq0a063mk2s4wb3p9
  text: |-
    ### implement — stuck
    - evidence: `swift test` 1713 tests, 6 issues (+3 known). The 6 are the EditorKit gaps above: 3× window undo (`window.stack.canUndo` false after typing in a SingleLineField), 3× text-view accessibility label `nil`. All other tests green, incl. PackageStructureTests (227), ElicitationFieldErrorsHostedTests, PermissionViewHostedTests, snapshot suites (no snapshot changed). Fields replaced: PermissionView comment, SessionListView search; ElicitationTextField was already SingleLineField (identifier moved to the text view, Return now submits). Kept: ElicitationNumberField TextField(value:format:). Red→green: identifier (3), Return (3), Esc (3), field-scope jump (1); card jump rule test passes before and after.
    - next: EditorKit (editorkit-28) to (1) join `\.undoStack` in SingleLineFieldRepresentable like EditorView, (2) add a text-view accessibility label slot, (3) optionally a value/format init with a commit hook for numbers. Then re-run the three undo and three label tests; no AVK code change expected beyond deleting the `.accessibilityLabel` calls in favour of the new slot.
  timestamp: 2026-10-23T12:30:54.649472+00:00
- actor: claude-code
  id: 01m5mbxpsneqeb8rmh896031yz
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the permission comment (PermissionView) and session search (SessionListView) use the new AgentOneLineField over SingleLineField; ElicitationTextField's identifier is on the text view only, and Return now presses Submit when the form is complete; the number field is kept as TextField(value:format:), noted in its doc. Red→green: identifier 3, Return 3, Esc 3, field-scope jump 1; new test aJumpOnTheCardFocusesTheCardAndNotItsCommentField states the nested-scope rule.
    - swift test: 1713 tests, 6 FAIL, all EditorKit gaps at 37325a2 (also at 0e145a8): (1) SingleLineFieldRepresentable never reads `\.undoStack` or calls `coordinator.join`, so typing never reaches the window stack (3 tests); (2) there's no way to set the text view's accessibility LABEL, so it's nil for all 3 fields (3 tests); (3) the number field: no value/format init, no parse or re-show, no focus-out commit hook.
    - The work is UNCOMMITTED in the main working tree: git now fails with "unable to access ~/.gitconfig: Operation not permitted" (a sandbox), so it couldn't be parked on a WIP branch.
    - test, commit, review: not run
    - next: EditorKit fixes gaps 1–2 (asked editorkit-28); git access is restored; then rerun the 6 tests.
  timestamp: 2026-10-23T12:31:40.853945+00:00
- actor: claude-code
  id: 01m5mbyyj8h0paeyc4n6btprn1
  text: |-
    Blockers are tracked in EditorKit, queued after ^j7pgvtb (EK-6 on iOS), in this order:
    1. ^q05zxwr (01M5MBY4Z9KBFDTPBSPQ05ZXWR): SingleLineField joins the window undo stack (`\.undoStack` + join, deferred leave on teardown). Typing becomes a burst entry; ⌘Z and ⇧⌘Z work.
    2. ^f4274r9 (01M5MBY9KNC3ZKD0M9RF4274R9): `.editorTextAccessibilityLabel(_:)` (plus a hint if cheap), set on the NSTextView only.
    3. ^99zb1dt (01M5MBYECEZZJ7VHR1A99ZB1DT): SingleLineField(value:format:) with TextField(value:format:) semantics, plus a public commit/focus-out hook. After it lands, also move the elicitation number field (ElicitationFieldViews) to SingleLineField.
    The 6 red tests cover 1 and 2. editorkit-28 will send SHAs.
  timestamp: 2026-10-23T12:32:21.576618+00:00
- actor: claude-code
  id: 01m5mjmkwm6409chk9hpyfdjr3
  text: |-
    ### finish — waiting on EditorKit
    - EditorKit main is at 818fb5a: ^j7pgvtb is done, and ^q05zxwr, ^f4274r9 and ^99zb1dt are still in todo. editorkit-28 is working on ^fe03a6.
    - Asked editorkit-28 (2026-10-23) to take ^q05zxwr and ^f4274r9 next, and to send their SHAs to agentviewkit-6c.
    - The working tree still holds this card's uncommitted work. The user said to finish this card first, working with editorkit.
    - next: when the SHAs come in, `swift package update EditorKit` → /implement (swap `.accessibilityLabel` for `.editorTextAccessibilityLabel`) → /test → /commit → /review.
  timestamp: 2026-10-23T14:29:02.996264+00:00
- actor: claude-code
  id: 01m5mng5kv2w6s3bb5xsrmgxf8
  text: |-
    ### EditorKit ^q05zxwr checked
    - `swift package update EditorKit` → main 3965543 (Package.resolved)
    - The 3 field suites (16 tests): the 3 `theWindowUndoTakesTheTyping…` tests pass now. The 3 label tests still fail as expected (`.label` nil): PermissionCommentFieldHostedTests.swift:83, SessionListSearchFieldHostedTests.swift:73, ElicitationTextFieldEditingHostedTests.swift:54.
    - New in EditorKit: Esc-revert is now an undoable "Revert" entry on the window stack. The full suite will show whether any test that counts entries after an Esc breaks.
    - next: wait for the ^f4274r9 SHA
  timestamp: 2026-10-23T15:19:03.035854+00:00
- actor: claude-code
  id: 01m5myenq75pvdj6masammp6h7
  text: |-
    Implement pass 2 (EditorKit ^f4274r9 landed):
    - `swift package update EditorKit` → main 8e4d27a (root Package.resolved, gitignored). The demo has its own gitignored resolution (AgentViewKitDemo.xcodeproj/.../swiftpm/Package.resolved) that still pinned 37325a2, which lacks `.editorTextAccessibilityLabel`; set its EditorKit pin to 8e4d27a so the demo builds.
    - `.editorTextAccessibilityLabel(_:)` is an `EditorSlotComposing` modifier (returns Self), so it must sit in the EditorKit modifier chain before any SwiftUI modifier, beside `.editorTextAccessibilityIdentifier`.
    - AgentOneLineField: SwiftUI `.accessibilityLabel(placeholder)` → `.editorTextAccessibilityLabel(placeholder)`; doc comment no longer says the label cannot reach the text view. PermissionView comment and SessionListView search go through AgentOneLineField, so they need no change of their own.
    - ElicitationTextField: the SwiftUI `.accessibilityLabel(title)` sat over BOTH branches of `input(model:)`; moved to `.editorTextAccessibilityLabel(title)` on the SingleLineField AND on the multi-line EditorView (the SwiftUI label never reached either text view). New test ElicitationFieldViewsHostedTests.theTextViewOfAMultiLineFieldCarriesTheTitleAsItsLabel (red: label nil → green).
    - EditorKitPromptEditor used the same pattern (`.accessibilityLabel(context.placeholder)` after the text identifier, label nil on the text view). Moved to `.editorTextAccessibilityLabel(context.placeholder)`. New test EditorKitPromptEditorHostedTests.theTextViewOfTheEditorCarriesThePlaceholderAsItsLabel (red: nil → green).
    - Number field kept on `TextField(value:format:)` with its doc note, until ^99zb1dt.
    - Esc "Revert" entry (from ^q05zxwr): no AVK test counts window-stack entries after an Esc. The only stack assertions in Esc-touching suites (`!stack.canUndo` / `stack.canRedo`) follow an undo of typing, not an Esc, and all pass. Nothing to change.
    - Formatter: the repo has no configured formatter — no .swift-format, .swiftformat, .swiftlint.yml, no Airbnb plugin in Package.swift, no format step in CI. Running swift-format or SwiftFormat with defaults would rewrap many untouched lines (the committed code runs past swift-format's 100-column default), so no formatter was run; the edits follow the surrounding style.
    - Demo build: first fresh-DerivedData `xcodebuild` hung with 0% CPU for ~1h (no output, no files written after the first minute); killed it. A second run with `-skipMacroValidation -skipPackagePluginValidation` (macros otherwise need interactive trust) → BUILD SUCCEEDED, 0 warnings, EditorKit @ 8e4d27a.
  timestamp: 2026-10-23T17:55:31.175371+00:00
- actor: claude-code
  id: 01m5myetfqsk8tpsnj805sh8r2
  text: |-
    ### implement — changed
    - evidence: `swift test` 1715 tests in 211 suites passed, 0 failures, 3 known issues (the pre-existing intentional `withKnownIssue` checks: SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests); PackageStructureTests 227 passed. Red→green: the 3 label tests (PermissionCommentFieldHostedTests, SessionListSearchFieldHostedTests, ElicitationTextFieldEditingHostedTests) plus 2 new (EditorKitPromptEditorHostedTests.theTextViewOfTheEditorCarriesThePlaceholderAsItsLabel, ElicitationFieldViewsHostedTests.theTextViewOfAMultiLineFieldCarriesTheTitleAsItsLabel). Demo `xcodebuild build` succeeded, 0 warnings. Files this pass: Sources/AgentViewKit/Input/AgentOneLineField.swift, Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift, Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Tests/AgentViewKitTests/Input/EditorKitPromptEditorHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationFieldViewsHostedTests.swift (+ gitignored Package.resolved files). Snapshots: none changed, none re-recorded. Not committed.
    - next: /review
  timestamp: 2026-10-23T17:55:36.055371+00:00
- actor: claude-code
  id: 01m5myvmmhba4669gz46vg2wyf
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (edeccb9) — 2 findings (2 confirmed, 3 refuted): Sources/AgentViewKit/Input/AgentOneLineField.swift:72 (reuse/reuse), Sources/AgentViewKit/Input/AgentOneLineField.swift:80 (duplication/duplication)
    - note: both findings name the same cause (`EditorModelSlot` duplicates `OwnModelSlot`). The reuse finding says to generalize `OwnModelSlot` with an `editable` parameter. The duplication finding's last sentence says not to edit `OwnModelSlot` as part of this change if it does not fit. `OwnModelSlot` makes a read-only model, so the two directions disagree. If the implementer cannot satisfy both, record this as a blocker and mark the task stuck rather than picking one.
    - next: implementer addresses both checklist items; task stays in review
  timestamp: 2026-10-23T18:02:36.049895+00:00
- actor: claude-code
  id: 01m5mywe6rv8tywmv8a4df5k31
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — EditorKit 8e4d27a; `.editorTextAccessibilityLabel` in AgentOneLineField, ElicitationTextField (one-line and multi-line) and EditorKitPromptEditor; 5 files
    - test: green — swift test, 1715 tests in 211 suites passed, 0 failed, 0 skipped (3 known issues are tests that expect a failure)
    - commit: edeccb9
    - review: findings — Sources/AgentViewKit/Input/AgentOneLineField.swift:72, Sources/AgentViewKit/Input/AgentOneLineField.swift:80
    - The two findings don't conflict: finding 1 asks to add an editable mode to `OwnModelSlot`, and then finding 2's main ask (delete `EditorModelSlot`, use `OwnModelSlot`) fits.
  timestamp: 2026-10-23T18:03:02.232152+00:00
- actor: claude-code
  id: 01m5myz3a45nv7y7f8z468e50m
  text: |-
    Implement pass 3 (review findings 12:58) research:
    - `OwnModelSlot` (Code/OwnModelSlot.swift) and `EditorModelSlot` (Input/AgentOneLineField.swift) are the same class; the only difference is `EditorModel.makeReadOnly(text)` vs `EditorModel(text)`.
    - `OwnModelSlot()` users: CodeBlockView, TerminalView, CommandOutputView (read-only, stay on the default). `EditorModelSlot()` users: PermissionView `comment`, SessionListView `search`, ElicitationTextField `ownModel`.
    - No test covered either slot. AgentOneLineField.swift holds no other copy of the slot (the rest is the field view, `agentTextInputEdge()` and `AgentTextInputEdge`).
    - `PromptEditorSession` (EditorKitPromptEditor.swift) also makes its model lazily but owns the completion engine, commit stream and pushed text, so it is not a copy; its doc line "as ``OwnModelSlot`` does" stays true.
    - Plan: `OwnModelSlot(editable: Bool = false)`; new OwnModelSlotTests (red: no `init(editable:)`).
  timestamp: 2026-10-23T18:04:29.380798+00:00
- actor: claude-code
  id: 01m5mz82rs5596c5se9anetbpq
  text: |-
    ### implement — changed
    - evidence: findings 12:58 both fixed and checked. `OwnModelSlot` gets `init(editable: Bool = false)` and makes `isEditable ? EditorModel(text) : EditorModel.makeReadOnly(text)`; doc comments name the read-only users (CodeBlockView, CommandOutputView, TerminalView, unchanged) and the editable users. `EditorModelSlot` deleted from AgentOneLineField.swift (no other copy in that file); PermissionView `comment`, SessionListView `search`, ElicitationTextField `ownModel` → `OwnModelSlot(editable: true)`. EditorKitPromptEditor's "as ``OwnModelSlot`` does" stays true, unchanged. New Tests/AgentViewKitTests/Code/OwnModelSlotTests.swift (3 tests; red: `init(editable:)` missing → green). `swift test`: 1718 tests in 212 suites passed, 0 failures, 3 known issues (the intentional `withKnownIssue` checks). The only build warning is SwiftPM's "missing creator for mutated node" on the mlx-swift_Cmlx bundle, from the dependency build, not this code. Not committed.
    - files: Sources/AgentViewKit/Code/OwnModelSlot.swift, Sources/AgentViewKit/Input/AgentOneLineField.swift, Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Sessions/SessionListView.swift, Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift, Tests/AgentViewKitTests/Code/OwnModelSlotTests.swift
    - next: /review
  timestamp: 2026-10-23T18:09:23.737986+00:00
- actor: claude-code
  id: 01m5mzg0hw0j65srn7bs4t159a
  text: |-
    ### review — clean
    - evidence: review sha b275da0~1..b275da0 — 0 findings (7 attempted, 0 failed); 6 files reviewed, 2 .kanban files excluded by .reviewignore; both items in Review Findings (2026-10-23 12:58) checked
    - next: task moved to done
  timestamp: 2026-10-23T18:13:43.612089+00:00
- actor: claude-code
  id: 01m5mzgmx5n3mrmexfqe1nka4t
  text: |-
    ### finish iteration 3 — clean
    - implement: changed — `OwnModelSlot(editable:)`; `EditorModelSlot` removed; new OwnModelSlotTests; 6 files
    - test: green — swift test, 1718 tests in 212 suites passed, 0 failed, 0 skipped (3 known issues are tests that expect a failure)
    - commit: b275da0 (+ 5d694c9, a kanban chore for ^8mv9xpj)
    - review: clean — 0 findings; task in done
    - Not pushed. Local commits edeccb9 and b275da0 need EditorKit 8e4d27a or later.
  timestamp: 2026-10-23T18:14:04.453067+00:00
position_column: done
position_ordinal: ffffc980
title: Replace one-line SwiftUI TextFields with EditorKit SingleLineField
---
User decision (2026-10-23, relayed by editorkit-28): a one-line editor uses EditorKit's one-line mode, not a SwiftUI text field. `SingleLineField` (EditorSwiftUI): lineLimit 1, Return submits via onSubmit, Esc reverts, paste flattens newlines; it has full window-stack undo and redo (EK-6).

Candidates named by editorkit-28 (confirm each and search for more `TextField(` in Sources/AgentViewKit):
- `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift:342` (the permission comment field)
- `Sources/AgentViewKit/Sessions/SessionListView.swift:166`
- `ElicitationTextField` (elicitation string fields)
- `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift:340`, a number field. If SingleLineField can't host a formatted number (parse, format, invalid input), don't fake it: report the gap to editorkit-28 and keep that one field on its current control, with a note, until EditorKit supports it.

Keep behaviour:
- the same binding and validation;
- Return submits where it submits today;
- the elicitation error display from ^r8bnszx (errors after an edit or a submit attempt);
- accessibility labels and identifiers;
- the ^cwdb5zg focus behaviour, under the item scopes.

Tests:
- hosted tests that each replaced field edits, submits on Return, reverts on Esc and undoes on the window stack;
- the existing elicitation and permission tests stay green, and the snapshots are re-recorded only where the look changes, listed by name.
Full `swift test` green; the demo builds. #avk-7

## Review Findings (2026-10-23 12:58)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 18 file(s) reviewed, 8 not reviewed.

> 8 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 8 file(s)

- [x] `Sources/AgentViewKit/Input/AgentOneLineField.swift:72` `reuse/reuse` — `EditorModelSlot` reimplements `OwnModelSlot`, an existing class with the same shape: a private optional `EditorModel` that is created on the first `model(text:)` read and then reused. The new class differs only in that it creates an editable `EditorModel(text)` where `OwnModelSlot` creates `EditorModel.makeReadOnly(text)`. That difference is a parameter, so the two copies will drift apart as the slot logic changes. Generalize `OwnModelSlot` so it takes the editability as a parameter, for example `init(editable: Bool = false)`, and makes the model with `editable ? EditorModel(text) : EditorModel.makeReadOnly(text)`. Then delete `EditorModelSlot` and have the `@State` properties in `PermissionView`, `SessionListView`, and `ElicitationTextField` use `OwnModelSlot(editable: true)`. If the read-only model is required by the existing callers, keep `OwnModelSlot`'s default and add only the parameter.
- [x] `Sources/AgentViewKit/Input/AgentOneLineField.swift:80` `duplication/duplication` — The new `EditorModelSlot` duplicates the existing `OwnModelSlot`. Both hold a lazily made `EditorModel` for a view's `@State`, and both `model(text:)` methods make the model on the first read and return it afterward. Two copies of the same state-holding logic can drift apart, and a future fix would have to land in both. Delete `EditorModelSlot` and use the existing `OwnModelSlot` at the four call sites: `ElicitationFieldViews.swift:186`, `PermissionView.swift:140`, `SessionListView.swift:116`, and `AgentOneLineField.swift`. If `OwnModelSlot` does not fit, check its API first, and do not edit it as part of this change.
