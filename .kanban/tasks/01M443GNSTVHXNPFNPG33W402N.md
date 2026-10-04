---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: Show a banner for each extension stop reason in StateBanner
---
## What
`StateBanner` (`Sources/AgentViewKit/Status/StateBanner.swift`) shows nothing for `.idle(.unknown)`. Thus a cut, empty, stalled or failed prompt looks like a correct end. Source: update.md §9.2.

The agent sends these extension stop reasons (`PromptExecution` in FoundationModelsACPAgent): `_truncated`, `_ended_in_reasoning`, `_repeated`, `_reasoning_limit`, `_error`, `_no_output`, `_stalled`. The kit `StopReason(wireValue:)` keeps the raw value.

- [ ] Add one banner text for each known `_` value. Put the texts in one table, so that the binding to the ACP `StopReason.unknown(String)` (later task) uses the same table.
- [ ] Show a general banner for each other unknown value. Include the raw value. Do not show nothing.
- [ ] Give each banner an accessibility identifier.

## Acceptance Criteria
- [ ] Each of the 7 known values shows its own text.
- [ ] An unknown value, for example `_custom`, shows the general banner with the raw value.
- [ ] `end_turn` shows no warning banner (no change).

## Tests
- [ ] Add `Tests/AgentViewKitTests/Status/StateBannerStopReasonTests.swift`: a parameterized test over the 7 values, one test for an unknown value, one test for `end_turn`.
- [ ] Add a hosted view test with `HostedViewHarness` that finds the banner by its accessibility identifier.
- [ ] `swift test --filter StateBanner` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #acp-client