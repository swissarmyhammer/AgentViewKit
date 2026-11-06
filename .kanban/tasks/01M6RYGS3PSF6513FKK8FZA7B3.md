---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Drop the thread's 360 pt minimum width now that crumbs never wrap
---
^ret3w0j gave AgentThreadView `.frame(minWidth: AgentThreadLayout.minimumWidth * fontScale)` (360 pt) because EK's EditorBreadcrumbBar wrapped a squeezed crumb one character per line, so the `.inspector` zero-width probe made a thread need 787.5 pt of height. EK ^zeyyr69 (2eb4b01a) fixes the bar: a crumb never wraps, the bar is one line tall at any width, and it fills its offered width from the leading edge. EK says AVK can drop the 360 pt minimum.

- [ ] Remove `AgentThreadLayout.minimumWidth`, the frame and the `fontScale` it used (revert 0ad2c52d) on EK ≥ 2eb4b01a
- [ ] ScreenshotTests gallery generates every key screen, including "Gallery columns" (1180×760)
- [ ] Root unit suite green