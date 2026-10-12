---
assignees:
- claude-code
position_column: todo
position_ordinal: 8c80
title: Use StatusSymbolImage for the other status symbols
---
## What
`Sources/AgentViewKit/Items/StatusSymbolImage.swift` (from ^r9sqgxj) holds the treatment of a status symbol: the hierarchical rendering mode, the symbol weight of the kit theme and a theme color. Other views still write the same modifier chain on their own symbol image.

## Work
- [ ] `Items/CompactionEntryView.swift` (header symbol): hierarchical, status color, symbol weight. Use `StatusSymbolImage`.
- [ ] `Items/ErrorView.swift` and `Status/SessionNoticeBanner.swift`: examine each symbol image with the hierarchical mode, a theme color and the symbol weight. Use `StatusSymbolImage` where the chain is the same.
- [ ] Add each changed file to `SharedSymbolTreatmentTests.statusSymbolFiles` (Tests/PackageStructureTests).
- [ ] Keep `SymbolRenderingModeTests` green.