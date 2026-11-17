---
assignees:
- claude-code
depends_on:
- 01M7NQMD8YCFC8F7TC11Y5EC6G
position_column: todo
position_ordinal: 8b80
title: 'AVK-15.4: Composer mention marks (resolved, unresolved, ambiguous)'
---
D199 (h). Brief item 4.

Do:
- Add `.composerMentionMarks { text -> [ComposerMentionMark] }`. A mark is a range and a state: `.resolved(link:)` draws a chip; `.unresolved(reason:)` draws the EditorKit "not found" mark (dotted red underline with a help text); `.ambiguous(reason:)` draws the same mark with its reason as the help text.
- The host calls its resolver for each `@` token that is not a file chip.
- A `.unresolved` mark sends nothing extra on submit.

Depends on the EditorKit "not found" mark (ek-brief-at-sessions.md). Ask editorkit for the task id. Fallback if it is late: `.editorOverlay`.

Tests (TDD, unit): the marks map to the decorations; a resolved mark gives a mention with its link in the ComposerSubmission. Hosted test (compile only): a `.unresolved` mark draws the mark.

#avk-15