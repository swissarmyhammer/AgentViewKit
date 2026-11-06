---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6rytqthh5jnr6wsn02avgb1
  text: |-
    ### review — clean
    - evidence: review sha 35ed0376..HEAD (60e8df8d, revert of 0ad2c52d in Sources/AgentViewKit/Thread/AgentThreadView.swift) — 0 findings, 0 confirmed, 0 refuted, 7 attempted, 0 failed; .kanban/ files excluded by .reviewignore. Caller-verified: root swift test 1072+50 passed; ScreenshotTests swift test 32 passed incl. gallery completeness with "Gallery columns" captured, on EK 2eb4b01a.
    - next: done
  timestamp: 2026-11-06T17:34:46.097073+00:00
position_column: done
position_ordinal: ffffffc380
title: Drop the thread's 360 pt minimum width now that crumbs never wrap
---
^ret3w0j gave AgentThreadView `.frame(minWidth: AgentThreadLayout.minimumWidth * fontScale)` (360 pt) because EK's EditorBreadcrumbBar wrapped a squeezed crumb one character per line, so the `.inspector` zero-width probe made a thread need 787.5 pt of height. EK ^zeyyr69 (2eb4b01a) fixes the bar: a crumb never wraps, the bar is one line tall at any width, and it fills its offered width from the leading edge. EK says AVK can drop the 360 pt minimum.

- [x] Remove `AgentThreadLayout.minimumWidth`, the frame and the `fontScale` it used (revert 0ad2c52d) on EK ≥ 2eb4b01a
- [x] ScreenshotTests gallery generates every key screen, including "Gallery columns" (1180×760)
- [x] Root unit suite green