---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5kwk1f9fjvzm805zhfp0z16
  text: |-
    Research (implement step):
    - Public StockPromptEditor surface: `public struct StockPromptEditor`, `StockPromptEditor.identifier` ("prompt-editor"), `StockPromptEditor.init(context:)`, and the short init `extension PromptInputView where Editor == StockPromptEditor, Accessory == DefaultPromptAccessory { init(text:attachments:onSubmit:) }`. DefaultThreadComposer is built on that short init. No enum case or option selects the editor; the demo uses `PromptInputView(text:) {}` (short init); no demo setting picks an editor.
    - EditorKitPromptEditor borrows `StockPromptEditor.minimumHeight/maximumHeight/returnAction`; they move into EditorKitPromptEditor.
    - Focus target and `DeckFocusMove.promptEditor` use `StockPromptEditor.identifier`. Testudo constraint 3 wants `prompt-editor` kept, so `EditorKitPromptEditor.identifier` takes the value "prompt-editor" (was "editorkit-prompt-editor").
    - Constraint 2 finding: bare `EditorView` (an NSViewRepresentable) applies NO `.commandScope`. Only `EditorContributor` adds `.commandScope(.editor(id))`. EditorKitPromptEditor uses bare EditorView, so a jump/focus that lands on the host's composer scope reaches the scope's own content. Test to be added.
    - EditorKit's `editorAccessibilityIdentifier(_:)` (sets the id on the hosted NSView) is internal to EditorSwiftUI; the kit uses SwiftUI `.accessibilityIdentifier` on the representable, which the AX tree reads.
    - `TextEditor(text: .constant(""))` in HostedViewHarnessTextViewsTests is TextEditor<String>, not AttributedString.
  timestamp: 2026-10-23T08:03:42.697775+00:00
- actor: claude-code
  id: 01m5kyssmg62gdtsv27gwzaa71
  text: |-
    Implementation notes (implement step):
    - StockPromptEditor.swift deleted; the short `PromptInputView(text:attachments:onSubmit:)` init is now `where Editor == EditorKitPromptEditor`; DefaultThreadComposer() unchanged in signature, now EditorKit-backed. `EditorKitPromptEditor.identifier` is now "prompt-editor" (was "editorkit-prompt-editor"); minimumHeight/maximumHeight/returnAction moved into EditorKitPromptEditor. Focus target + DeckFocusMove.promptEditor use EditorKitPromptEditor.identifier.
    - ComposerWindowUndoHostedTests: ComposerUndoEditor enum, stock cases and withKnownIssue removed. New redo test `theWindowRedoGivesTheUndoneTypingBack` (edit.redo until !canRedo -> text view and model show "Hello"): PASSED AT ONCE on EditorKit's window stack (written first, ran before any production change).
    - BLOCKER (Testudo constraints 2 and 3), measured with new DefaultThreadComposerHostedTests against the pinned EditorKit 7c043ad:
      (3) The SwiftUI `.accessibilityIdentifier("prompt-editor")` on the EditorView representable reaches NO accessibility element: `harness.element(identifier: "prompt-editor")` is nil (also breaks ThreadFloatingControlsHostedTests.theDefaultComposerIsInTheFloatingControlsOfTheThread, PromptInputViewHostedTests.theDefaultComposerMountsTheEditorAndTheSubmitButton, EditorKitPromptEditorHostedTests.theEditorMountsInTheComposerSlot). EditorKit's own fix for this, `editorAccessibilityIdentifier(_:)`, is internal to EditorSwiftUI (also internal on EditorKit main bc599af), and it names the lane host view, not the EditorInputTextView. So an XCUITest `typeText` into "prompt-editor" has no element to find.
      (2) EditorView adds NO `.commandScope` of its own (only EditorContributor does). Still, a nav move or a jump that lands on a host `.commandScope(segment:)` around DefaultThreadComposer() makes the scope's GeometryProbeView beacon the first responder, not the text view: the probe picks the focusable that holds the beacon CENTER (GeometryProbeView.contentResponder), and the EditorInputTextView is only one line tall (432x16) under `.editorSizingMode(.intrinsic)`, so the composer's center misses it. The stock TextEditor passed the same test (its text view filled the 36pt editor frame).
      Both need an EditorKit change (public identifier API on the input text view; text view filling its frame or a probe pick that does not depend on the center), which this card cannot pull (no `swift package update`).
  timestamp: 2026-10-23T08:42:21.200707+00:00
