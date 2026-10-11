---
assignees:
- claude-code
depends_on:
- 01M4NPHNFGP5JDZS02XHHE6BE3
position_column: todo
position_ordinal: '8180'
title: 'SF Symbols: show each status with a symbol, not with color only'
---
## What
An audit on 2026-10-11 found indicators that show their meaning only with color. Paths are below `Sources/AgentViewKit/`.

## Work
- [ ] Activity timeline: show the tool status with its status symbol, and add the status to the accessibility label (`Activity/ActivityTimeline.swift:209`, `:247-248`).
- [ ] MCP connection chip: replace the colored dot with a status symbol (`Connections/ConnectionStatusChip.swift:42`). Localize its labels (`:80-84`).
- [ ] Plan priority: use a different symbol for each priority level, not the same `flag.fill` in different colors (`Status/TaskListView.swift:171-174`).
- [ ] Status bar: a failure banner uses the error color, not `theme.accent` for each banner (`Status/StatusBar.swift:37`).
- [ ] Thread minimap: the ticks show the status with color only (`Thread/ThreadMinimapView.swift:305-316` `tint(of:)`, the `Canvas` at `:152`). The accessibility elements of each tick exist only in DEBUG builds (`:156`). Give the status a signal that is not color (shape or symbol), and give release builds an accessible summary.
- [ ] Tests for each change.