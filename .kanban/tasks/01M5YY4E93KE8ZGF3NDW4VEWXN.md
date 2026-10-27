---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5yzfrhq5r23fccw9q2p8yzm
  text: |-
    ### Research (implement)
    - `swift package update EditorKit`: resolved 2906f93 -> 79f043e28b09 (main). The checkout contains 6bc467c (^1gab15j) and 1731354 (^84ygyk0).
    - How ^1gab15j works: `EditorModel.undoSource` now holds the `EditorUndoSource` strongly. `leave()`/holderCount are gone, and `EditorView`/`SingleLineField` dismantle takes nothing off the stack. The source's `isolated deinit` takes the entries off on the next main run loop pass. The source holds the stack weakly.
    - Name clash check, AgentViewKitTestSupport vs EditorTestSupport: no clash. The shared names (`views`, `render`, `accessibilityElements`, `close`, ...) are `HostedViewHarness` members in AVK, and free functions or members of other types with other labels in EK. The only shared top-level name is `UIFamilyTheme`: the test module's own `Tests/AgentViewKitTests/Theme/UIFamilyTheme.swift` and EK's. A module's own declaration shadows the imported one. I proved it with a temporary build: I added `import EditorTestSupport` to SingleLineFieldChecks, FontRoleHostedTests and CitationProseTests (the two `UIFamilyTheme` users), plus a probe file that calls `accessibilityHitTest(at:window:)` beside `import AgentViewKitTestSupport`. `swift build --build-tests` was clean. Then I reverted all of it. No call site needs a module-qualified name today. ^j4vnh1r can `import EditorTestSupport` directly.
    - AVK owns its field models in `@State` `OwnModelSlot`s (`PermissionView.commentModel`, `SessionListView.searchModel`, `ElicitationTextField` with no supplied model). The composer keeps its model in a slot of `EditorKitPromptEditor`. So a field that leaves the window releases its model, and its entries go with it.
  timestamp: 2026-10-27T15:25:59.735349+00:00
- actor: claude-code
  id: 01m5yzg197xy399hsq3bjx4ty0
  text: |-
    ### What each window-undo candidate protects (EditorKit ^1gab15j)
    All six candidates passed unchanged on EK 79f043e. None of them unmounts an editor, so none assumed that unmount removes entries. Each one is kept as written, and none is weakened.
    - `ComposerWindowUndoHostedTests.typingIsUndoneByTheWindowUndo` (`#expect(!thread.stack.canUndo)`): ⌘Z (`edit.undo`) undoes all of the composer's typing, and the typing is the only work on the stack. The composer stays mounted the whole time. Protects: no extra or phantom entry (mount, re-render, focus) is left under the typing. Not affected by the rule.
    - `SessionListSearchFieldHostedTests.theWindowUndoTakesTheTypingOutOfTheSearchField` (`!window.stack.canUndo`): the same for the search field (`SingleLineFieldChecks.typeAndUndoAll`). The field stays mounted. Protects: the field's typing is the only undoable work, and undoing it also restores every row. Not affected.
    - `PermissionCommentFieldHostedTests.theWindowUndoTakesTheTypingOutOfTheCommentField` (`!canUndo`, `canRedo`): the same for the comment field of a pending permission card. The card stays pending and mounted. Protects: the typing round-trips on the window stack. Not affected.
    - `ElicitationTextFieldEditingHostedTests.theWindowUndoTakesTheTypingOutOfTheField` and `ElicitationNumberFieldEditingHostedTests.theWindowUndoTakesTheTypingOutOfTheInput` (`!canUndo`): the same. The number variant also protects that the value the input shows on mount is not an undo entry. The form stays mounted. Not affected.
    - `Helpers/WindowUndoChecks.expectUnavailableOnAnEmptyStack` (`!stack.canUndo`, `!canRedo`, `edit.undo`/`edit.redo` registered but disabled): callers are AttachmentCommandsHostedTests (x2), AgentCommandScopeHostedTests (x2) and ComposerWindowUndoHostedTests.aMountedAndReRenderedComposerLeavesNothingToUndo. Each one checks a freshly mounted window where nobody edited. Protects: a mount or re-render pushes no entry (^yahkhjn), and the window commands are disabled on an empty stack. Not affected.

    No AVK test checked "entries leave when the field unmounts", so no case of "release the model and keep the check" exists today. A regression guard for the kit-owned slots (an answered permission card, a submitted form) is filed as ^nth5f7e (01M5YZFBR74BP1XYQ2MNTH5F7E).
    No other failure came from the new EditorKit, so there is no EditorKit repro to report.
  timestamp: 2026-10-27T15:26:08.679817+00:00
