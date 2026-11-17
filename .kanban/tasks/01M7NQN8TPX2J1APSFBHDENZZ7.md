---
assignees:
- claude-code
depends_on:
- 01M7NQMD8YCFC8F7TC11Y5EC6G
position_column: todo
position_ordinal: 8d80
title: 'AVK-15.6: Insert @ at the caret opens the mention popup'
---
D199. Brief item 6. The Send to Session command is in TestudoApp. AVK only needs a way to insert `@` at the caret and open the popup.

Do:
- Check that the current "insert text at the caret" path of the composer opens the `@` popup.
- If it does not, add `PromptEditorContext.insertAndComplete(_ sigil: String)`.

Tests (TDD, unit): an insert of `@` at the caret starts the completion session of the `@` engine.

#avk-15