---
assignees:
- claude-code
position_column: todo
position_ordinal: '8380'
title: 'AgentRowList: check the focused row''s mark with macOS Keyboard Navigation on'
---
Unverified from the current-row work (3a75e41). With the system's Keyboard Navigation setting on, SwiftUI may give the row's `.focusable()` the responder instead of the scope's beacon. The row has its focus effect off, so a focused non-current row could show no mark. This is inferred from the code; tests flip no system settings.

- [ ] Find out without flipping a system setting, for example by reading the key-view behaviour in a hosted test, or wait for Testudo's report.
- [ ] If it's real, use `.editorFocusRing(isFocused:radius:)` with a `@FocusState`, as PermissionView does.