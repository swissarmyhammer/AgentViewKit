---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5na637zpnqywm4pmw2m98xy
  text: 'EditorKit ^0apj6a2 landed on main at 69d04fc (code f8ff1bc), as described in section 2: `Theme.editorBackground` and `gutterBackground` are removed; editors and diff header/filler are clear; the terminal default background is clear unless the theme sets `terminal.background`. Resolve EditorKit main at 69d04fc or later for this card.'
  timestamp: 2026-10-23T21:20:33.023829+00:00
position_column: todo
position_ordinal: '80'
title: 'Adopt EditorKit main: onEditorCommit edit sessions (781f2fe, ^a54d840) and transparent-by-default (^0apj6a2)'
---
BLOCKS PUSH. Reported by editorkit-28 (2026-10-23). AVK's `Package.swift` tracks EditorKit `branch: "main"`, and `Package.resolved` is gitignored, so any fresh resolve (CI, Testudo) builds AVK against EditorKit main. EditorKit main already breaks AVK. Our local pin at 8e4d27a only hides the break. Do this card before pushing the local commits of ^8zmkh1a, ^66has33 and ^2sg9taf.

## 1. EditorKit 781f2fe (^a54d840): in-place edit session
EditorKit's changes in 781f2fe (from its commit message):
- `SingleLineField(onSubmit:)` is REMOVED. Build error: `Sources/AgentViewKit/Input/AgentOneLineField.swift:36:61: extra argument 'onSubmit' in call`.
- New: `.onEditorCommit(_:)` with `EditorCommit { reason: EditorCommitReason, text, isChanged }`; reasons include `.submit`, `.submitNow`, `.leave`, `.focusLoss`.
- Esc now COMMITS the edit and drills out. Revert Field is now `editor.revertField` (`EditorRevertFieldCommand`), on Control-Command-Z.
- The placeholder is now the accessibility HINT.
- [ ] `swift package update EditorKit` to main, and read 781f2fe's EditSession.swift and its DocC/tutorial for the intended host pattern.
- [ ] AgentOneLineField: replace `onSubmit:` with `.onEditorCommit` (`.submit`). Callers: PermissionView comment (Return sends reject with the comment), SessionListView search (no submit), ElicitationTextField (Return presses Submit via `elicitationReturnAction`).
- [ ] Esc semantics changed upstream. ^8zmkh1a's tests assert that "Esc takes back the typing since the field got the focus" (PermissionCommentFieldHostedTests, SessionListSearchFieldHostedTests, ElicitationTextFieldEditingHostedTests). Follow EditorKit's new rule: Esc commits and drills out, and revert is Revert Field / ⌃⌘Z. Update those tests to the new behaviour, and add a Revert Field test per field. Esc must still never answer or dismiss a permission request. If the new rule conflicts with an AVK requirement, mark this card stuck; don't pick a side.
- [ ] Placeholder as hint: check the AX label and hint tests of the three fields (label from `.editorTextAccessibilityLabel`, hint now the placeholder).
- [ ] FileReferenceSource and SlashCommandSource still compile against `CompletionTokenOpening` (^fe1dbrc, 7944113); watch the completion tests.

## 2. EditorKit ^0apj6a2: transparent by default (pending push; the user's rule relayed by testudoapp-2c)
- `Theme.editorBackground` and `Theme.gutterBackground` are REMOVED; hosts add `.background(...)`. EditorView, SingleLineField and the iOS input are clear by default; diff header/filler bands and the terminal palette's default background (SGR 49) are clear by default.
- [ ] AVK Sources don't reference the removed members. In Tests: `DistinctRolesTheme.swift` 55/61/111/114 (extra members, still compile); `EditorThemeViewsTests`, `TerminalViewHostedTests`, `ContentFillTests` mention them. Fix them.
- [ ] `EditorBlockChrome.swift:49-52` `TerminalBlockFrame` fills `palette[.background]`, which becomes clear unless the theme sets `terminal.background`. Testudo is asking the user whether the terminal fill stays. Don't change AVK's terminal code until that answer is relayed; record the snapshot effect.
- [ ] Re-record only the snapshots that change (code blocks, composer, terminal, diff), and list each one with what changed.
- [ ] This answers ^m231ph5 (white fill of the code block text area): note it there.

Acceptance: AVK builds and `swift test` is green against EditorKit main as resolved fresh; the demo builds; UI tests only under the shared lock. #avk-8 #cross-repo #bug