---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4hasc1e8jpcz1h08sjjrjrz
  text: 'Decision (2026-10-09, owner): the kit corrects the anchor at jumps. The kit starts each jump, so it knows the target row. After a jump, the kit sets the anchor from the target row. Do not add a geometry callback to each row. A Load Earlier press after a jump must keep the correct row.'
  timestamp: 2026-10-09T21:58:25.070343+00:00
- actor: claude-code
  id: 01m4hb9wg1rpd4ectg23fxzg6g
  text: |-
    Research:
    - All jumps go through `ScrollAnchorManager.noteJump(to:)`: `ConversationView.showItem` (Show Error button), `ThreadMinimapView.jump(to:)` and `AgentCommandTarget.jump(forward:)`. Thus the manager is the one place to correct the state.
    - `saveAnchor()` reads `visibleIDs.first`. `AgentCommandTarget.jumpTarget(forward:)` also reads `visibleIDs.first`, so a stale report also makes the next jump command start from the wrong row. The minimap band reads `visibleIDs`.
    - The stale report arrives AFTER `noteJump`, so it is not sufficient to set `visibleIDs` in `noteJump`: the manager must also not let the stale report replace it.
    - `ConversationView` calls `noteVisible(ids: anchors.visibleIDs, ...)` from its scroll geometry callback (only the pin changes). That call must not count as a new report.
    - Plan: `noteJump` sets `visibleIDs` to `[id]` and keeps the jump item until the next report. A report that is equal to `visibleIDs` changes only the pin. The first new report after a jump replaces `visibleIDs` only when it includes the jump item; a report without the item is from a layout pass before the list placed the item, so the manager keeps `[id]`. The report after that replaces `visibleIDs` as before (the user scrolled). The pin state still comes from each report. No change to the rows, no new callback.
    - Existing tests that change: `AgentCommandsTests.theJumpCommandsGoToTheNextAndThePreviousTurn` (it gives no report after the first jump), and `ThreadMinimapViewHostedTests.aClickOnATickScrollsTheConversationToTheRowOfTheEntry` (its wait on `visibleIDs.contains(firstKey)` becomes true at once; it must check the row frame).
  timestamp: 2026-10-09T22:07:26.209489+00:00
- actor: claude-code
  id: 01m4hd1gafzxy30zmf498tsp39
  text: |-
    Implementation landed (not committed).

    Change in `Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift`:
    - New private `jumpItemID` (`@ObservationIgnored`): the item of the last jump, until the next new report.
    - `noteJump(to:)` also sets `visibleIDs = [id]` and `jumpItemID = id`.
    - `noteVisible(ids:distanceFromBottom:)`: the pin state still comes from each report. A report equal to `visibleIDs` (the scroll geometry callback of `ConversationView` sends `anchors.visibleIDs`) changes only the pin. The first new report after a jump replaces `visibleIDs` only when it includes the jump item, or when it pins the list. The report after that replaces `visibleIDs` as before, so a user scroll after a stale report is not lost.
    - New private `acceptsReport(of:)` holds that rule.
    - Doc comments of `visibleIDs`, `noteVisible` and `noteJump` tell the behavior.

    TDD: new tests in `ScrollAnchorManagerTests` (section "Jump report"). RED: `aJumpSetsTheVisibleIdsToTheItem` (got `["d", "e"]`), `aSaveAfterAJumpAndAReportWithoutTheItemKeepsTheItem` (the restore went to `.item("a")`, not `.item("c")`), `aReportEqualToTheVisibleIdsDoesNotEndTheWaitForTheJumpReport`. GREEN after the change: 29 of 29 in the suite. Two guard tests (`aJumpReportWithTheItemReplacesTheVisibleIds`, `theReportAfterAReportWithoutTheItemReplacesTheVisibleIds`) passed before and after: they fix the limits of the rule.

    Existing tests changed because of the new behavior:
    - `AgentCommandsTests.theJumpCommandsGoToTheNextAndThePreviousTurn`: it now gives the report of the first jump before the report of a scroll.
    - `ThreadMinimapViewHostedTests.aClickOnATickScrollsTheConversationToTheRowOfTheEntry`: the wait reads the row frame (`ConversationViewHostedTests.showsRow`), because `visibleIDs` holds the jump item at once.
    - `ConversationViewHostedTests.theShowErrorButtonMovesToTheErrorEntry`: adds `#expect(anchors.visibleIDs.contains(errorKey))` (the check from the reproduction on the card). The doc comment of `showsRow` is updated.

    Rule limit (known): if SwiftUI sends two different reports without the jump item before it places the item, the second one replaces `visibleIDs` (the same as before this change).

    Discovery: under high machine load (load average 29 to 80), the full `swift test` run fails in the demo agent suites at the 5 s bound, at the start of the run. Not related to this change. New card ^kmkd5rx.
  timestamp: 2026-10-09T22:37:48.751287+00:00
