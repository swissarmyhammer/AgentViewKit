---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m617pvqgye7yd6rhbpe8cfj2
  text: 'Don''t write AVK''s own scanner. KanbanViewKit already has one (TextInputControlScanner and TextInputControlTests: skips comments and strings, fixtures for each control). I''ve asked editorkit-a9 to move it into EditorTestSupport as the one shared copy, with an allow list as a parameter. This card waits for that SHA, then calls it from PackageStructureTests with AVK''s allow list: PromptCaretProbe.swift (finds EditorKit''s text view) and AgentViewKitTestSupport (harness type checks).'
  timestamp: 2026-10-28T12:28:09.840352+00:00
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