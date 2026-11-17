---
assignees:
- claude-code
depends_on:
- 01M7NQMD8YCFC8F7TC11Y5EC6G
position_column: todo
position_ordinal: 8a80
title: 'AVK-15.3: A composer submit hook that runs before the text clears'
---
D199. Brief item 3.

Now `PromptInputView.submit()` (Input/PromptInputView.swift:302-311) calls `takeInput()` (:346-352), which clears the text, and the host callback `PromptEditorContext.Submit` (PromptEditorContext.swift:14) runs after the send. So the host does not see the mentions. `PromptContent.makeBlocks` (:68-76, :95-113) makes one text block and one block for each attachment. `SessionModel+Requests.swift:51-57` sends no `_meta`.

Do:
- Add `.onComposerSubmit { (ComposerSubmission) async -> ComposerSubmitResult }`. ComposerSubmission has the plain text, the attributed text, and the mentions (token, link or nil, range).
- The hook runs BEFORE `takeInput()` clears the text.
- ComposerSubmitResult can add text blocks (after the text block, in `makeBlocks`), give `_meta` for the prompt, or cancel the send. A cancel keeps the text.
- With no hook, the submit does not change.

Tests (TDD, unit): the hook gets the mentions with their links before the clear; the added blocks follow the text block; `_meta` goes on the prompt request; a cancel sends nothing and keeps the text. Hosted test (compile only) with a fake SessionModel.

#avk-15