---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m46bhe7gaj0svf1289dene8t
  text: |-
    Research done.
    - `ContextUsageTests` reads the merge table in `Docs/decisions/usage-model.md`. Each stored property must have a row, and each row must name a stored property. Thus the rows for `input`, `output` and `quota` (FoundationModels and PCC) must go from that table when the fields go.
    - After the removal, no error kind uses the Retry action (`rateLimited` and `timeout` used it). Thus `ErrorView.Action.retry` and `ErrorActions.retry` go. Rephrase stays for `refusal`.
    - `ConversationLayout.relatedErrorID` maps `idle(.maxTokens)` to `contextSizeExceeded`. After the removal, `idle(.maxTokens)` has no related error kind.
    - Tests that use `.timeout` as a sample kind: ConversationViewHostedTests, ConversationLayoutTests, RegistryResolutionTests, TurnSummaryTests, ActivityTimelineHostedTests, AgentThreadApplyTests, ThreadItemTests, ErrorViewHostedTests. They change to a kind that stays.
    - `init(used:fill:)` is not a word, so the whole-word scan cannot find it. The word `fill` also matches SwiftUI code. The vocabulary test gets a second check for removed label sequences, `(used: ... fill:`.
    - README "Components" line for `ContextUsageView` stays (task ^g95wwbs). plan.md lines stay for the same reason.
  timestamp: 2026-10-05T15:39:54.992128+00:00
- actor: claude-code
  id: 01m46bz3eejdex1snwezek9p8e
  text: |-
    Implementation landed (TDD). RED: the changed tests did not compile, because `ContextUsageView.detailText(for:locale:)` did not exist. GREEN: the five changed suites passed, then the full `swift test` passed.

    What changed:
    - `ContextUsage` now has `used`, `size` and `cost` only. `init(used:fill:)`, `Input`, `Output` and `Quota` are gone.
    - `ThreadError.Kind` now has `refusal`, `acp` and `unknown` only. `ErrorView` lost the four blocks. No kind used Retry after the removal, so `ErrorView.Action.retry` and `ErrorActions.retry` are gone too. `ErrorActions` now has `init(rephrase:)` only.
    - `ConversationLayout.relatedErrorID`: `idle(.maxTokens)` has no related error kind now. `idle(.refusal)` matches `refusal` only.
    - `ContextUsageView`: `detailLines(for:locale:)` became `detailText(for:locale:)`, which gives one string. The quota label, `quotaIdentifier`, `quotaText`, and the quota symbol and color are gone.
    - `Docs/decisions/usage-model.md`: the merge table has the ACP rows only. `ContextUsageTests` reads this table, so the table had to change with the type.
    - `RemovedVocabularyTests`: added `contextSizeExceeded` and `guardrailViolation`. Added a second scan, `RemovedInitializer`, which finds the argument labels of a call in order (`\(\s*\bused:.*\bfill:`). The whole-word scan cannot find `init(used:fill:)`, and the word `fill` also matches SwiftUI code.
    - Tests that used `.timeout` as a sample kind now use `.unknown(message:)` or `.refusal(explanation:)`.

    Not changed: the plan.md lines and the README line for `ContextUsageView` (task ^g95wwbs), and the `contextSizeExceeded` text in a ReadmeCoverageTests fixture string (it is test data for the Markdown parser, not a use).

    Process note: one test edit (ErrorViewHostedTests) was made with a shell script, not with the file tool. The result was read back and is correct.
  timestamp: 2026-10-05T15:47:22.702373+00:00
- actor: claude-code
  id: 01m46bz6qayysvb1jhcbrhtcg5
  text: |-
    ### implement — changed
    - evidence: 17 files — Sources/AgentViewKit/Model/ContextUsage.swift, Sources/AgentViewKit/Model/ThreadError.swift, Sources/AgentViewKit/Items/ErrorView.swift, Sources/AgentViewKit/Items/ErrorActions.swift, Sources/AgentViewKit/Status/ContextUsageView.swift, Sources/AgentViewKit/Thread/ConversationView.swift, Docs/decisions/usage-model.md, Tests/PackageStructureTests/RemovedVocabularyTests.swift, Tests/AgentViewKitTests/{Model/ContextUsageTests, Items/ErrorViewHostedTests, Status/ContextUsageViewHostedTests, Thread/ConversationLayoutTests, Thread/ConversationViewHostedTests, Thread/RegistryResolutionTests, Model/ThreadItemTests, Model/AgentThreadApplyTests, Activity/TurnSummaryTests, Activity/ActivityTimelineHostedTests}.swift; `swift test` passed (1151 + 69 + 124 + 1 tests, 0 failures, 0 warnings)
    - next: /review
  timestamp: 2026-10-05T15:47:26.058705+00:00
- actor: claude-code
  id: 01m46cany6v5fvcgsc8f9frxg3
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — ContextUsage keeps used, size and cost; ThreadError.Kind keeps refusal, acp and unknown; Retry action removed; usage-model.md; RemovedInitializer scan; 18 files
    - test: green — swift test, 1345 passed; README gate passed
    - commit: 0fff37a
    - review: clean — 0 findings
  timestamp: 2026-10-05T15:53:42.086289+00:00
- actor: claude-code
  id: 01m46caq74eyq9r082wx101bd1
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (0fff37a). 17 files reviewed. 0 findings, 0 confirmed, 0 refuted. Not reviewed: 4 .kanban files (ignore rule), Docs/decisions/usage-model.md (no validator matches this file).
    - next: none. The task is in done.
  timestamp: 2026-10-05T15:53:43.396017+00:00
depends_on:
- 01M443M1YMTRRXEZYGFAJ4J75B
position_column: done
position_ordinal: df80
title: Remove the Router and FoundationModels parts of ContextUsage and ThreadError.Kind
---
## What
Only the Router and FoundationModels sources made these values (update.md §6). ACP gives usage through `usage_update` (`used`, `size`, cost) and errors through JSON-RPC codes.

- [x] In `Sources/AgentViewKit/Model/ContextUsage.swift`: remove `init(used:fill:)` and the `Input`, `Output` and `Quota` parts. Keep the fields that ACP `usage_update` fills.
- [x] In `Sources/AgentViewKit/Model/ThreadError.swift`: remove the `ThreadError.Kind` cases `contextSizeExceeded`, `rateLimited`, `guardrailViolation` and `timeout`. Remove their blocks and actions from `Items/ErrorView.swift` and `Items/ErrorActions.swift`.
- [x] Change `Status/ContextUsageView.swift` for the smaller `ContextUsage`.
- [x] Delete or change `Tests/AgentViewKitTests/Model/ContextUsageTests.swift`, `ErrorViewHostedTests` and the `ContextUsageView` tests.

## Acceptance Criteria
- [x] `ContextUsage` has only the fields that ACP fills. `ThreadError.Kind` has no case that only FoundationModels made.
- [x] `swift test` passes.

## Tests
- [x] Change `ContextUsageTests`: one test for the values from a `usage_update`.
- [x] Add `contextSizeExceeded`, `guardrailViolation` and `init(used:fill:)` to `RemovedVocabularyTests`.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.