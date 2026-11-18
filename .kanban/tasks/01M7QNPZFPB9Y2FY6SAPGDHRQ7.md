---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Right click on answer text shows the item menu, not the AppKit text menu (D108, D193 f)
---
Bug report from testudoapp-9a (IntegrationTests ChatContextMenuHostedTests in TestudoApp, now a known issue there).

Now: after AVK-9.5 (D185), the text of an agent answer is a read-only EditorKit `EditorView` in `RenderedMarkdownView`. A right click on it gives the AppKit text menu of `EditorInputTextView` (Look Up, Translate, Cut, Copy, Paste, Share…, Font, Spelling and Grammar, Substitutions, Speech). D108 and D193 (f) require the item menu of the message: Copy Message, Inspect, Inspect in New Pane, and Copy for a selection. The AVK hosted tests cover only `EditorLabel`, which is correct.

Cause: `EditorInputTextView` (EditorKit Sources/EditorText/EditorTextView.swift:1165) is a final internal NSTextView, and it does not override `menu(for:)`. Thus AppKit gives its default text menu. `EditorLabelTextView.menu(for:)` (Sources/EditorSwiftUI/EditorLabelTextView.swift:355) already gives the menu of the nearest ancestor. AVK cannot change the text view of `EditorView`.

Blocked: this task waits for an EditorKit hook. On 2026-11-18 I asked editorkit-7a for it: for example, a read-only `EditorView` gives the menu of the nearest ancestor (as `EditorLabel` does), as the default or with a modifier.

Do, when the hook is on EditorKit main:
- Update the EditorKit pin.
- Use the hook in `RenderedMarkdownView` (and each other read-only `EditorView` in a transcript row), so a right click shows the item menu of the row. Keep Copy for a selection, and Copy Code Block in a code block.
- Add a hosted test in IntegrationTests: a right click on answer text gives the item menu (Copy Message, Inspect, Inspect in New Pane), and not the AppKit text menu. Compile it only. Do not run it: the user runs the hosted suites.
- Add a unit test if the hook gives a headless check.
- Run `swift test`. Push, and send the sha to testudoapp-9a.