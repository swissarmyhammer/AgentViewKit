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
- actor: claude-code
  id: 01m853g5wb0y6v76wme51jp6r9
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (461c37a6): 1 finding (1 confirmed, 1 refuted) — Sources/AgentViewKit/Code/CodeBlockView.swift:121 duplication/duplication.
    - next: implement the finding (one shared counted make-model function for CodeBlockView and RenderedMarkdownView). Then run the screenshot gallery when the computer is free. The gallery run is also an open item. The task stays in review.
  timestamp: 2026-11-23T21:02:57.931752+00:00
- actor: claude-code
  id: 01m853gwpmkx19dncgz1pfcakm
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 11 files
    - test: green — swift test 1660 + 59; 15 hosted suites (before the screen stop)
    - commit: 461c37a6
    - review: findings — Sources/AgentViewKit/Code/CodeBlockView.swift:121
  timestamp: 2026-11-23T21:03:21.300242+00:00
- actor: claude-code
  id: 01m853sbj9wn1hfmdp6pytzw1z
  text: |-
    Fix of the duplication finding at Sources/AgentViewKit/Code/CodeBlockView.swift:121:
    - Added two functions to the EditorModel extension in Sources/AgentViewKit/Code/CodeBlockModelCache.swift: `makeCountedReadOnly(_:keyPrefix:)` holds the `#if DEBUG` BodyEvaluationCounter note and returns `makeReadOnly(text)`. `readOnlyCounterKey(for:keyPrefix:)` is the one key format, `<keyPrefix><text>`.
    - CodeBlockView.makeModel and RenderedMarkdownView.makeModel now call `makeCountedReadOnly` with their prefix constants. RenderedMarkdownView sets `presentation = .rendered` on the returned model.
    - The two `modelCounterKey(for:)` functions are now one-line calls to `readOnlyCounterKey`. The prefixes and the keys did not change, so ThreadModelCacheHostedTests uses the same keys.
    - New unit tests: Tests/AgentViewKitTests/Code/CountedReadOnlyModelTests.swift (4 tests). RED was a compile failure (members missing). GREEN after the change.
    - swift test: 1664 + 59 tests pass, no code warnings. swift build --build-tests is complete in IntegrationTests and ScreenshotTests. No hosted suite ran (the user needs the screen).
    - Finding flipped to - [x].
  timestamp: 2026-11-23T21:07:58.665386+00:00
- actor: claude-code
  id: 01m853sdqcxcrw6x6wa15hgke5
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Code/CodeBlockModelCache.swift, Sources/AgentViewKit/Code/CodeBlockView.swift, Sources/AgentViewKit/Content/RenderedMarkdownView.swift, Tests/AgentViewKitTests/Code/CountedReadOnlyModelTests.swift; swift test 1664 + 59 pass; build-tests complete in IntegrationTests and ScreenshotTests
    - next: test, then review
  timestamp: 2026-11-23T21:08:00.876067+00:00
- actor: claude-code
  id: 01m853wf3rafrhga04wexmt41a
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (ec04b89e): 0 findings (0 confirmed, 0 refuted; 7 attempted, 0 failed). 4 files reviewed. All prior review items are checked.
    - next: run the screenshot gallery when the computer is free. The gallery run is the last open item. The task stays in review until the gallery run is done.
  timestamp: 2026-11-23T21:09:40.600066+00:00
- actor: claude-code
  id: 01m86sccnrza8yvgrkjtjynw8c
  text: |-
    ### review — clean
    - evidence: no new review. The newest code range of this card is ec04b89e (review sha HEAD~1..HEAD). It has a clean review record: 0 findings. The later commit cba06915 changes only the kanban files of this card. All 10 items are checked. The screenshot gallery run passed on 2026-11-24 05:37 (46 tests). CI 45311745699 is green.
    - next: none. The card moves to done.
  timestamp: 2026-11-24T12:44:36.920843+00:00
position_column: done
position_ordinal: ffffffffa180
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

## Review Findings (2026-11-23 15:01)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 10 file(s) reviewed, 3 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Code/CodeBlockView.swift:121` `duplication/duplication` — The new static function `makeModel` repeats the debug counter pattern of `RenderedMarkdownView.makeModel`: a `#if DEBUG` call to `BodyEvaluationCounter.note` with a key from a prefix constant and a `modelCounterKey(for:)` helper, then a call to `EditorModel.makeReadOnly`. Two copies of this scheme can drift, for example when one key format changes and the other does not, and the counts in the tests then stop matching. Extract one shared function in an `EditorModel` extension, for example `static func makeCountedReadOnly(_ text: String, keyPrefix: String) -> EditorModel`. It holds the `#if DEBUG` note of `keyPrefix + text` and then returns `makeReadOnly(text)`. `CodeBlockView.makeModel` and `RenderedMarkdownView.makeModel` each call it with their own prefix constant. `RenderedMarkdownView` then sets `presentation = .rendered` on the returned model. Remove the duplicated `modelCounterKey(for:)` bodies, or make them one-line calls to the shared helper.