- actor: claude-code
  id: 01m4hd1qj4thy6d6qhmvzdy5wg
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift, Tests/AgentViewKitTests/Infrastructure/ScrollAnchorManagerTests.swift (5 new tests, 3 RED then GREEN), Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift, Tests/AgentViewKitTests/Thread/ThreadMinimapViewHostedTests.swift, Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift. `swift test --filter ScrollAnchorManagerTests`: 29 of 29 passed. Full `swift test` (load average 29 to 80): 1 + 93 tests passed; AgentViewKitTests 1040 tests in 110 suites, with 18 and then 33 issues, all in the demo agent suites at the 5 s bound at the start of the run (new card ^kmkd5rx); each changed test passed (ScrollAnchorManagerTests, AgentCommandsTests, ConversationViewHostedTests, ThreadMinimapViewHostedTests, AgentCommandScopeHostedTests). The failed suites alone: 34 tests in 5 suites passed. `swift build --package-path Benchmarks`: build complete (only the known mlx-swift warning "missing creator for mutated node"). `Scripts/check-benchmarks.sh` under load 29 to 48: instruction gate passed; wall clock p90 of "Transcript stream, default cadence" 573 ms vs 209 ms (load). Single run of that scenario under load 40: instructions p90 2802 M vs baseline 2728 M (+2.7 %, gate 25 %), wall clock p90 288 ms vs 209 ms (+38 %, gate 75 %), so it passes.
    - next: /review
  timestamp: 2026-10-09T22:37:56.164353+00:00
- actor: claude-code
  id: 01m4hhnjhx856wmahk0v1m8h9p
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (480b95e): 1 finding (1 confirmed, 0 refuted) — Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift:256 swift/fluent-usage
    - next: Rename acceptsReport(of:) to an imperative verb phrase, or move the clear of jumpItemID into noteVisible(ids:distanceFromBottom:). Then run the review again.
  timestamp: 2026-10-09T23:58:40.701534+00:00
- actor: claude-code
  id: 01m4hhnyxcv6wddwxwgxmmvqnk
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 5 files (ScrollAnchorManager.swift and 4 test files)
    - test: green — swift test, 1040 tests in 110 suites passed (load average 38-53); Benchmarks build complete
    - commit: 480b95e
    - review: findings — Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift:256 (swift/fluent-usage)
  timestamp: 2026-10-09T23:58:53.356984+00:00
- actor: claude-code
  id: 01m4hkybt6wkpcew6zf5zs1928
  text: |-
    Fix for the finding `swift/fluent-usage` on `acceptsReport(of:)` (the second form, as the request prefers):
    - `acceptsReport(of:)` is now a pure predicate. It only returns a Bool. Its doc comment tells that it does not change state.
    - `noteVisible(ids:distanceFromBottom:)` computes `isNewReport` (`ids != visibleIDs`) before it can replace `visibleIDs`, and then sets `jumpItemID = nil` when `isNewReport` is true. This is the same condition as before (the old guard cleared `jumpItemID` only for a new report). A clear when `jumpItemID` is already `nil` changes nothing. Thus the behavior is the same.
    - Check of the other functions that 480b95e added or changed in ScrollAnchorManager.swift: `noteVisible(ids:distanceFromBottom:)` and `noteJump(to:)` are imperative verb phrases with side effects, which is correct. `isAtBottom(visibleIDs:distanceFromBottom:)` is a pure query (480b95e did not change it). No other function has a query name with a side effect.
    - No new test: the change is a refactor with the same behavior. The existing tests `theReportAfterAReportWithoutTheItemReplacesTheVisibleIds` and `aReportEqualToTheVisibleIdsDoesNotEndTheWaitForTheJumpReport` cover the clear of `jumpItemID`.
    - Load: the load average stayed at 44 to 104 for the full 30 minute wait. The full run started at load 104.53 and passed.
  timestamp: 2026-10-10T00:38:25.862749+00:00
