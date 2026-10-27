---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5z13whst7td4phmk5ec6kxv
  text: 'Research: EditorKit 79f043e `EditorUndoSource` is held by `EditorModel.undoSource`; its isolated deinit calls `stack.removeOnNextPass`, which is `RunLoop.main.perform` (common modes). So once the kit-owned model dies, its entries leave on the next main run loop pass; `RunLoopBlockFence.afterPendingBlocks()` (common-mode block, FIFO) is the deterministic wait. The kit-owned slots are `PermissionView.comment` and `ElicitationTextField.ownModel` (`OwnModelSlot` in `@State`). The existing `ElicitationViewHostedTests.mount` pins one `ElicitationView` that never leaves the window, so the elicitation test mounts the `RequestDeck` (`AgentCommandScopeHostedTests.mount`), where the answered card leaves. No test can reach the private `@State` model, so RED is verified by a temporary strong hold of each `OwnModelSlot` model (reverted).'
  timestamp: 2026-10-27T15:54:27.769044+00:00
- actor: claude-code
  id: 01m5z1z8assvw4rb1htq4m49q0
  text: |-
    Leak found and fixed in AVK. On main, both new tests FAILED: the kit-owned model stayed alive after its card left. `heap` + `leaks --traceTree` showed a retain cycle: SwiftUI `StoredLocation<OwnModelSlot>` -> `OwnModelSlot` -> `EditorModel` -> `EditorModel.onEditCommit` (EditorKit keeps the `.onEditorCommit` callback on the model and never clears it at dismantle) -> closure capturing the view struct -> the same `@State` storage. AgentOneLineField's `{ commit in didCommit(commit) }` held `onSubmit`, which captures PermissionView (owner of the slot). ElicitationTextField's `{ commit in didCommit(commit) }` captured the field itself (owner of `_ownModel`).
    Fix: `AgentOneLineField` now installs a callback that holds a `SubmitRelay` (kept in the field's own `@State`) weakly. This covers every AgentOneLineField user (PermissionView comment, SessionListView search, ElicitationNumberField). `ElicitationTextField` captures only `returnAction` (`[returnAction]` + static `run(_:for:)`).
    Ruled out: first responder, autorelease pools, unbound scopes, number of run-loop passes (20 fences did not help).
    Not fixed here, for EditorKit: `SingleLineField(model:id:value:format:)` wraps the host commit in `commit(wrapping:committingTo: model)`, which captures `model` and is stored on `model.onEditCommit`, so a value-form model retains itself. ElicitationNumberField's model therefore still leaks. Root fix belongs in EditorKit (clear `model.onEditCommit` at dismantle, or hold the slot callback weakly).
    RED check per the card: no test can reach the private `@State` model, so the hold was a temporary `static var` array in `OwnModelSlot.model(text:)`. Both tests failed with it, and it is reverted.
  timestamp: 2026-10-27T16:09:24.569938+00:00
- actor: claude-code
  id: 01m5z1zew5az5791yz82w5vhw6
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Input/AgentOneLineField.swift (SubmitRelay, weakly held commit callback), Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift (ElicitationTextField commit callback captures only returnAction), Tests/AgentViewKitTests/HumanInTheLoop/PermissionCommentFieldHostedTests.swift (anAnsweredCardTakesTheTypingOfItsCommentFieldOffTheWindowUndoStack), Tests/AgentViewKitTests/Elicitation/ElicitationTextFieldEditingHostedTests.swift (aSubmittedFormTakesTheTypingOfItsFieldOffTheWindowUndoStack + mountInTheDeck). RED on main (real leak), GREEN after the fix, RED again with a temporary held model (reverted). Full `swift test`: 1870 tests / 232 suites and 256 tests / 34 suites passed, 0 failures (7 known issues are the intended checker meta-tests). The SwiftPM `missing creator for mutated node ... mlx-swift_Cmlx.bundle` build warning was already there and comes from a dependency.
    - deviation: the acceptance said "pass on main"; they did not, because AVK leaked. Fixed in AVK per the dispatch instruction.
    - next: /review. Follow-up: an EditorKit card for the value-form `SingleLineField` self-cycle (`commit(wrapping:committingTo:)` stored on `model.onEditCommit`).
  timestamp: 2026-10-27T16:09:31.269872+00:00
- actor: claude-code
  id: 01m5z2esy57derafkyv1vp0n90
  text: |-
    ### test — green
    - evidence: `swift test` run twice (flakiness check for deallocation-timing tests): run 1 and run 2 each "1870 tests in 232 suites passed with 7 known issues", 0 failures, 0 skipped. `Scripts/test-examples.sh AgentViewKitDemo`: 10 UI tests, 0 failures, "The example gate passed."
    - warnings: none in repo code. Only toolchain noise: SwiftPM "missing creator for mutated node ... mlx-swift_Cmlx.bundle" and xcodebuild appintentsmetadataprocessor "Metadata extraction skipped". The 7 known issues are the expected count.
    - no source or test files were edited; no snapshots re-recorded; AgentViewKitTestSupport untouched; nothing committed.
    - next: review
  timestamp: 2026-10-27T16:17:54.117500+00:00
position_column: doing
position_ordinal: '8680'
title: 'AVK: pin that a field the kit tears down leaves no stale entry on the window undo stack (EditorKit ^1gab15j)'
---
## Why

Since EditorKit ^1gab15j (6bc467c), an editor's entries stay on the window undo stack while its `EditorModel` is alive, and leave only when the model is released. Unmount no longer removes them. Found during ^w4vewxn.

AVK's own fields keep their models in `@State` `OwnModelSlot`s (`PermissionView.commentModel`, `SessionListView.searchModel`, `ElicitationTextField` with no supplied model). So today the entries leave when the view and its `@State` go away. But no AVK test pins that. If a future change keeps such a model alive past its view (a cache, a model on the session, a slot lifted to a parent), ⌘Z would undo typing in a field that is gone, and no test would fail.

## What to do

- [x] Add a hosted test: type in the comment field of a `PermissionView`, answer the request so that the card leaves the window, let the stack settle (`waitUntilIdle` / one main run loop pass), and expect `!stack.canUndo` and `!stack.canRedo`.
- [x] Do the same for an elicitation text field (submit the form) with no supplied model.
- [x] Document on each test that a host-supplied model keeps its entries for as long as the host keeps it (EditorKit rule), so the check applies only to the kit-owned slot.

## Acceptance

- The new tests fail if the kit-owned model of a removed field is kept alive (verify RED by holding the model in the test), and pass on main. #avk-8 #cross-repo