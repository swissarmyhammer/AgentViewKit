---
assignees:
- claude-code
position_column: doing
position_ordinal: '8480'
title: Deduplicate AgentViewKitStyle CompletionRow onto EditorKit's EditorCompletionRow
---
**Blocked** on EK renaming its public `CompletionRow` (EditorComplete, made public in df2ba2a9) to `EditorCompletionRow`. editorkit-b5 sends the SHA. Don't start before then.

AgentViewKitStyle has its own public `CompletionRow`. Both are the row of a completion list, and the user's boundary says single-value controls belong to EK. Check whether EK's type covers AVK's uses (EditorKitPromptEditor.swift:624 and the rest). If it does, delete AVK's and adopt EK's. If it doesn't, write on the card what EK is missing and send it to editorkit-b5.

## Acceptance Criteria
- [ ] AVK has no `CompletionRow` of its own, or the card says why it stays.
- [ ] Before pushing the removal, grep the KVK, SVK and Testudo origin mains for `CompletionRow` from AgentViewKitStyle (KVK's BoardFieldCompletion imports both modules), and wait for each user's SHA.
- [ ] The review gallery shows the prompt completion list, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.