---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7qsfbt8j74kc72nvvprf29h
  text: 'editorkit-7a accepted the request as EditorKit task 01M7QSEX39Y5CY42FDJDMJJ0FJ. Planned: (1) with `.editorTextMenu(.ancestor)`, the EditorView writes the code block of the right click into `context.codeBlock` of its enclosing command scope before the ancestor menu opens, and clears it when the click is not in a code block, so `copyCodeBlock` works as it is; (2) a public pure EditorModel query gives the code block at an offset and at the caret. Blocked until editorkit-7a sends the commit and the exact API.'
  timestamp: 2026-11-18T16:57:37.864904+00:00
- actor: claude-code
  id: 01m7qy514c619bg3dq377r0e31
  text: |-
    Not blocked now. The EditorKit hook is on origin/main, head 8a5d8bae (feature 03172d8e, refactor de93daee, EditorKit task ^dmjj0fj).
    - With `.editorTextMenu(.ancestor)`, before the ancestor menu opens, the EditorView writes `context.codeBlock` (EditorCodeBlockContextValue) into the context of its enclosing command scope. A right click outside a code block clears it. The value goes when the view leaves the scope. The `copyCodeBlock` gate `EditorCodeBlockScope.isInside(context)` and `context.codeBlock?.text` work with no change.
    - New public API: `EditorModel.codeBlockContext(atUTF8Offset:)`, `EditorModel.caretCodeBlockContext`, and `ScopeContributionOwner.click` (the fold order is host, scope, click, mount).
    - Open risk (editorkit-7a): headless tests prove the context value. They do not prove that the SwiftUI item menu shows Copy Code Block on the FIRST right click. EditorKit follow-up ^fxb0j34 adds a hosted test. If an AVK hosted test sees no Copy Code Block on the first click, tell editorkit-7a.
    Do: update the EditorKit pin, check that the item menu of an answer shows Copy Code Block in a code block (unit test with the new API if possible), and add a hosted test (compile only). Start after the side card task.
  timestamp: 2026-11-18T18:19:22.124397+00:00
position_column: todo
position_ordinal: '80'
title: Copy Code Block in the item menu of an answer needs the code block of the caret at the item path (EditorKit hook)
---
Found in ^pgdhrq7.

Now: `AgentCommandVerb.copyCodeBlock` shows only when `context.codeBlock != nil` (`EditorCodeBlockScope.isInside`). Only `EditorScopeContribution.register` writes `context.codeBlock` (EditorKit `EditorContributor`). AVK shows answers in a plain `EditorView`, which registers no contribution. Thus no real right click shows Copy Code Block: not before ^pgdhrq7 (the code block items of the text view got no code block value), and not after it (`.editorTextMenu(.ancestor)` gives the item menu, which is built at the item path `agentMessage:<key>`).

AVK cannot write the value itself: the code text of a block (`codeText(of:)`, `codeBlockContext(at:under:)`) is private or internal in EditorKit. A copy of that logic in AVK is a duplicate.

Do:
- Ask editorkit-7a for a hook. For example: under `.editorTextMenu(.ancestor)`, an `EditorView` writes the code block of its caret into the context of its enclosing command scope; or a public `EditorModel` method gives the `EditorCodeBlockContextValue` of the caret.
- Use the hook, so a right click in a code block of an answer shows Copy Code Block in the item menu.
- Add a hosted test (compile only) and a unit test if the hook gives a headless check.