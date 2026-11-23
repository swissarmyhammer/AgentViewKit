---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m852dep1zh4npzys3d7v314p
  text: |-
    Research (implement step):
    - ResponseView gives each prose segment and each code segment a model from `\.codeBlockModelCache` when the environment has a cache. With no cache, RenderedMarkdownView and CodeBlockView keep the model in `OwnModelSlot` (@State). When the row is not live (LiveRowRange), ResponseView shows a placeholder, the editor leaves the tree, and the slot goes away. Thus a row that comes back makes new models.
    - ConversationView sets `\.liveRowRange` but no `\.codeBlockModelCache`.
    - CodeBlockModelCache has no limit now. The transcript does not bound it: LiveRowRange exists because one answer keeps about 659 KiB (ARCHITECTURE.md). A default thread cache with no limit keeps the models of each row ever seen. Thus the default cache needs a count limit with least-recently-used eviction. A host cache keeps its old behavior (no limit) unless the host gives a limit.
    - Live range steps: the range moves when the rows in view move more than `margin - slack` rows (now 8), and each move changes the liveness of about 9 rows at each end. A smaller margin (12, slack 8) moves the range after 4 rows and changes about 5 rows at each end.
    - The hosted tests note that SwiftUI can send no visibility report in the off-screen harness window. The RED run of the new hosted test must show if the rows lose their models in the harness.
  timestamp: 2026-11-23T20:44:00.065625+00:00
- actor: claude-code
  id: 01m852w2hkvw43wd3m7a0pbgnb
  text: |-
    TDD record:
    - RED hosted: ThreadModelCacheHostedTests.aScrollDownAndBackUpMakesNoNewModelForTheRowsAlreadySeen failed: 14 new models for 46 models already seen (300 answers with fences; mount, scroll to top, scroll to bottom, scroll to top).
    - RED unit: LiveRowRangeTests.aScrollOfOneRowAtATimeChangesTheLivenessOfFewRowsAtEachMove failed: 18 rows changed at one move (limit 10). CodeBlockModelCacheTests limit tests did not compile (no `init(limit:)`).
    - Fix: CodeBlockModelCache gets `init(limit: Int = .max)` with least-recently-used eviction (a read with model(for:) is a use). `CodeBlockModelCache.threadLimit = 256`. ConversationView reads `\.codeBlockModelCache` and gives its rows `hostModelCache ?? ownModelCache`. LiveRowRange margin 16 -> 8, slack 8 -> 4.
    - Not done: margin 12 / slack 8. The tests aScrollInTheSlackKeepsTheRange and aScrollPastTheSlackMovesTheRange require slack == margin / 2, so the step size can only get smaller with a smaller margin.
    - GREEN: new hosted suite 2/2 (0 new models); unit suites LiveRowRangeTests, CodeBlockModelCacheTests, LiveRowModelsTests, LiveRowStreamingTests 23/23.
    - aCacheOfTheHostGetsTheModelsOfTheRows and aCacheWithNoLimitKeepsEachModel guard old behavior; they pass also before the fix.
  timestamp: 2026-11-23T20:51:59.155037+00:00
