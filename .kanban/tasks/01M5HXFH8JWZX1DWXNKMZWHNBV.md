---
assignees:
- claude-code
position_column: todo
position_ordinal: a480
title: 'AVK-14f Add one #Preview sheet for the status icons'
---
## Goal

The user examines the look of each component in the Xcode canvas. These small icon views have no `#Preview`:

- `Sources/AgentViewKit/Items/ToolStatusImage.swift` — `ToolStatusImage`
- `Sources/AgentViewKit/Items/StatusSymbolImage.swift` — `StatusSymbolImage`
- `Sources/AgentViewKit/Items/DecorativeSymbolImage.swift` — `DecorativeSymbolImage`

## Change

- [ ] Add one `#Preview` in each file. Each preview shows a grid of all the states of its view, with the name of each state next to the icon. Use the enums of the model, with `allCases` where the type has it, so that a new state shows without a change to the preview.
- [ ] Show the icons at the sizes that the kit uses.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14