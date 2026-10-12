---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4q9xn2vre0qg6ht3z2a3fcd
  text: |-
    Implementation done.
    - NameChecks has a new generic `expectDistinct<Value: Hashable>(_:sourceLocation:)`. `expectDistinctNames` stays for strings and calls it. The two existing callers do not change.
    - Positions in PermissionPresentationTests are `Int`, so that test calls `expectDistinct`. The other six listed files compare strings and call `expectDistinctNames`.
    - AttachmentResolutionTests compared the set count with `Renderer.allCases.count`. The identifiers come from `allCases`, so the helper check has the same meaning.
    - One more check that the card did not list: `AttachmentChipsHostedTests.twoDroppedImagesGoToTwoFiles` had `Set(urls).count == 2`. It now has `attachments.count == 2` and `NameChecks.expectDistinct(urls)`. This is the same as "two attachments in two different files". It is a little stricter: before, three attachments with two URLs also passed.
    - The `Set(...).count > 1` in SymbolConceptTests is a filter, not an expectation. It stays.
    - Tests/PackageStructureTests did not change.
  timestamp: 2026-10-12T05:38:43.419200+00:00
- actor: claude-code
  id: 01m4q9xqvyeej170zdx2m4jtj1
  text: |-
    ### implement — changed
    - evidence: 9 files — Tests/AgentViewKitTests/Helpers/NameChecks.swift, Status/TaskListViewLabelTests.swift, Status/StateBannerStopReasonTests.swift, Attachments/AttachmentResolutionTests.swift, Thread/ThreadMinimapTickMarkTests.swift, Thread/TranscriptRowKeyTests.swift, Theme/AgentThemeGoldenTests.swift, HumanInTheLoop/PermissionPresentationTests.swift, Input/AttachmentChipsHostedTests.swift. `swift test`: 1160 tests in 128 suites passed, 2 planned known issues, exit 0. Load average before 26.71 22.96 21.49, after 14.21 20.46 20.87.
    - next: review
  timestamp: 2026-10-12T05:38:46.270199+00:00
- actor: claude-code
  id: 01m4qa9axffwaj0p1nf46g8pv6
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 7ac42fa). 0 findings, 0 confirmed, 0 refuted. 9 files reviewed. 4 .kanban files not reviewed because of the ignore rule.
    - next: none. The task is in done.
  timestamp: 2026-10-12T05:45:06.223272+00:00
- actor: claude-code
  id: 01m4qa9nh3txg545f0f7qbbewr
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — NameChecks.expectDistinct (generic) and expectDistinctNames in eight test files
    - test: green — swift test, 1160 tests passed, 2 expected known issues, load average 15 to 21
    - commit: 7ac42fa
    - review: clean — 0 findings (9 files); task in done
  timestamp: 2026-10-12T05:45:17.091035+00:00
position_column: done
position_ordinal: ffb180
title: 'Tests: use NameChecks.expectDistinctNames for the other distinct-value checks'
---
## What
Task ^02jyret added the shared test helper `NameChecks.expectDistinctNames(_:sourceLocation:)` in `Tests/AgentViewKitTests/Helpers/NameChecks.swift`. SymbolConceptTests and ToolKindSymbolTests call it. Other test files still write the same check by hand: `#expect(Set(values).count == values.count)`.

## Work
- [x] Make these tests call the shared helper. If a test compares values that are not strings, make the helper generic over `Hashable` first.
  - `Tests/AgentViewKitTests/Status/TaskListViewLabelTests.swift` (`eachStatusAndPriorityHasADistinctLabel`)
  - `Tests/AgentViewKitTests/Status/StateBannerStopReasonTests.swift` (titles and identifiers)
  - `Tests/AgentViewKitTests/Attachments/AttachmentResolutionTests.swift` (`eachRendererHasADistinctIdentifier`)
  - `Tests/AgentViewKitTests/Thread/ThreadMinimapTickMarkTests.swift` (shapes)
  - `Tests/AgentViewKitTests/Thread/TranscriptRowKeyTests.swift` (row keys)
  - `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift` (`tableHasOneRowForEachToken`)
  - `Tests/AgentViewKitTests/HumanInTheLoop/PermissionPresentationTests.swift` (positions)
- [x] The tests in `Tests/PackageStructureTests` are a different target. Do not change them in this task.
- [x] Run the full `swift test`.