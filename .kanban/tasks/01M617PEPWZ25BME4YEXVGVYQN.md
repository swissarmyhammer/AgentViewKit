---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m617pvqgye7yd6rhbpe8cfj2
  text: 'Don''t write AVK''s own scanner. KanbanViewKit already has one (TextInputControlScanner and TextInputControlTests: skips comments and strings, fixtures for each control). I''ve asked editorkit-a9 to move it into EditorTestSupport as the one shared copy, with an allow list as a parameter. This card waits for that SHA, then calls it from PackageStructureTests with AVK''s allow list: PromptCaretProbe.swift (finds EditorKit''s text view) and AgentViewKitTestSupport (harness type checks).'
  timestamp: 2026-10-28T12:28:09.840352+00:00
- actor: claude-code
  id: 01m64p73j75kw1f2eqv5h0qeqq
  text: |-
    ### implement — changed
    - evidence: commit dc5e52b on wt/text-input-scan (worktree AgentViewKit-wt/text-input-scan), EditorKit resolved at 86bad82 (descends from afda494). New Tests/PackageStructureTests/TextInputControlScanTests.swift runs EditorTestSupport's TextInputControlScanner over Sources/ + Examples/. RED first: 3 hits, all in PromptCaretProbe.swift (the `-> NSTextView?` return types and `as? NSTextView`). GREEN after allow-listing that one file with its reason. No real violation in the kit, the demo support or the demo.
    - Differs from the card text: (1) the AgentViewKitTestSupport allow-list entry was left out. HostedViewHarness+TextViews.swift was deleted in 7c1535e (adopt EditorTestSupport), and the EK scanner reports a stale entry as a failure. (2) The scanner flags casts too, so a cast is allowed per file by the allow list, not per line. (3) The self-test for each forbidden form lives in EditorKit's TextInputControlScannerTests with the shared scanner, and AVK keeps no copy.
    - Migration: EK's new PackageFiles made the name ambiguous in LightAndDarkOnlyTests, AnnouncementPathScanTests and NoSwiftUIListTests. These now use `PackageFiles()` from EditorTestSupport and no longer import PackageFileSupport. No AVK code used the removed repository* helpers or the views that moved to EditorSwiftUI.
    - Docs: plan.md §4.1 "Text input" bullet and an ARCHITECTURE.md Style bullet (^tx59fk had already run).
    - Tests: `swift test --filter "^PackageStructureTests\."`: 298 tests in 43 suites passed. Only warning: mlx-swift dependency. No UI, snapshot or capture tests run (UI pause).
    - next: /review
  timestamp: 2026-10-29T20:39:25.511984+00:00
- actor: claude-code
  id: 01m64q4pfv0z794805dav3mgc1
  text: |-
    ### implement — changed (follow-up: no AVK PackageFiles copy)
    - evidence: commit e89e6cb on wt/text-input-scan, 58 files changed (+230 −593). Deleted Sources/PackageFileSupport/PackageFiles.swift and Tests/PackageStructureTests/PackageFilesTests.swift (13 tests that EK now owns). About 52 test files moved to EK's `PackageFiles()`, `PackageFiles(root:).swiftFileTexts(under:)` and `swiftFiles(under:)`. Where the old throwing `swiftFiles(in:)` was the only thing that failed on a missing folder, an isEmpty check was added.
    - Kept in AVK:
      - `MarkdownTable`, in the PackageFileSupport target, which still exists. It reads the decision-record tables and has no EK equivalent.
      - `StyleGuideLinkTests.visibleFiles(below:withExtensions:)`, a suite-local listing that skips hidden items. EK has no such helper. It is generic, so it should move into EditorTestSupport.
    - NoEditorKitDuplicateTests now scans Sources/AgentViewKitTestSupport, Sources/PackageFileSupport and Tests. It found one more copy, Tests/AgentViewKitTests/Theme/UIFamilyTheme.swift. That file is deleted, and its users now use EK's UIFamilyTheme: CitationProseTests and FontRoleHostedTests. AgentViewKitStyleTests' StatusBarTests already used EK's.
    - Tests:
      - PackageStructureTests: 285 tests in 42 suites passed.
      - CitationProseTests: 13 passed.
      - MathEngineDecision, AttachmentResolution, PermissionPresentation and StyleTokenGolden: 38 tests in 4 suites passed.
      - The changed hosted suites were built but not run, because the UI pause is still on.
      - The only warning was from mlx-swift.
    - next: /review
  timestamp: 2026-10-29T20:55:35.163970+00:00
position_column: todo
position_ordinal: ac80
title: 'A source-scan test holds the style.md "Text input" rule: every typing surface is an EditorKit editor'
---
EditorKit/style.md gained a "Text input" section at EditorKit 107e869 (user request). Every place where the user types uses an EditorKit editor: EditorView for multi-line text, SingleLineField for one line. Not allowed in the kit, the demo support or the demo: SwiftUI TextField / TextEditor / SecureField, AppKit NSTextField / NSTextView, UIKit UITextField / UITextView, and `.searchable`.

AVK already complies. A scan of Sources and Examples finds no input view built from those types. The only mentions are read-only lookups of EditorKit's own text view: PromptCaretProbe.swift (`as? NSTextView`, to find the caret behind the probe) and AgentViewKitTestSupport/HostedViewHarness+TextViews.swift (type checks). But no test stops a violation from coming back.

## Work
- [ ] A PackageStructureTests test scans Sources/AgentViewKit, the demo support and Examples. It forbids constructing or declaring those types: `TextField(`, `TextEditor(`, `SecureField(`, `NSTextField(`, `NSTextView(`, `UITextField(`, `UITextView(`, a subclass of any of them, and `.searchable(`. Match as whole-word tokens, so qualified names and extra whitespace are caught too (see ContentTilePaddingTests' WordPattern).
- [ ] It permits only type casts and lookups (`as? NSTextView`, `case let x as NSTextField`) and lists each permitted file with its reason: PromptCaretProbe (finds EditorKit's text view) and AgentViewKitTestSupport (the test harness).
- [ ] A self-test proves the scan catches each forbidden form and leaves a cast alone
- [ ] plan.md and ARCHITECTURE.md cite the rule (fold this into ^tx59fk if that card hasn't run yet)
- [ ] `swift test` is green