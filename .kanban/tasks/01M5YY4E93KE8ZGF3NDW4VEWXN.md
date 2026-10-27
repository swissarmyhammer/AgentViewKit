---
assignees:
- claude-code
position_column: todo
position_ordinal: a780
title: 'AVK: move to EditorKit main 79f043e: depend on the EditorTestSupport product, and update the window-undo tests for EditorKit ^1gab15j'
---
## Why

EditorKit main is at 79f043e (editorkit-a9, 2026-10-27). It brings two changes:
- ^84ygyk0 (1731354): `EditorTestSupport` is now a library product. AVK needs it for EditorKit's hit-test helpers (`accessibilityHitTest(at:window:)`, `accessibilityHitTest(atCenterOfScopeAt:in:window:)`, `expectLeafControlWinsTheHitTest(_:layout:control:)`), which ^j4vnh1r needs. It's also needed for the helper move (EditorKit ^1b4z2mv, then AVK ^t3eq162). `EditorCommandsTestSupport` was already a product.
- ^1gab15j (6bc467c, "fix(undo)!"): an editor's entries stay on the window undo stack while its EditorModel is alive, even after its views unmount. They leave once the model is released. The public API is unchanged.

## What to do

- [ ] `swift package update EditorKit` (Package.resolved is git-ignored). It must resolve to 79f043e or later.
- [ ] Add `.product(name: "EditorTestSupport", package: "EditorKit")` to the AVK test targets that need it. Today that's at least AgentViewKitTests. If AgentViewKitTestSupport and EditorTestSupport declare the same names, resolve the ambiguity at the call sites, with module-qualified names or by importing only where needed. Do NOT edit or delete files in `Sources/AgentViewKitTestSupport/`; EditorKit ^1b4z2mv / AVK ^t3eq162 handles that.
- [ ] Run the full `swift test`. Fix every test that assumed an editor's undo entries leave the window stack when the editor unmounts. Candidates: `ComposerWindowUndoHostedTests`:187, `SessionListSearchFieldHostedTests`:157, `PermissionCommentFieldHostedTests`:198, `ElicitationTextFieldEditingHostedTests`:148, `ElicitationNumberFieldEditingHostedTests`:108, `Helpers/WindowUndoChecks.swift`:38. For each one, decide what the test really protects:
  - If it's "no stale entries once the model is gone", release the model and keep the check.
  - If it's AVK behaviour that the new EditorKit rule changes, write the new expected behaviour and say why in a card comment.
- [ ] Any other failure from the new EditorKit: fix it in AVK if it's AVK's, or write a repro on this card and report it to editorkit-a9 if it's EditorKit's.
- [ ] Build the demo: regenerate with `generate_xcodeproj.rb`, then run the xcodebuild command.

## Acceptance

- AVK resolves EditorKit 79f043e or later, and AgentViewKitTests can `import EditorTestSupport`.
- The full `swift test` is green with the same known issues, and the demo builds. #avk-8 #cross-repo