- actor: claude-code
  id: 01m4hkye0t5gjh5wdgasqr42hk
  text: |-
    ### implement — changed
    - evidence: 1 file — Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift. `swift test --filter ScrollAnchorManagerTests`: 29 tests in 1 suite passed. Full `swift test` (load average 104): 93 tests in 11 suites passed, 1040 tests in 110 suites passed, 0 failures. Only the known mlx-swift build warning "missing creator for mutated node".
    - next: /review
  timestamp: 2026-10-10T00:38:28.122909+00:00
- actor: claude-code
  id: 01m4hn75wz9emd6eq7p3cqyv7b
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit afb9821). 0 findings, 0 confirmed, 0 refuted, 7 validators attempted, 0 failed. 1 file reviewed. The prior finding is checked.
    - next: none. The task is in done.
  timestamp: 2026-10-10T01:00:43.295698+00:00
- actor: claude-code
  id: 01m4hn7ds5m8m3kn3zrp2py6ew
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — 1 file (ScrollAnchorManager.swift: acceptsReport(of:) is a pure predicate; noteVisible clears jumpItemID)
    - test: green — swift test, 1040 tests in 110 suites passed (load average 77)
    - commit: afb9821
    - review: clean — 0 findings, prior finding checked
  timestamp: 2026-10-10T01:00:51.365455+00:00
position_column: done
position_ordinal: ff9b80
title: Decide if ScrollAnchorManager.visibleIDs must be correct after a long jump in ConversationView
---
## What
^vyqyvwv found this behavior. After a long jump in `ConversationView` (for example the Show Error button, the thread minimap, or the jump command), the LazyVStack can do a first layout pass in which a row that SwiftUI kept alive still has an old position. `onScrollTargetVisibilityChange` reports the rows in view for that pass. The next layout pass moves the row to its correct position, but the content offset and the content size do not change. SwiftUI then does not call `onScrollTargetVisibilityChange` again. Thus `ScrollAnchorManager.visibleIDs` stays stale until the next scroll. The list itself shows the correct rows.

Evidence (from ^vyqyvwv): after the jump to the first row, the clip origin was at the top of the content, and the accessibility frame of the error row was in the list frame. But `visibleIDs` was `[m0, m1, m2, m3, m4]` and did not include the error row for 5 seconds.

Effects: `saveAnchor()` uses `visibleIDs.first`, so a Load Earlier press after such a jump can keep the wrong row as the anchor. A view that shows the rows in view from `visibleIDs` can show the wrong rows until the next scroll.

- [x] Decide if the kit must correct `visibleIDs` after a jump, or if the stale value until the next scroll is acceptable. Decision (owner, 2026-10-09): the kit corrects the anchor at jumps. The kit starts each jump (Show Error button, thread minimap, jump command), so it knows the target row. After a jump, `ScrollAnchorManager` sets the anchor and `visibleIDs` (the state that `saveAnchor()` reads) from the target row. A Load Earlier press right after a jump must keep the target row. Do not add a geometry callback or a position check to each row. Keep all state in `ScrollAnchorManager`.
- [x] If the kit must correct it, find a way that does not add a geometry callback to each row (the observation benchmarks measure the cost of the list). Done in `ScrollAnchorManager` only: `noteJump(to:)` sets `visibleIDs` to `[id]`; the first new report after the jump replaces `visibleIDs` only when it includes the item or pins the list. No row callback, no change to `ConversationView`.

## How to reproduce
Run 6 test-bundle processes at the same time with `swiftpm-testing-helper`, `--filter theShowErrorButtonMovesToTheErrorEntry --repetitions 30 --repeat-until fail`, and an assertion on `anchors.visibleIDs.contains(errorKey)` after the press. See the comments on ^vyqyvwv.

## Review Findings (2026-10-09 18:44)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 8 not reviewed.

> 8 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 8 file(s)

- [x] `Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift:256` `swift/fluent-usage` — The predicate acceptsReport(of:) reads as a side-effect-free query, but it clears jumpItemID on the first new report. A caller that reads the name cannot know that the call changes state. The rule says operations with side effects are imperative verb phrases, so the name hides the effect. Rename the function to an imperative verb phrase that states the effect, such as takeReportIfAccepted(of:) or endJumpWait(for:), so the name says the call clears the jump wait. Or move the clear of jumpItemID out of the predicate into noteVisible(ids:distanceFromBottom:), so the function only returns a Bool.
