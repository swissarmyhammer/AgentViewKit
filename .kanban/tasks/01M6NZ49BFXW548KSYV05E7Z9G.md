---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6p202z3kd2bx44w24f7nsv3
  text: |-
    Picked up in worktree branch worktree-agent-ab4df383ae84c6d94 (merged local main 638cfcfc). `swift package update` in root, IntegrationTests and ScreenshotTests: EditorKit resolves to main 73033d2 (contains de292643 and 2b0d42e2).

    Research: 150 calls in 46 files under IntegrationTests/Tests/IntegrationTests (root Tests/ and ScreenshotTests/ have none). Renamed mechanically: `harness.press(identifier: X)` -> `harness.perform(.press, on: X)`, `increment(identifier:)` -> `perform(.increment, on:)`, `performCustomAction(named: N, identifier: X)` -> `perform(.custom(N), on: X)`, including the 4 calls split over two lines. One expectation switched error type: AgentRowListSectionsHostedTests now expects `AccessibilityActionError.noCustomAction(name:identifier:)` (perform throws AccessibilityActionError, not HostedViewHarnessError). ARCHITECTURE.md "Tests of this kit" names `perform(_:on:)` with its exactly-one-element lookup instead of the three old verbs; the comment in ElicitationFieldViewsHostedTests names `HostedViewHarness.perform(_:on:)`.
  timestamp: 2026-11-05T14:32:23.779781+00:00
- actor: claude-code
  id: 01m6p29vyd3yfrm6qsybx1sstk
  text: |-
    Exactly-one-match failures (first full IntegrationTests run after the rename: 2 of 954), each fixed without loosening the lookup:
    1. SourcesViewHostedTests.aPressOnARowOpensItsSource — 2 elements had "link-card": every LinkView card of the sources footer shared LinkView.cardIdentifier. Fixed in the VIEW: SourceLink gives each card its own id, `SourcesView.cardIdentifier(index:)` = `sources-card-<index>` (new public `cardIdentifierPrefix`, documented in the SourcesView doc). The outer `.accessibilityIdentifier` overrides LinkView's own. Watched RED (noElement "sources-card-1") then GREEN.
    2. MessageActionsHostedTests.copyThreadInTheFooterOfAThreadViewRunsTheCopyThreadCommand — 2 elements had "message-copy-thread": the test put `.messageFooter { MessageActions(entry: $0) }` under both the user and the agent message, and every message's action row shares the per-action ids by design. Fixed in the TEST: the footer stands under the user message only (`if case .user = entry`).
    Also: the 4 two-line calls are formatted `perform(\n  .press, on: …)`.
  timestamp: 2026-11-05T14:37:44.269532+00:00
- actor: claude-code
  id: 01m6p29za0bsy0z7cth4qg9qgn
  text: |-
    ### implement — changed
    - evidence: commit c43c71bc on worktree-agent-ab4df383ae84c6d94; 48 files — ARCHITECTURE.md, Sources/AgentViewKit/Citations/SourcesView.swift, 46 files under IntegrationTests/Tests/IntegrationTests (150 calls renamed; MessageActionsHostedTests and SourcesViewHostedTests duplicate-id fixes). Root `swift test`: 983 + 48 tests passed. `swift test --package-path IntegrationTests`: 954 tests in 128 suites passed (5 known issues, the pre-existing withKnownIssue checks in FontRoleExpectationsTests). Only warning: the allowed mlx-swift "missing creator" one. No hosted test steals focus (no activate/makeKeyAndOrderFront added).
    - next: /review
  timestamp: 2026-11-05T14:37:47.712384+00:00
position_column: done
position_ordinal: ffffffaa80
title: Move AVK's hosted tests onto EditorKit's harness.perform(_:on:)
---
EK ^e0jrvyt is on EK origin at 2b0d42e2: `harness.perform(.press | .increment | .custom(name) | .focus | .pick(…), on: id)` in EditorTestSupport. It's headless: no activation, no window brought front, no key window, and menus show for one run-loop turn then close. Its lookup is stricter, requiring exactly one match.

About 42 AVK test files call EK's older `press(identifier:)`, `increment(identifier:)` and `performCustomAction(named:identifier:)`. Those still work and run the same path.

**Order:** start after the accessibility card ^b2h8hpz and the other in-flight cards merge, because they touch the same test files.

## What
- `swift package update` (all dependencies together).
- Rename every call to `perform(_:on:)`. Where the exactly-one-match lookup now fails, fix the duplicate ids in the view, or the test, rather than loosening the lookup.

## Tests
- [x] The full AVK suite is green, with zero warnings in AVK targets, and no hosted test steals focus.