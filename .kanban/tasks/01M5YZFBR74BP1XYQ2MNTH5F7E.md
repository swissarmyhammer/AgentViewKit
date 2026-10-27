---
assignees:
- claude-code
position_column: todo
position_ordinal: a980
title: 'AVK: pin that a field the kit tears down leaves no stale entry on the window undo stack (EditorKit ^1gab15j)'
---
## Why

Since EditorKit ^1gab15j (6bc467c), an editor's entries stay on the window undo stack while its `EditorModel` is alive, and leave only when the model is released. Unmount no longer removes them. Found during ^w4vewxn.

AVK's own fields keep their models in `@State` `OwnModelSlot`s (`PermissionView.commentModel`, `SessionListView.searchModel`, `ElicitationTextField` with no supplied model). So today the entries leave when the view and its `@State` go away. But no AVK test pins that. If a future change keeps such a model alive past its view (a cache, a model on the session, a slot lifted to a parent), ⌘Z would undo typing in a field that is gone, and no test would fail.

## What to do

- [ ] Add a hosted test: type in the comment field of a `PermissionView`, answer the request so that the card leaves the window, let the stack settle (`waitUntilIdle` / one main run loop pass), and expect `!stack.canUndo` and `!stack.canRedo`.
- [ ] Do the same for an elicitation text field (submit the form) with no supplied model.
- [ ] Document on each test that a host-supplied model keeps its entries for as long as the host keeps it (EditorKit rule), so the check applies only to the kit-owned slot.

## Acceptance

- The new tests fail if the kit-owned model of a removed field is kept alive (verify RED by holding the model in the test), and pass on main. #avk-8 #cross-repo