- actor: claude-code
  id: 01m5m1naepwvkf1e2ywdvstrvx
  text: |-
    BLOCKER confirmed end to end (not only in the harness):
    - `Scripts/test-examples.sh`: build step `** BUILD SUCCEEDED **`; UI tests: 4 of 5 FAIL, every ACPTabEndToEndTests case at ACPTabEndToEndTests.swift:77 "The composer has no editor." (`app.element("prompt-editor")` never exists), so the stock ^bc6fapz hit-point failure is now superseded by a missing element; GalleryTabEndToEndTests passes. XCUITest cannot find "prompt-editor" on the EditorKit composer.
    - `swift test`: 1680 tests in 207 suites, 6 failing tests (all the identifier/focus blocker): PromptInputViewHostedTests.theDefaultComposerMountsTheEditorAndTheSubmitButton, EditorKitPromptEditorHostedTests.theEditorMountsInTheComposerSlot, ThreadFloatingControlsHostedTests.theDefaultComposerIsInTheFloatingControlsOfTheThread, DefaultThreadComposerHostedTests.theEditorThatTakesTypingCarriesThePromptEditorIdentifier, DefaultThreadComposerHostedTests.aFocusOnTheHostScopeOfTheComposerGoesIntoTheTextOfTheEditor(.nav,.jump). Everything else green (HostedSnapshotTests re-recorded for the new editor: thread-*, bottom-bar-buttons-*, composer-idle-*, composer-running-*).
    - Found and fixed on the way (in scope, the swap exposed it): EditorKitPromptEditor lost an external prompt write that came while the commit of the previous taken text was still in the commit stream (SpeechInputButtonHostedTests.theTranscriptGoesAfterTheTextOfTheComposer hung forever: text stuck at "Fix the"). didCommit now ignores the commit of a pulled text (origin .externalReload, not undo/redo).
    Decision needed (human): (a) EditorKit change: public `editorAccessibilityIdentifier` that names the EditorInputTextView, plus a text view that fills its frame (or a GeometryProbeView pick that does not need the beacon center inside the one-line text view); then bump the EditorKit pin here; or (b) allow a kit-side workaround: a background NSViewRepresentable in EditorKitPromptEditor that walks the hosted view tree to the EditorInputTextView, sets its identifier, and (for focus) cannot be fixed kit-side without (a).
  timestamp: 2026-10-23T09:32:20.310343+00:00
- actor: claude-code
  id: 01m5m1ng1qyccv7nc91ppq0qz1
  text: |-
    ### implement — stuck
    - evidence: `swift test` 1680 tests / 207 suites, 6 failing (identifier + focus blocker, see previous comment); `Scripts/test-examples.sh` BUILD SUCCEEDED, UI tests 4/5 fail "The composer has no editor." Removed public API: `StockPromptEditor` (struct, `init(context:)`, `identifier`); short init `PromptInputView.init(text:attachments:onSubmit:)` now constrained `Editor == EditorKitPromptEditor` (was `StockPromptEditor`); `EditorKitPromptEditor.identifier` value "editorkit-prompt-editor" -> "prompt-editor". Redo test for EditorKit passed at once. Nothing committed.
    - next: human decision on EditorKit API (identifier on the input text view; text view that fills its frame / probe pick) vs a kit-side view-tree workaround; Testudo constraints 2 and 3 are not met until then.
  timestamp: 2026-10-23T09:32:26.039741+00:00
