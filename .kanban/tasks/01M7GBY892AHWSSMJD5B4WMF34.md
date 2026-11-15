---
assignees:
- claude-code
position_column: doing
position_ordinal: '8180'
title: Selectable text in each transcript component
---
Defect from the user (OpenTestudo): the user cannot select the text of thoughts and tool results. Only MessageLayout turns on Textual selection.

Fix:
- Turn on Textual selection in ResponseView and in AttachmentTextContent, not only in MessageLayout.
- Show plain transcript labels (plan entries, diff hunk headers, terminal command and cwd, session message sender line, compaction error) in coordinated selectable text.
- Show JSON (error data, JSON disclosure) in a read-only EditorKit view.
- Remove SwiftUI `.textSelection(.enabled)` from the transcript, because SwiftUI cannot clear that selection.
- A test that each component puts its text in a selectable component. #bug