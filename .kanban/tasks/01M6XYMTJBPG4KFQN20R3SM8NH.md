---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: Snapshot of the selection and focus look of AVK items
---
Found during ^v3zpcpd. No snapshot of ScreenshotTests shows a focused item, so after ^v3zpcpd no PNG changed and the user cannot review the new focus look.

To do:
- [ ] Add a HostedSnapshotTests screen (light and dark) with: an AgentRowList with a selected row and a focused row, a focused AttachmentChip, a selected AttachmentView chip, and a focused message (ring, no surface). Land the focus through the command system in the harness window. The window is never ordered in and never key; the inactive grey of a window that is not key is part of the look, so also show the active look as EK SelectableItemHostedTests does (`\.appearsActive`).
- [ ] Give the PNG paths to the user.

Test rules: no clock/sleep/poll/retry/timeLimit/XCUITest; no window shown and no focus taken.