- actor: claude-code
  id: 01m5m1q0rtv45mspwg1cjzf26d
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the work is parked on local branch `wip/69g4a69-drop-stock-editor` (b72013a, NOT pushed; main is clean). It removes StockPromptEditor (type, init(context:), identifier); the short PromptInputView init → EditorKitPromptEditor; EditorKitPromptEditor.identifier → "prompt-editor"; DefaultThreadComposer() unchanged; fixes a lost external write (dictation echo); redo test passes at once; 16 snapshots re-recorded.
    - 6 tests red, both EditorKit gaps: (1) `editorAccessibilityIdentifier` is internal and labels the outer view, so "prompt-editor" never reaches the text view (harness + XCUITest can't find it; demo UI 1/5); (2) a jump or nav onto the host scope around DefaultThreadComposer() focuses the scope, not the text view: EditorKit picks the focusable view under the scope centre, and the one-line text view (432×16) isn't there.
    - test, commit, review: not run
    - next: EditorKit gives a public identifier on the text view, and a focus pick that finds the editor in a host scope (per the user rule, jump support lives fully in EditorKit). Asked editorkit-28. Then check out the WIP branch onto main, bump EditorKit, and rerun.
  timestamp: 2026-10-23T09:33:15.930883+00:00
- actor: claude-code
  id: 01m5m1rh88gp8pffbsw1v9dngk
  text: |-
    Blockers are tracked in EditorKit, queued after ^z3fws0w:
    - ^kek5v80 (01M5M1QZ84SA1ESJ8P3KEK5V80): a public way to set the accessibility identifier on the TEXT VIEW inside EditorView and SingleLineField (macOS; the iOS path compiles). The API name comes with the SHA.
    - ^qs0g2n (01M5M1R48CQVPCP3D5K8QS0G2N): a landed jump, nav or drill-in on a scope whose own content (excluding nested scopes) holds EXACTLY ONE focusable text view focuses that text view, wherever it sits. With zero or several, it behaves as today. No host modifier is needed.
    When both SHAs arrive: check out `wip/69g4a69-drop-stock-editor` onto main, `swift package update EditorKit`, use the identifier API in EditorKitPromptEditor, and rerun the 6 red tests and the demo UI suite.
  timestamp: 2026-10-23T09:34:05.576786+00:00
- actor: claude-code
  id: 01m5m4bcz64p3dt3byb1497y6v
  text: 'Blocker 1 of 2 LANDED: EditorKit d4c767f (^kek5v80, feature 6d4a822). `.editorTextAccessibilityIdentifier(_ identifier: String)` on EditorSlotComposing (EditorView, SingleLineField, EditorContributor) lands the id on the NSTextView only. In EditorKitPromptEditor, add `.editorTextAccessibilityIdentifier(Self.identifier)` before `.frame(...)` and REMOVE the SwiftUI `.accessibilityIdentifier(Self.identifier)` there, so XCUITest doesn''t match two. iOS gap: EditorKit ^t9a7jgs. Still waiting on blocker 2, ^qs0g2n (focus on the only text view of a scope).'
  timestamp: 2026-10-23T10:19:20.934545+00:00
- actor: claude-code
  id: 01m5m60vgmcrk5t7hectgzxtzs
  text: |-
    UNBLOCKED: EditorKit f913e78 (^8qs0g2n, which editorkit-28 earlier mistyped as ^qs0g2n; feature commit 4a92ce0) together with d4c767f (`.editorTextAccessibilityIdentifier`, ^kek5v80). A landed jump, nav or drill-in on a scope focuses its ONE EditorKit text view tagged with the scope's path (`\.commandScopePath`), even when it's off-centre. The rules are centre point, then exact-frame stand-in, then the single tagged text view; with none or several, the beacon keeps focus and draws the ring.
    - The composer EditorView must NOT have its own `.commandScope` between it and the host's composer scope. Then it's tagged with the composer scope's path and gets the focus, and the host's focused path is the composer path.
    To do: `git checkout wip/69g4a69-drop-stock-editor -- .` onto main (or cherry-pick b72013a and drop its .kanban changes, since main's .kanban is newer); `swift package update EditorKit` to f913e78 or later; in EditorKitPromptEditor, add `.editorTextAccessibilityIdentifier(Self.identifier)` before `.frame(...)` and remove the SwiftUI `.accessibilityIdentifier(Self.identifier)`; rerun the 6 red tests and the demo UI suite.
  timestamp: 2026-10-23T10:48:32.532072+00:00
position_column: doing
position_ordinal: '8480'
title: 'Drop StockPromptEditor: EditorKitPromptEditor is the only composer (no TextEditor<AttributedString>)'
---
User decision (2026-10-23, relayed by editorkit-28): "we should never be using TextEditor<AttributedString> at all, if we need a one line editor, we need a one line mode of our editor kit editor."

Why: a plain SwiftUI `TextEditor<AttributedString>` can't redo undone typing on macOS 27.0.1, even without EditorKit, because SwiftUI's write-back after an undo clears redo. EditorKit card ^2x162ch closed with no workaround. `EditorKitPromptEditor` (an EditorView) has full window-stack undo and redo.

Work:
- Remove `StockPromptEditor` (`Sources/AgentViewKit/Input/StockPromptEditor.swift`) and every way to select it: composer slots, options, previews, demo settings and docs. `EditorKitPromptEditor` becomes the only composer. No backward-compatibility shim (ARCHITECTURE.md).
- Remove or adapt the tests that cover StockPromptEditor. That includes the StockPromptEditor cases and the `withKnownIssue` redo limit in `ComposerWindowUndoHostedTests` (^m1wgq3k). Keep the EditorKitPromptEditor cases, and add a real redo assertion for it (⇧⌘Z / `edit.redo` re-applies undone typing).
- If the public API names the stock editor (a public type or an enum case), remove it, and note the break for hosts. testudoapp-2c must know before the push.
- Search Sources, Tests, Examples and the docs for `TextEditor` and remove every other `TextEditor<AttributedString>` use too.
- Full `swift test` green; the demo builds. #avk-7

## Constraints from Testudo (coordinator, 2026-10-23)
- [ ] KEEP the public `DefaultThreadComposer()` initializer unchanged (Testudo passes it in AgentThreadView's `composer:` slot, inside its own `.commandScope(segment: composer)`), now backed by EditorKitPromptEditor. Do not remove or rename it.
- [ ] Jump focus: the default composer has no command scope of its own today, so a jump that lands on the host's composer scope focuses the text view. Check whether EditorKitPromptEditor/EditorView adds its own `.commandScope`; if it does, a jump would land on that inner scope and not in the text. Add a hosted test: a host wraps `DefaultThreadComposer()` in `.commandScope(segment:)`, a jump or focus request lands on that scope, and first responder is the editor's text view. Report the finding.
- [ ] Keep the `prompt-editor` accessibility identifier on the element that takes typing (the EditorKit text view), and keep `prompt-submit` on the Send button. XCUITest `typeText` into it must work. If the demo UI suite covers typing into the composer, confirm it still passes, apart from the known ^bc6fapz hit-point failure, and say so explicitly.