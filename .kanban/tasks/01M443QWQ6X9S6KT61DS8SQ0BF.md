---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m48tj6xbqhswmxkjt8x37x5g
  text: |-
    Research done.
    - `SessionModel.usage` is `UsageUpdate?` (FoundationModelsACP): `size: Int`, `used: Int`, `cost: Cost?` (`amount: Double`, `currency: String`), `meta`. The model sets it on each `usage_update` and sets it to nil on reset.
    - Now `ContextUsageView(usage: ContextUsage?)` shows a ring and a percentage, and it shows "used of size tokens" only in the help tag and the accessibility hint. Callers: the demo `ACPTabView` and `ContextUsageViewHostedTests`.
    - `ContextUsage.fraction` has no other production caller. When the view stops its use, `fraction` is dead code.
    - Owner decision (question tool, 2026-10-06): keep a ring. A ring view takes numerator, denominator, caption and a text style enum: `short` shows "30%", `full` shows "1,200 of 4,000 tokens". ContextUsageView reads `SessionModel.usage` and gives used, size and "tokens" to the ring. The owner did not give the default style; I use `short`, because that is the current behavior.
    - Note for the owner: the question tool cuts off long questions. Short questions (one line) arrive complete.
  timestamp: 2026-10-06T14:40:57.771356+00:00
- actor: claude-code
  id: 01m48v2tkb8h2gnh6agsxqz5wq
  text: |-
    Implementation landed (TDD: the new tests failed to compile first, then passed).
    - New `UsageRingView` (`Sources/AgentViewKit/Status/UsageRingView.swift`): numerator, denominator, caption and `TextStyle` (`short` = "30%", `full` = "1,200 of 4,000 tokens"). The help tag and the accessibility hint give the other text. The ring and the percent come from the two numbers that the caller gives; the view keeps no model copy.
    - `ContextUsageView(session:style:)` reads `session.usage` in its body and gives `used`, `size` and "tokens" to the ring. Cost label from the ACP `Cost`. The identifier `percentIdentifier` is now `usageIdentifier` ("context-usage"), because the full style shows no percent.
    - Removed: `ContextUsageView(usage:)`, `percentText(for:)`, `detailText(for:)`, the old `ContextUsageViewHostedTests`, and the dead `ContextUsage.fraction` with its four tests. `Docs/decisions/usage-model.md` now says that `ContextUsage` has no `fraction`.
    - Demo `ACPTabView` shows `ContextUsageView(session:)` when `session.sessionModel` is set.
    - README not changed: its `ContextUsageView` line is already out of date (it names FoundationModels); ^g95wwbs rewrites the README.
    - Gates: the new suites pass (13 tests). `Scripts/test-examples.sh AgentViewKitDemo` passed. Full `swift test`: 1,323 of 1,324 passed; 1 failure in `PendingRequestsSessionModelHostedTests.thePermissionResponseFrameComesBeforeTheNextPromptFrame` (run 39 of 50: the prompt frame came before the permission response frame). That test does not touch this change. Cause: `SessionModel.selectPermission` only resumes a continuation, and the response goes out later from the request handler task. New task ^et6e0ps.
  timestamp: 2026-10-06T14:50:02.219298+00:00
- actor: claude-code
  id: 01m48v2xjxy8azjkscemaq0qeq
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Status/UsageRingView.swift (new), Sources/AgentViewKit/Status/ContextUsageView.swift, Sources/AgentViewKit/Model/ContextUsage.swift, Docs/decisions/usage-model.md, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, Tests/AgentViewKitTests/Status/ContextUsageSessionModelHostedTests.swift (new), Tests/AgentViewKitTests/Status/UsageRingViewTests.swift (new), Tests/AgentViewKitTests/Model/ContextUsageTests.swift, Tests/AgentViewKitTests/Status/ContextUsageViewHostedTests.swift (deleted). Commands: swift test --filter (13 passed), swift test (1323/1324, 1 unrelated race failure, ^et6e0ps), Scripts/test-examples.sh AgentViewKitDemo (passed).
    - next: /test, then /review.
  timestamp: 2026-10-06T14:50:05.277883+00:00
- actor: claude-code
  id: 01m48vddd606wjkn8cvdgp126b
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (8f29995): 0 findings (findings 0, confirmed 0, refuted 0; 7 validators ran, 0 failed). No prior Review Findings sections.
    - next: none. The task moved to done.
  timestamp: 2026-10-06T14:55:49.158925+00:00
- actor: claude-code
  id: 01m48vdepvppjj8n225dmgja76
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — ContextUsageView(session:) reads session.usage; UsageRingView (new); ContextUsage.fraction and the old view tests removed
    - test: green — swift test, 1324 passed
    - commit: 8f29995
    - review: clean — 0 findings
  timestamp: 2026-10-06T14:55:50.491754+00:00
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
- 01M443M8BHM2BDPPZ2FVDA5TFV
position_column: done
position_ordinal: ee80
title: Bind ContextUsageView to the usage of SessionModel
---
## What
Source: update.md §4.2 (last-value state `usage`), §4.5 (kit `ContextUsage` replaced by the ACP type). Owner rule (2026-10-06): the view binds directly to the observable model of FoundationModelsACPClient. It shows what the model holds. The kit keeps no copy of the usage and computes no usage value that the model does not report.

- [x] `ContextUsageView` (`Sources/AgentViewKit/Status/ContextUsageView.swift`) takes the `SessionModel` and reads `SessionModel.usage` (`UsageUpdate?`: `used`, `size`, and `cost` when present) directly in its body. Do not keep the usage in `@State`, in a kit struct or in a kit `@Observable` object.
- [x] Show nothing when `usage` is nil.
- [x] Remove the kit `ContextUsage` use from this view. Do not add a kit type that copies `UsageUpdate`.

## Acceptance Criteria
- [x] A `usage_update` that the model applies shows in the view with no other step: used of size, and the cost when the agent sends it.
- [x] A second `usage_update` replaces the shown values: the view always shows the last value of the model.
- [x] With `usage` nil, the view is hidden.
- [x] No kit type keeps a copy of `UsageUpdate`. (The view and the new `UsageRingView` keep no copy. The old kit `ContextUsage` type is still used by `AgentThread` and `SessionUpdateMapping`; ^71k836q deletes it.)

## Tests
- [x] `Tests/AgentViewKitTests/Status/ContextUsageSessionModelHostedTests.swift`: the scripted agent sends a `usage_update`, and the test asserts the shown text; a second update changes the text; with and without cost; with no update the view is hidden.
- [x] `swift test` passes. (2026-10-06 run: 1,323 of 1,324 tests passed. The one failure is the race in `PendingRequestsSessionModelHostedTests.thePermissionResponseFrameComesBeforeTheNextPromptFrame`, which this card does not touch. ^et6e0ps tracks it.) — the test step ran swift test green (1324 passed); the unstable frame-order test is ^et6e0ps.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.