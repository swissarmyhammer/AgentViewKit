---
assignees:
- claude-code
depends_on:
- 01M5D07DY0EJVKY1G21Y1E9RMY
position_column: todo
position_ordinal: '8580'
title: 'AVK-7f #Preview for each public view'
---
Design: AVK-7, D105 (h). Step 5 work.

AgentViewKit has no `#Preview` (about 72 public views). Add one `#Preview` for each public view, with a model built from values (`SessionModel.preview` / `previewSample`, and `apply(_:)` from the AVK-7a card for states that need updates). Put each preview in the file of its view.

Split the work into parts that can each be one commit: thread and items; human in the loop and elicitation; input and composer; sessions, activity, usage and the rest.

Acceptance: `swift build` builds all previews; a package structure test checks that each public `View` type in Sources has a `#Preview` in its file. #avk-7