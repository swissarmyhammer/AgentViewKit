---
assignees:
- claude-code
depends_on:
- 01M5KVZMEZNJ8SKF8E269G4A69
position_column: todo
position_ordinal: ab80
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