- actor: claude-code
  id: 01m5yzg7pvaa4a8p7djdbakpkc
  text: |-
    ### implement — changed
    - evidence: EditorKit resolved at 79f043e28b09d9a8d72615e2ddf680c5bf40c90b (contains 6bc467c and 1731354). Files: Package.swift (`editorKitTestSupportProducts` now also holds `.product(name: "EditorTestSupport", package: "EditorKit")`, linked by AgentViewKitTests), Tests/PackageStructureTests/ManifestTests.swift (`editorKitTestSupportProducts` set, new `linksTheEditorKitTestSupportProductsToTheKitTestsOnly`, `usesTheTwelve…` became `usesTheThirteenEditorKitProducts`; RED first: 2 issues on the old manifest), Docs/decisions/dependencies.md (EditorKit products row). The ManifestTests change was RED first: 2 failing expectations on the old manifest. `swift test` full: 1866 tests in 232 suites passed, with 7 known issues (the deliberate withKnownIssue self-tests: SnapshotStoreTests 1, HostedLayoutExpectationsTests 1, FontRoleExpectationsTests 5), 0 failures and 0 skipped. Demo: generate_xcodeproj.rb regenerated the project, and the project pin is also 79f043e. The xcodebuild command gave BUILD SUCCEEDED. No file in Sources/AgentViewKitTestSupport/ was touched.
    - next: /review. Follow-up ^nth5f7e filed.
  timestamp: 2026-10-27T15:26:15.259768+00:00
- actor: claude-code
  id: 01m5yzvkhrbn9xsnn0b8pgkac4
  text: |-
    ### test — green
    - evidence: `swift test` — 1866 tests in 232 suites passed, 0 failures, 7 known issues (as expected); `Scripts/test-examples.sh AgentViewKitDemo` — demo BUILD SUCCEEDED, UI tests: 10 executed, 0 failures, TEST SUCCEEDED.
    - warnings: none in repo code. Two tool-emitted lines only: SwiftPM "missing creator for mutated node ... mlx-swift_Cmlx.bundle/Contents/MacOS" (mlx-swift dependency bundle) and appintentsmetadataprocessor "Metadata extraction skipped, no AppIntents.framework dependency found" (Xcode, informational).
    - no files changed in this step; nothing committed.
    - next: review
  timestamp: 2026-10-27T15:32:27.832645+00:00
position_column: doing
position_ordinal: '8580'
title: 'AVK: move to EditorKit main 79f043e: depend on the EditorTestSupport product, and update the window-undo tests for EditorKit ^1gab15j'
---
## Why

EditorKit main is at 79f043e (editorkit-a9, 2026-10-27). It brings two changes:
- ^84ygyk0 (1731354): `EditorTestSupport` is now a library product. AVK needs it for EditorKit's hit-test helpers (`accessibilityHitTest(at:window:)`, `accessibilityHitTest(atCenterOfScopeAt:in:window:)`, `expectLeafControlWinsTheHitTest(_:layout:control:)`), which ^j4vnh1r needs. It's also needed for the helper move (EditorKit ^1b4z2mv, then AVK ^t3eq162). `EditorCommandsTestSupport` was already a product.
- ^1gab15j (6bc467c, "fix(undo)!"): an editor's entries stay on the window undo stack while its EditorModel is alive, even after its views unmount. They leave once the model is released. The public API is unchanged.

## What to do

- [x] `swift package update EditorKit` (Package.resolved is git-ignored). It must resolve to 79f043e or later.
- [x] Add `.product(name: "EditorTestSupport", package: "EditorKit")` to the AVK test targets that need it. Today that's at least AgentViewKitTests. If AgentViewKitTestSupport and EditorTestSupport declare the same names, resolve the ambiguity at the call sites, with module-qualified names or by importing only where needed. Do NOT edit or delete files in `Sources/AgentViewKitTestSupport/`; EditorKit ^1b4z2mv / AVK ^t3eq162 handles that.
- [x] Run the full `swift test`. Fix every test that assumed an editor's undo entries leave the window stack when the editor unmounts. Candidates: `ComposerWindowUndoHostedTests`:187, `SessionListSearchFieldHostedTests`:157, `PermissionCommentFieldHostedTests`:198, `ElicitationTextFieldEditingHostedTests`:148, `ElicitationNumberFieldEditingHostedTests`:108, `Helpers/WindowUndoChecks.swift`:38. For each one, decide what the test really protects:
  - If it's "no stale entries once the model is gone", release the model and keep the check.
  - If it's AVK behaviour that the new EditorKit rule changes, write the new expected behaviour and say why in a card comment.
- [x] Any other failure from the new EditorKit: fix it in AVK if it's AVK's, or write a repro on this card and report it to editorkit-a9 if it's EditorKit's.
- [x] Build the demo: regenerate with `generate_xcodeproj.rb`, then run the xcodebuild command.

## Acceptance

- AVK resolves EditorKit 79f043e or later, and AgentViewKitTests can `import EditorTestSupport`.
- The full `swift test` is green with the same known issues, and the demo builds. #avk-8 #cross-repo