- actor: claude-code
  id: 01m853bd7cn3hvc1a7sdbg7zh4
  text: |-
    ### implement — changed
    - evidence: headless `swift test` 1660 + 59 tests passed, 0 code warnings. `swift build --build-tests` in IntegrationTests and ScreenshotTests: exit 0, 0 code warnings. Hosted suites, one at a time, all passed: ThreadModelCacheHostedTests 2/2, ConversationViewHostedTests 12, ResponseViewHostedTests 5, CodeBlockViewHostedTests 12, LiveRowRangeRedrawScopeTests 1, SessionModelRedrawScopeTests 1, ThreadHeaderContextMenuHostedTests 5, ThreadAccessibilityHostedTests 13, ResponseStreamingHostedTests 1, SourcesViewHostedTests 12, ThreadMinimapViewHostedTests 11, AgentCommandScopeHostedTests 15, SessionTranscriptViewHostedTests 9, TranscriptSearchStepHostedTests 2, BodyEvaluationCounterTests 3. Before/after: 14 new models for 46 seen -> 0; largest liveness change of one range move 18 -> 10 rows.
    - not run: the screenshot gallery. The coordinator stopped all hosted and gallery runs because the user needs the computer. After that stop, I changed only docs and LiveRowModelsTests (headless, green); the hosted suites ran before that change.
    - open gap: the new hosted test scrolls with `ConversationViewHostedTests.jump` in both directions, and not with `scrollToTop` for the upward scroll as the card says. I did not change it because a changed hosted test could not run again after the stop.
    - files: ARCHITECTURE.md; Sources/AgentViewKit/Code/CodeBlockModelCache.swift, Code/CodeBlockView.swift, Content/RenderedMarkdownView.swift, Content/ResponseView.swift, Thread/ConversationView.swift, Thread/LiveRowRange.swift; Tests/AgentViewKitTests/Code/CodeBlockModelCacheTests.swift, Thread/LiveRowRangeTests.swift, Thread/LiveRowModelsTests.swift; new IntegrationTests/Tests/IntegrationTests/Thread/ThreadModelCacheHostedTests.swift.
    - next: run the gallery when the computer is free; /review.
  timestamp: 2026-11-23T21:00:21.612061+00:00
position_column: doing
position_ordinal: '80'
title: Keep the EditorKit models of thread rows in a thread-level cache so rows that come back do not rebuild
---
## Rule
Stay with SwiftUI and use it smarter. Do not replace views with AppKit.

## What
Bug: "scrolling is not very smooth in the agent view" (seen in TestudoApp). Rows that come back into the live range make new EditorKit models in batches.
- Sources/AgentViewKit/Thread/LiveRowRange.swift:23 `margin = 16`, :31 `slack = 8`, :47-51 `noteVisible` moves the range in large steps.
- Sources/AgentViewKit/Content/ResponseView.swift:218-227 shows a placeholder when the row is not live; the editor then leaves the tree.
- Sources/AgentViewKit/Content/RenderedMarkdownView.swift:91 and Sources/AgentViewKit/Code/CodeBlockView.swift:45 keep the model in `OwnModelSlot` (@State). The slot goes away with the view, so a row that comes back makes a new model.
- TestudoApp does not set `\.codeBlockModelCache` (Sources/AgentViewKit/Code/CodeBlockModelCache.swift).
- Fix: ConversationView (Sources/AgentViewKit/Thread/ConversationView.swift, near :309) sets a thread-level `CodeBlockModelCache` by default when the host does not give one. Then a row that leaves the range keeps its model. Also move the range in smaller steps (examine smaller margin/slack values).

## Acceptance Criteria
- [x] Without a host cache, ConversationView gives one cache to all rows.
- [x] A host cache still wins over the default.
- [x] Scroll down and back up makes 0 new models for rows already seen.

## Tests
Write the tests first.
- Add a DEBUG `BodyEvaluationCounter` key in the make-model paths of RenderedMarkdownView and CodeBlockView.
- New hosted test in IntegrationTests/Tests/IntegrationTests/Thread/: host 300 answers with fences, scroll down and back up with the helpers `scrollToTop` and `jump` in ConversationViewHostedTests.swift:264-289, assert 0 new models on the way back.
- Run `swift test` in the root (headless). Run the hosted test alone: `cd IntegrationTests && swift test --filter <TestName>`. One hosted test at a time.
- No sleep, poll, retry or time limit. Wait only on certain events.

## Workflow
Use /tdd.

## Subtasks
- [x] Add the DEBUG make-model counter keys.
- [x] Add the hosted test (it fails first).
- [x] Set a default thread-level cache in ConversationView.
- [x] Make the range move in smaller steps; keep LiveRowRange unit tests green.
- [x] Make the hosted test pass.

Files: ConversationView.swift, LiveRowRange.swift, RenderedMarkdownView.swift, CodeBlockView.swift, one new test file. #scroll-perf