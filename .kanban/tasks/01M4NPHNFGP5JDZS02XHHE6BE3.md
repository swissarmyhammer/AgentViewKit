---
assignees:
- claude-code
depends_on:
- 01M4NPZHCT8SVBD2JAM8PH2F7D
position_column: todo
position_ordinal: '80'
title: 'SF Symbols: one symbol table, one symbol for each concept'
---
## What
An audit on 2026-10-11 found that the symbol names are spread over many views, and that one concept has different symbols in different views. The renames of the old names are on a separate card, which comes first. Paths are below `Sources/AgentViewKit/`.

## Work
- [ ] Put each SF Symbol name of the kit in one place (extend `ToolKindSymbol` / `ToolStatusSymbol` in `Items/ToolKindSymbol.swift`, or add one symbol table). The views read the names from it.
- [ ] Use one symbol for each concept:
  - error: `xmark.octagon.fill` (`Items/ToolKindSymbol.swift:52`, `Status/SessionNoticeBanner.swift:104`, `Status/StateBanner+StopReasons.swift:45`) against `exclamationmark.triangle.fill` (`Items/ErrorView.swift:54`, `Status/StateBanner.swift:233`) and the outline triangle (`Items/UserMessageView.swift:89`, `Diff/DiffRendererSlot+EditorKit.swift:77`, demo `ACPTabView.swift:351`)
  - cancelled: `slash.circle` (`Items/ToolKindSymbol.swift:53`), `xmark.circle` (`Status/TaskListView.swift:201`), `stop.circle.fill` (`Status/StateBanner.swift:185`)
  - pending: `hourglass` against `circle`
  - completed: `checkmark.circle` (`Status/StateBanner.swift:171`) against `checkmark.circle.fill`
  - unknown: `questionmark.circle` (`Status/TaskListView.swift:202`, `Items/ToolKindSymbol.swift:55`), `questionmark.circle.fill` (`Status/StateBanner.swift:86`, `Status/StateBanner+StopReasons.swift:73`), `questionmark.square.dashed` (`Items/ToolKindSymbol.swift:25`)
  - diff edit row: `pencil` against the `.square` symbols (`Diff/DiffView.swift:174-181`)
- [ ] The switch-mode tool kind (`Items/ToolKindSymbol.swift:23`) and the max-turn-requests banner (`Status/StateBanner.swift:208`) must not show the same symbol.
- [ ] Tests: two different concepts do not share a symbol. Cover the banners, the stop reasons, the plan, the diff, the command output, the message actions and the send state. `Tests/AgentViewKitTests/Items/ErrorViewHostedTests.swift:15` pins `exclamationmark.triangle.fill`; change it to read the table.