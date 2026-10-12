---
assignees:
- claude-code
position_column: todo
position_ordinal: 8b80
title: 'Tests: use NameChecks.expectDistinctNames for the other distinct-value checks'
---
## What
Task ^02jyret added the shared test helper `NameChecks.expectDistinctNames(_:sourceLocation:)` in `Tests/AgentViewKitTests/Helpers/NameChecks.swift`. SymbolConceptTests and ToolKindSymbolTests call it. Other test files still write the same check by hand: `#expect(Set(values).count == values.count)`.

## Work
- [ ] Make these tests call the shared helper. If a test compares values that are not strings, make the helper generic over `Hashable` first.
  - `Tests/AgentViewKitTests/Status/TaskListViewLabelTests.swift` (`eachStatusAndPriorityHasADistinctLabel`)
  - `Tests/AgentViewKitTests/Status/StateBannerStopReasonTests.swift` (titles and identifiers)
  - `Tests/AgentViewKitTests/Attachments/AttachmentResolutionTests.swift` (`eachRendererHasADistinctIdentifier`)
  - `Tests/AgentViewKitTests/Thread/ThreadMinimapTickMarkTests.swift` (shapes)
  - `Tests/AgentViewKitTests/Thread/TranscriptRowKeyTests.swift` (row keys)
  - `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift` (`tableHasOneRowForEachToken`)
  - `Tests/AgentViewKitTests/HumanInTheLoop/PermissionPresentationTests.swift` (positions)
- [ ] The tests in `Tests/PackageStructureTests` are a different target. Do not change them in this task.
- [ ] Run the full `swift test`.