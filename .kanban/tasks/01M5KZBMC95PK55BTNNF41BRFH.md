---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5m8kf54k4t20hhbnsx5avsf
  text: |-
    Research:
    - The draft lives in `DefaultThreadComposer` as `@State private var draft` (Sources/AgentViewKit/Input/DefaultThreadComposer.swift), so a rebuild of AgentThreadView under a new identity drops it.
    - The "restored draft" path of ^m1wgq3k is `EditorKitPromptEditor.body`: `session.model(startingWith: String(context.text.wrappedValue.characters))` seeds the EditorEngine with the binding's text, so a non-empty binding at mount restores with NO undo entry. Building on it only needs the binding to read a draft that outlives the view.
    - `SessionModel` is a `@MainActor @Observable public final class` of FoundationModelsACPClient (external package), so the kit cannot add a stored property to it. The draft goes in a kit-owned per-session store keyed by the model object (weak, so a draft dies with its model).
    - The seeded EditorEngine puts the caret at offset 0 (EditorEngine.init seeds `.cursor(utf8Offset: 0)`), so a restored draft would start with the caret at the start; a selection-only transaction records nothing in the RevisionLog (§19#8), so moving the caret to the end should add no undo entry.
    - Send clears through `PromptInputView.takeInput` (`text = AttributedString()` via the binding), so a store behind the binding is cleared by Send with no extra code; ⌘Z after Send commits an undo transaction that `didCommit` pushes back into the binding (isPull excludes undo/redo), so the undo writes the draft back.
    - ^32a58sq rebuild host: `ScopeRebuildHost` in Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift (`AgentThreadView(session:).id(model.generation)`).
  timestamp: 2026-10-23T11:33:39.620667+00:00
- actor: claude-code
  id: 01m5m94hx4z042qn16xdxzk7m3
  text: |-
    Implementation landed (not committed):
    - New Sources/AgentViewKit/Input/PromptDraftStore.swift: `@MainActor @Observable final class PromptDraft { var text: AttributedString }` and `@MainActor final class PromptDraftStore` (`static let shared`, `draft(for: SessionModel) -> PromptDraft`), keyed by ObjectIdentifier with a weak ref to the model; an entry counts only while it still holds that model, and gone models are dropped when a new draft is added. Both internal: NO public API change. `DefaultThreadComposer()` keeps its signature.
    - DefaultThreadComposer: `@State draft` replaced by a binding over `PromptDraftStore.shared.draft(for: session)` (session from `\.sessionModel`, which AgentThreadView sets on the slot); with no session model it falls back to `@State ownDraft`. Per keystroke the only work is the binding set `draft.text = $0`; no timer, no polling.
    - EditorKitPromptEditor / PromptEditorSession.model(startingWith:): a new model now dispatches a selection-only transaction (identity changes, caret at documentEnd), so a restored draft has the caret at its end. Selection-only adds no undo entry: ComposerWindowUndoHostedTests (incl. the ^m1wgq3k mount-with-draft case) stay green.
    - Decision: ⌘Z after Send ALSO writes the draft back. Why: the store is the composer's text binding; the undo commit goes through didCommit -> push -> binding, so the draft always equals what the composer shows. Not writing it back would need a special case and would make a rebuild after ⌘Z drop the restored prompt the person can see. Tested by theUndoAfterSendGivesThePromptBackToTheDraft.
    - Tests/PackageStructureTests/RemovedVocabularyTests.swift: added "PromptDraft" to `allowedObservableClasses` (the gate lists each kit @Observable class with the view state it holds); the draft is composer view state, not a value SessionModel holds.
    - Behavior notes for the next agent: two windows showing the SAME session model now share one draft (typing in one mirrors into the other through the binding). A thread view that switches session in place shows the other session's draft by `replaceAll` on the editor model; whether that switch adds a window undo entry is not tested.
    - RED evidence: the first build of ComposerDraftHostedTests failed only with "cannot find 'PromptDraftStore' in scope" (the tests wait on the store, so a pre-change behavioural run would hang on `ObservationWait.until`). After the store landed, aRebuiltThreadViewShowsTheTypedDraftWithTheCaretAtItsEnd failed on the selectedRange expectation (caret at 0) until the caret move landed.
  timestamp: 2026-10-23T11:42:59.492830+00:00
- actor: claude-code
  id: 01m5m94px2v4qqm9tc4cjrphr8
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Input/PromptDraftStore.swift (new), Sources/AgentViewKit/Input/DefaultThreadComposer.swift, Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Tests/AgentViewKitTests/Input/ComposerDraftHostedTests.swift (new, 4 hosted tests), Tests/PackageStructureTests/RemovedVocabularyTests.swift. Draft lives in PromptDraftStore.shared, one PromptDraft per SessionModel. RED: build failed "cannot find 'PromptDraftStore'", then the caret expectation failed; GREEN 4/4. ComposerWindowUndoHostedTests green. Full `swift test`: 1 + 227 + 1697 tests passed (3 known issues are the pre-existing withKnownIssue self-tests), 0 failures. Public API: none changed.
    - next: /review. Then send testudoapp-2c the SHA after commit.
  timestamp: 2026-10-23T11:43:04.610638+00:00
- actor: claude-code
  id: 01m5m9drrzxmzy6kpec1n6acww
  text: |-
    ### test — green
    - evidence: `swift test` run twice back to back with the three changed Sources files touched first. Run 1: 1697 tests in 208 suites passed, 3 known issues (plus 227 tests in 30 suites and 1 test in 1 suite in the other runners), 0 failures, 0 skipped. Run 2: identical, 1697 tests in 208 suites passed, 3 known issues. ComposerDraftHostedTests passed in both runs. No compiler warnings from project code; only the known SwiftPM mlx-swift "missing creator" notice.
    - isolation: each ComposerDraftHostedTests test opens its own ScriptedSession (own SessionModel identity, so its own weakly keyed draft), the suite is serialized and hosted serially, and Send clears the draft, so no draft leaks between tests. No flakiness seen; no code changed.
    - next: review / commit
  timestamp: 2026-10-23T11:48:01.439944+00:00
depends_on:
- 01M5KVZMEZNJ8SKF8E269G4A69
position_column: doing
position_ordinal: '8380'
title: The composer draft survives a remount of the thread view for the same session
---
Reported by testudoapp-2c (Testudo card ^ad0cgnc, 2026-10-23); it reproduces on Testudo main, independent of AVK's recent changes.

Repro: Testudo's Swap Chat and View moves the AgentThreadView of the SAME session to the other NavigationSplitView column. SwiftUI rebuilds the view, and the typed but unsent prompt is gone, because the draft lives in the composer's view state (@State).

Wanted: the draft survives a remount of the thread view for the same session. Keep it in a model that outlives the view (the session model, or a per-session draft store owned by the kit), not in @State. AVK may already have a draft-restore path: ^m1wgq3k fixed the undo entry from "mounting with a restored draft", so find where that draft comes from and make the composer write it back as the user types.

Constraints:
- After ^69g4a69, EditorKitPromptEditor is the only composer; cover it, through `DefaultThreadComposer()`.
- Restoring the draft on mount adds NO undo entry (the ^m1wgq3k test stays green).
- Send clears the draft in the store as well as in the view, and ⌘Z after Send still restores the prompt (^m1wgq3k). Decide and test whether that undo also restores the stored draft.
- Different sessions keep separate drafts.
- No timers or polling. Write the draft on change, and keep the write cheap: no work per keystroke beyond setting a value.

Tests (hosted):
- type into the composer, rebuild the thread view under a new identity for the same session (as in the ^32a58sq test), and the composer shows the full typed text, with the caret at the end if it can be observed;
- a different session's thread view doesn't show it;
- after Send, a rebuild shows an empty composer.
Full `swift test` green. Send testudoapp-2c the SHA: Testudo's `testComposerKeepsTheFocusAfterSwapChatAndView` will then expect the full pre-swap prompt. #avk-7 #bug #testudo-request