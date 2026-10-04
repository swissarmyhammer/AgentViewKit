---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m44g1yxx5t56a85ygy7yftmn
  text: |-
    Research:
    - `StateBanner.message(for:)` is the one source of the banner text. `ConversationView` (`ConversationBanner`) and `ThreadAccessibility.turnAnnouncement` call it too.
    - `turnAnnouncement` gives the banner title when a banner exists. Thus after this change, an unknown stop reason announces the banner title, not "Response complete". The existing test `aTurnThatEndsAnnouncesThatTheResponseIsComplete` asserts "Response complete" for `.idle(.unknown("other"))`. That assertion must change. The existing hosted test `StateBannerHostedTests` asserts that `.idle(.unknown("paused"))` shows no bar. That row must change too.
    - The 7 values come from `PromptExecution` in FoundationModelsACPAgent: `_truncated` (output token ceiling), `_ended_in_reasoning` (ended inside the reasoning, below the ceiling), `_repeated` (Router stopped for repetition), `_reasoning_limit` (Router stopped at the reasoning token limit), `_error` (unmapped prompt failure), `_no_output` (prompt generated nothing), `_stalled` (stalled generation ended).
    - Plan: a public table `StateBanner.extensionStopReasonMessages: [String: Message]` keyed by the raw wire value, and `StateBanner.message(forUnknownStopReason:)` that gives the table row or a general banner with the raw value. `Message` gets an `identifier`. The bar keeps `state-banner` on the container. The text group of the bar gets the identifier of the message.
  timestamp: 2026-10-04T22:20:21.821228+00:00
- actor: claude-code
  id: 01m44g912487fgam06nz1d1fwd
  text: |-
    Implementation landed (TDD):
    - RED: the new test file did not compile, because `Message.identifier`, `extensionStopReasonMessages` and `unknownStopReasonIdentifier` did not exist.
    - GREEN: new file `Sources/AgentViewKit/Status/StateBanner+StopReasons.swift` holds the table `StateBanner.extensionStopReasonMessages` (key = raw wire value) and `StateBanner.message(forUnknownStopReason:)`. It gives the table row, or a general text "The turn stopped for an unknown reason" with "The agent sent the stop reason <raw>." and the identifier `state-banner-stop-reason-unknown`. The later ACP `StopReason.unknown(String)` binding calls this same function.
    - `StateBanner.Message` has a new `identifier`. Each message has a different identifier (`state-banner-requires-action`, `state-banner-max-tokens`, `state-banner-max-turn-requests`, `state-banner-refusal`, `state-banner-stop-reason-<name>`). The container keeps `state-banner`. The combined text element of the bar has the identifier of the message.
    - `message(for:)` sends `.idle(.unknown(raw))` to the new function. `.idle(.endTurn)`, `.idle(.cancelled)`, `.idle(nil)` and `.running` still show no bar.
    - Changed existing tests: `StateBannerHostedTests` now expects a bar for `.idle(.unknown("paused"))`. `ThreadAccessibilityTests`: the "Response complete" assertion for an unknown reason moved to a new test `anUnknownStopReasonAnnouncesTheTitleOfItsBanner`, because `turnAnnouncement` now gives the banner title for an unknown reason. This is the correct result: an unknown stop reason must not read as a correct end.
    - I checked each SF Symbol name with `NSImage(systemSymbolName:)` on this machine: all exist.
    - `swift format lint` is clean on the new files. The old long line in `StateBanner.swift` (the max turn requests text) and the old import order in `ThreadAccessibilityTests.swift` were there before this change.
    - plan.md (StateBanner line) still names only the three standard reasons. The plan rewrite task ^bg95wws owns plan.md, so I did not change it.
  timestamp: 2026-10-04T22:24:13.380299+00:00
- actor: claude-code
  id: 01m44g995yga013443jm3rns3j
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Status/StateBanner.swift, Sources/AgentViewKit/Status/StateBanner+StopReasons.swift (new), Tests/AgentViewKitTests/Status/StateBannerStopReasonTests.swift (new), Tests/AgentViewKitTests/Status/StateBannerHostedTests.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityTests.swift. `swift test` full run: all suites pass (1291 tests in 113 suites in the main run), 0 warnings. `swift test --filter StateBanner` after the last text change: 11 tests in 2 suites pass, 0 warnings. `swift format lint` clean on the new files. `Scripts/test-examples.sh` not run (screen locked; this card needs only `swift test`).
    - correction: the previous comment names the plan rewrite task as ^bg95wws. The correct short id is ^g95wwbs.
    - next: /review
  timestamp: 2026-10-04T22:24:21.694260+00:00
- actor: claude-code
  id: 01m44ggjj279k3fws58tysqh8n
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 57f25b8), 0 findings, 0 confirmed, 0 refuted. 5 files reviewed. 4 .kanban files not reviewed (.reviewignore). No prior Review Findings sections.
    - next: task moved to done.
  timestamp: 2026-10-04T22:28:20.674066+00:00
- actor: claude-code
  id: 01m44ggm2sac8nwftgbg1avesf
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — StateBanner.swift, StateBanner+StopReasons.swift (new), StateBannerStopReasonTests.swift (new), StateBannerHostedTests.swift, ThreadAccessibilityTests.swift
    - test: green — swift test, 1527 passed
    - commit: 57f25b8
    - review: clean — 0 findings
  timestamp: 2026-10-04T22:28:22.233609+00:00
position_column: done
position_ordinal: d280
title: Show a banner for each extension stop reason in StateBanner
---
## What
`StateBanner` (`Sources/AgentViewKit/Status/StateBanner.swift`) shows nothing for `.idle(.unknown)`. Thus a cut, empty, stalled or failed prompt looks like a correct end. Source: update.md §9.2.

The agent sends these extension stop reasons (`PromptExecution` in FoundationModelsACPAgent): `_truncated`, `_ended_in_reasoning`, `_repeated`, `_reasoning_limit`, `_error`, `_no_output`, `_stalled`. The kit `StopReason(wireValue:)` keeps the raw value.

- [x] Add one banner text for each known `_` value. Put the texts in one table, so that the binding to the ACP `StopReason.unknown(String)` (later task) uses the same table.
- [x] Show a general banner for each other unknown value. Include the raw value. Do not show nothing.
- [x] Give each banner an accessibility identifier.

## Acceptance Criteria
- [x] Each of the 7 known values shows its own text.
- [x] An unknown value, for example `_custom`, shows the general banner with the raw value.
- [x] `end_turn` shows no warning banner (no change).

## Tests
- [x] Add `Tests/AgentViewKitTests/Status/StateBannerStopReasonTests.swift`: a parameterized test over the 7 values, one test for an unknown value, one test for `end_turn`.
- [x] Add a hosted view test with `HostedViewHarness` that finds the banner by its accessibility identifier.
- [x] `swift test --filter StateBanner` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #acp-client