---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7yvsdzjhx5z4wawh6ax96rd
  text: |-
    ### Integration job hang — facts (2026-11-21)
    - Run 44863705973, job 136741707622, commit dda19651. Runner: m3u1.
    - The step "Run the selected integration tests" started at 05:32:39 UTC. The job was cancelled at 08:28:55 UTC (duration 10,575 s). I did not cancel it: it was already cancelled when I looked.
    - The last test event is at 05:34:48 UTC. 40 tests started and did not end. The last ones: aSubmitPassesTheAttachmentsAndClearsTheRow(), theFocusedInspectorShowsItsScopeRing(), aLandingOnTheCardWhileTheCommentFieldHasTheFocusFocusesTheCard(landing:), aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:).
    - From 05:34:48 to 08:28:51 UTC, the log shows only one line, about 6 times each second (66,138 lines in all): "info FoundationModelsCodeContext.index: [FoundationModelsExtras] enter FoundationModelsCodeContext.index.pass". The first one is at 05:33:29 UTC.
    - No AgentViewKit source or test uses FoundationModelsCodeContext. The line comes from a dependency, possibly the real agent that an integration test starts.
    - This is not the same as the EditorKit hang (font server): here a process continues to write the index log.
    - At the cleanup, the runner stopped the orphan processes swiftpm-testing (22393) and swift-package (21717).
    - Next: the user decides if the runners get a restart of fontd. Then run the job again. The card stays open.
  timestamp: 2026-11-21T10:52:45.938671+00:00
- actor: claude-code
  id: 01m7yvwrdawq8x22fh0jzjqw3r
  text: |-
    ### Integration job hang — the last lines before the stop (2026-11-21)
    - FoundationModelsExtras says that the "index.pass" lines are an idle poll of each CodeContext (300 ms sleep). They do not block the tests. They are only noise after the stop.
    - The log lines at 05:34:48 UTC are one flush of the output. Their own time stamps are 05:34:45 to 05:34:46 UTC. After log line 18589, the log has no other line than "index.pass", up to the cancel at 08:28:55 UTC.
    - The last lines that are not "index.pass" (log lines 18565 to 18589):
      - 05:34:46 rpc.method=session/close session.id=scripted-session.
      - aFocusedViewWithASurfaceShowsNoScopeRing(surface:) passed. AttachmentCommandsHostedTests passed. theComposerShowsTheRowOnlyWhenItHasAttachments() passed.
      - aSubmitPassesTheAttachmentsAndClearsTheRow() started, then rpc initialize and session/new.
      - aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:) failed for kind .message at AgentItemFocusHostedTests.swift:168: the responder is EditorText.EditorInputTextView (472 x 16), not GeometryProbeView. This is the AgentItemFocus failure of the earlier red job 136420732846.
      - The case kind .toolCall of aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:) started, then rpc initialize and session/new. This is the last line.
    - Thus the process stopped during the case .toolCall of aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:), or during aSubmitPassesTheAttachmentsAndClearsTheRow(), both after session/new. The log does not show which test holds the stop. A timeout with stack samples (workflows 9b5f96b) is necessary to find it.
  timestamp: 2026-11-21T10:54:34.922476+00:00
- actor: claude-code
  id: 01m7ywp9qs6n0j7vamgy529x7b
  text: |-
    ### The index.pass lines — fix in a dependency (2026-11-21)
    - FoundationModelsCodeContext 90f3003 (main): the idle index loop runs a pass only when a file waits. Thus the "index.pass" lines go away from the Integration log.
    - AgentViewKit gets FoundationModelsCodeContext only as a dependency of a dependency (through Multitool). Package.resolved is not tracked, thus CI resolves the newest main on each run.
    - This fix does not fix the stop of the tests. The 30-minute timeout with the stack sample (d2b5ffb3) shows the cause on the next run.
  timestamp: 2026-11-21T11:08:31.865809+00:00
- actor: claude-code
  id: 01m7zzcdayf6vdnk24qk8gkx27
  text: |-
    ### Integration run with the 30-minute limit (2026-11-21)
    - Run 44906413428, job 136859513205, commit 59d61e00, runner m3u1. The test step ran 13:38:54 to 13:59:00 UTC. At 13:58:55 the job sampled the process swiftpm-testing-helper (pid 32768) and stopped it. Artifact: integration-hang-samples (local copy: scratchpad/hang/32768.txt).
    - The same tests fail as in job 136420732846 (about 18): AgentItemFocus (theFirstResponderCoversAFocusedItem, theBeaconOfAnItemWithNoFocusableViewHoldsTheFocus .message), TranscriptSearchStep escape, AgentRowListRename (3, textView.string == text), accessibility text labels (compaction summary, agent message chunks, wire text block, math, linked blocks, Markdown attachment "json"), ThreadHeaderContextMenu empty part, ThreadBarBannerOverlap, submit hook mentions.
    - After about 13:41 no test event comes until the sample. The main thread does not block: it waits in the run loop (OutermostRunLoopGuard.runAgain, OutermostRunLoopGuard.swift:83, mach_msg) and gets no event. The other threads are idle: the CodeContext index loop (GRDB reader, Store.drainLspDirty) and the cooperative pool. Thus one test awaits an event that never comes. It is not a deadlock and not the font server.
    - The output of Swift Testing is buffered, so the start times do not show which test waits. 20 tests started and did not end before 13:41. Tests that are open in both hangs (job 136741707622 and this job): aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:) (in both runs, the .message case of an AgentItemFocus test fails just before the stop), theFocusedInspectorShowsItsScopeRing(), aSubmitPassesTheAttachmentsAndClearsTheRow(), aJumpOnTheCardFocusesTheCardAndNotItsCommentField(), aSubmitAttemptShowsTheErrorOfEachFieldThatIsNotValid().
    - Next: find the await with no bound in those tests (for example in AgentScopeSubjectHostedTests.sendScopeToolCall, used by the .toolCall case after the .message case fails), and fix the failing tests.
  timestamp: 2026-11-21T21:14:48.030177+00:00
- actor: claude-code
  id: 01m7zzwh9erref7zr3avg9111m
  text: |-
    ### Research for the hang and the failures (2026-11-21)
    - The hosted tests have 117 calls of `ObservationWait.until(_:)` with no bound (IntegrationTests and AgentViewKitTestSupport). Also 189 calls of `harness.render { … }`. These calls go to EditorKit `HostedViewHarness.render(when:)`, which calls `ObservationWait.until(_:)` with no bound. The default `render(when:)` of the AVK protocol `RenderedMount` is never used: the method of `HostedViewHarness` is the witness.
    - Other unbounded waits: `await task.value` on test tasks (about 10), one `withCheckedContinuation` in AgentAuthViewHostedTests, and the `for await` loop of `TurnAnnouncementFixtures.announcements`.
    - EditorKit gives the bounds: `BoundedWait.defaultBound` (30 s), `BoundedWait.next(before:)` and `ObservationWait.until(within:)`.
    - EditorKit b4c60286 found the same kind of hang in EditorKit: a wait on a value that is not observable (`NSTextView.string`) never wakes. One of the open tests can have the same defect.
    - The same failures are in the Integration log of 2026-11-20 17:21 (EditorKit 409d360), before 4127c353. Thus 4127c353 is not the first cause of the AgentItemFocus `.message` failures. The last green Integration job is on 429cda80 (2026-11-13).
  timestamp: 2026-11-21T21:23:36.366263+00:00
- actor: claude-code
  id: 01m800vg5dy9nb9kme755tr3t2
  text: |-
    ### Hang: each event wait now has a bound (2026-11-21)
    - `RenderedMount.renderAfter(within:sourceLocation:_:)` (IntegrationTests/Helpers/RenderedMount.swift) replaces each call of EditorKit `HostedViewHarness.render(when:)` (187 calls). It calls `ObservationWait.until(within: BoundedWait.defaultBound)` (30 s), then `RunLoopBlockFence.afterPendingBlocks()`, then `render()`. A grep for `.render {` and `.render(when:` now finds 0 calls.
    - Each `ObservationWait.until { }` in IntegrationTests and AgentViewKitTestSupport is now `ObservationWait.until(within: BoundedWait.defaultBound) { }` (114 calls).
    - New `Task.boundedValue(within:sourceLocation:)` (Sources/AgentViewKitTestSupport/BoundedTaskValue.swift) for the 9 `await task.value` in hosted tests. At the bound it records an issue, cancels the task and throws `BoundedTaskError.noEnd`.
    - `TurnAnnouncementFixtures.collect` reads the stream in a task with a bound, and it now throws. The parse wait of `ResponseTextChecks.renderParsed` has a bound.
    - Not changed: the `withCheckedContinuation` in AgentAuthViewHostedTests is a fake of production that waits for a cancel, and no test awaits it. `waitForLiveBeacons` and `settle(until:)` are polls of EditorKit that already have a timeout. The unit tests in Tests/ (not hosted) keep their unbounded waits (out of scope).
    - I could not find the one wait that hung, because the output is buffered. With the bounds, the next run gives a failed test with the issue "the change never came", at the line of the wait, and not a hang. EditorKit b4c60286 found a hang of the same kind: a wait on a value that is not observable.

    ### Failing hosted tests: cause and fix
    - TranscriptSearchStep findNextHitRunsInAMountedThreadWithHits, escapeInAMountedThreadWithHitsRemovesTheHitsOfTheHost. Cause: the harness gives the focus to its first key view (EditorKit HostedViewHarness `selectKeyView(following:)`), the composer text view. The find verbs are off in a text input on purpose (D133), so perform and Esc give false. The test is stale (ee9fb3fa, cfd868cb, never run in CI). Fix: `showHits` takes the focus out with `makeFirstResponder(nil)` and requires it.
    - AgentRowListRename (3 tests). Cause: each field starts with the row id ("second"); "x" goes in at the caret and gives "xsecond". The test is stale (6b2b7364, never run). Fix: `rename(thenPress:)` types with `replacingAllText: true`. The later checks (D197 b keys) never ran; the next run shows them.
    - AgentItemFocus `.message` (theFirstResponderCoversAFocusedItem nav/jump, theBeaconOfAnItemWithNoFocusableViewHoldsTheFocus nav/jump, aFocusedItemWithNoSurfaceShowsItsScopeRing .message). Cause: AVK a92da599 (2026-11-17) shows the text of a message in a read-only, selectable EditorView. EditorKit GeometryProbeView.requestFocus(yieldingTo:) gives the item focus to that text view (472x16), not to the beacon. This is a production regression (the same symptom as EditorKit 905d321a). 4127c353 is not a cause: its guard needs an empty transcript and a composer. Not fixed here: it needs an EditorKit change. New task ^6386krf.
    - CompactionAndNotice aSummaryChunkBeforeAnyUpdateShowsNoStatusYetAndTheSummary, SessionEntryRows aCompactionSummaryShowsTheACPContentOfTheModel, MessageViews anAgentMessageEntryShowsEachBlockAndASecondChunkChangesTheText, WireContentBlockView aWireTextBlockShowsItsText. Cause: since a92da599, text is in the value of an NSTextView element, not in a label. The tests are stale. Fix: the tests read the value (`ResponseTextChecks.texts` or `value`); the MessageViews helper is now `showsText`.
    - ThreadAccessibility anAnswerReadsItsMathAtItsPlaceAndKeepsTheMathElement. Text check: EditorKit 3b665069 and 4148b295 speak math as "Math, x^2" on purpose; the test is stale; fix: it expects `EditorSwiftUIStrings.renderedWidgetSpokenText(label: mathLabel, value: "x^2")`. Docs/decisions/accessibility.md and the RenderedMarkdownView comment changed to match. Value check (formula value nil): probably EditorKit `MathWidget` has no static text trait; not fixed here, task ^6386krf.
    - ThreadAccessibility theTextsOfTheBlocksOfOneMessageLinkEachOther. Cause: since a92da599, the SwiftUI linked group does not reach the hosted NSTextView, and EditorKit has no API for it. Production gap; not fixed here, task ^6386krf.
    - AttachmentTextContent aMarkdownAttachmentShowsTheRenderedForm. Cause: the fence header comes from the syntax tree, after an async parse; the test read it after one render. The test is stale. Fix: the header check is now its own test, theFenceOfRenderedMarkdownShowsItsLanguageInItsHeader, with a model that it keeps and a bounded wait for the parse.
    - ComposerCompletionRoutes theSubmitHookGetsTheMentionsBeforeTheTextClears. Cause: the link of an accepted mention comes to the composer through the async commit stream; the test pressed Return in the same step, before the link was in the draft. The test is stale (d1ce3b05, never run). Fix: a bounded wait until the draft text holds the link, before the submit.
    - ThreadHeaderContextMenu theEmptyPartOfTheHeaderShowsTheContextMenuOfTheHostPath. New test (af0b24c8), never green. I could not find the cause without a hosted run. Hypothesis: the `.contentShape` is on the inner line, not on the view that has `.hostPathContextMenu` (AgentThreadView `topBarParts`). Next: one run that logs the hit-test view at the point.
    - ThreadBarBannerOverlap theLastRowAtRestIsAboveTheBannersOfTheBottomBar. A regression after 429cda80 (the last row is 27.5 pt under the bar). I could not find the cause without a hosted run. Hypothesis: row heights change after the async parse (a92da599), and this test does only two synchronous render passes.

    ### Checks
    - `cd IntegrationTests && swift build --build-tests`: success, 0 errors, 0 warnings (EditorKit 621c702).
    - `swift test` (root): 1586 tests in 180 suites and 54 tests in 11 suites passed.
    - `swift format lint --strict` on the 85 touched Swift files: 0 findings (the files are formatted with `swift format -i`, so the diff also holds layout changes).
    - I did not run the hosted suites.
  timestamp: 2026-11-21T21:40:31.021385+00:00
- actor: claude-code
  id: 01m800vwy3bxeevzjeba7f5v59
  text: |-
    ### implement — changed
    - evidence: 87 tracked files plus 1 new file (Sources/AgentViewKitTestSupport/BoundedTaskValue.swift). Main files: IntegrationTests/Tests/IntegrationTests/Helpers/RenderedMount.swift, Helpers/ResponseTextChecks.swift, Thread/TranscriptSearchStepHostedTests.swift, Lists/AgentRowListRenameHostedTests.swift, Input/ComposerCompletionRoutesHostedTests.swift, Attachments/AttachmentTextContentHostedTests.swift, Accessibility/ThreadAccessibilityHostedTests.swift, Items/CompactionAndNoticeHostedTests.swift, Items/SessionEntryRowsHostedTests.swift, Items/MessageViewsHostedTests.swift, Content/WireContentBlockViewHostedTests.swift, Sources/AgentViewKitTestSupport/TurnAnnouncementFixtures.swift, Sources/AgentViewKit/Content/RenderedMarkdownView.swift (comment only), Docs/decisions/accessibility.md, and the bounded-wait edits in about 75 hosted test files. `swift build --build-tests` (IntegrationTests) passed; `swift test` passed 1586 + 54; lint 0 findings. Hosted suites not run.
    - open: 5 tests are not fixed. 3 need EditorKit (task ^6386krf): AgentItemFocus `.message`, the math value, linked text. 2 need a hosted run to find the cause: ThreadHeaderContextMenu empty part, ThreadBarBannerOverlap.
    - next: /review, then a CI Integration run.
  timestamp: 2026-11-21T21:40:44.099235+00:00
- actor: claude-code
  id: 01m801y8th2ngwpx2b92yttk26
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (676308b0): engine 20 confirmed, 31 refuted. 19 dropped by the written rule (refactor of tests that existed before). 1 open: IntegrationTests/Tests/IntegrationTests/Helpers/ComposerHarness.swift:92 (completeness/invariant-propagation).
    - next: Fix the open finding. The task stays in Review: 5 hosted tests are not fixed, and CI on main is not green.
  timestamp: 2026-11-21T21:59:30.385399+00:00
- actor: claude-code
  id: 01m801yvttewy9thgmztyacm7m
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 88 files (bounded waits in the hosted tests; 16 stale hosted tests fixed; 5 open: 3 on ^6386krf, 2 need a hosted run)
    - test: green — swift test, 1586 tests in 180 suites and 54 tests in 11 suites passed; IntegrationTests and ScreenshotTests build passed (not run)
    - commit: 676308b0
    - review: findings — IntegrationTests/Tests/IntegrationTests/Helpers/ComposerHarness.swift:92 (19 others dropped by the written rule for old tests)
  timestamp: 2026-11-21T21:59:49.850056+00:00
- actor: claude-code
  id: 01m802623dz9a30qbbm5yypawm
  text: |-
    Implement pass for the finding at ComposerHarness.swift:92 (sourceLocation of the bounded wait).

    Research: A script examined each func in IntegrationTests, ScreenshotTests and Examples that has a `sourceLocation: SourceLocation` parameter, and found each bounded wait call in its body (ObservationWait.until(within:), renderAfter, boundedValue, BoundedWait). Two calls did not send the location of the caller:
    - `ComposerHarness.typePrompt`: `ObservationWait.until(within: BoundedWait.defaultBound)`.
    - `SingleLineFieldChecks.expectAnswerTakesTheTypingOffTheUndoStack`: `window.harness.renderAfter(requestIsGone)`.
    Each bounded wait helper (`RenderedMount.renderAfter`, `Task.boundedValue` in AgentViewKitTestSupport, EditorKit `ObservationWait.until(within:sourceLocation:)`) already has a `sourceLocation` parameter, so no helper signature changed. `ComposerWindowUndoHostedTests.performWhileAvailable` (called by `SingleLineFieldChecks.typeAndUndoAll`) has no bounded wait (it uses the unbounded `waitUntilIdle`) and no `sourceLocation` parameter, so it is out of scope.

    Change: both calls now send `sourceLocation: sourceLocation`.

    TDD note: no failing test was written first. The change is only the location of an issue in hosted test helpers, and the hosted suites are not run locally (user rule). The build of the hosted test tree checks that the code compiles.
  timestamp: 2026-11-21T22:03:45.645446+00:00
- actor: claude-code
  id: 01m80264mhya980ea99z8ceabc
  text: |-
    ### implement — changed
    - evidence: 2 files — IntegrationTests/Tests/IntegrationTests/Helpers/ComposerHarness.swift, IntegrationTests/Tests/IntegrationTests/Helpers/SingleLineFieldChecks.swift. `swift test` (root, headless): 1586 tests in 180 suites passed, and 54 tests in 11 suites passed, rc=0. `cd IntegrationTests && swift build --build-tests`: Build complete, 0 errors. `swift format lint --strict` on the 2 files: 0 findings. The finding at ComposerHarness.swift:92 is flipped to [x]. Hosted suites not run (user rule).
    - next: /review. The task stays in doing.
  timestamp: 2026-11-21T22:03:48.241984+00:00
position_column: doing
position_ordinal: '80'
title: Integration CI job on main is red (run 44757895393, a60d101a)
---
Request from testudoapp-9a (2026-11-20). Job "Integration (opt-in, real dependencies)" on mini-01 failed. The user cleared the runner screens, and the job runs again (rerun started 2026-11-20).

Failures:
- `TranscriptSearchStepHostedTests.swift:86` findNextHitRunsInAMountedThreadWithHits: `registry.perform(findNextHit)` is false.
- `ThreadBarBannerOverlapHostedTests.swift:84` theLastRowAtRestIsAboveTheBannersOfTheBottomBar.
- `AttachmentTextContentHostedTests.swift:23` aMarkdownAttachmentShowsTheRenderedForm.
- `ThreadAccessibilityHostedTests.swift:223` theTextsOfTheBlocksOfOneMessageLinkEachOther.
- `AgentItemFocusHostedTests.swift:149` theFirstResponderCoversAFocusedItem(kind: .message, landing: .nav).

Do:
- Read the result of the rerun. For each failure that stays, find the cause from the CI log and the code, and fix it. The hosted suites are not run locally; CI checks them.
- Push, and send the sha and the CI result to testudoapp-9a.

## Review Findings (2026-11-21 15:43)

> Scope: `review sha HEAD~1..HEAD` (676308b0). The review examined only the lines that the change added or changed. 85 files were examined. 4 files in `.kanban/` were not examined (ignore rule). `Docs/decisions/accessibility.md` was not examined (no validator applies).

- [x] `IntegrationTests/Tests/IntegrationTests/Helpers/ComposerHarness.swift:92` `completeness/invariant-propagation` — The bounded wait for the typed value does not send the sourceLocation of the caller. `typePrompt` has a `sourceLocation` parameter, and the goal of this change is that a missing event fails the test at the line of the test. The other waits in this change send the location, so this wait is not the same as them. When the bound expires here, the tool records the issue at the line of the helper, not at the line of the test that called `typePrompt`. Send the location of the caller: `await ObservationWait.until(within: BoundedWait.defaultBound, sourceLocation: sourceLocation) { typed() == prompt }`. Then a timeout shows at the line of the test that called the helper. Do this for each bounded wait in a helper that has a `sourceLocation` parameter.

> 19 other findings are dropped. The written rule of the review skill drops findings that ask to refactor tests that existed before. Each test, helper and duplicate wait in these findings was in the code at HEAD~1. This change only added a bound (`within: BoundedWait.defaultBound`) or changed the format on these lines. The dropped findings are at these locations:
> - `Commands/AgentCommandScopeHostedTests.swift:394` (duplication)
> - `Config/ConfigOptionsSessionModelHostedTests.swift:213`, `:439`, `:472` (reuse)
> - `HumanInTheLoop/PermissionViewHostedTests.swift:320` (reuse)
> - `HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift:94` (reuse)
> - `Input/AttachmentChipsHostedTests.swift:293` (duplication)
> - `Input/ComposerCompletionRoutesHostedTests.swift:331`, `:535` (duplication)
> - `Input/ComposerDraftHostedTests.swift:181` (duplication)
> - `Input/ComposerEditorMenuHostedTests.swift:143` (duplication)
> - `Input/ComposerSessionModelHostedTests.swift:394`, `:450` (duplication)
> - `Input/EditorKitPromptEditorHostedTests.swift:60` (duplication, reuse), `:198` (duplication)
> - `Input/PromptInputViewHostedTests.swift:234` (duplication)
> - `Items/MessageActionsHostedTests.swift:215` (test-integrity/no-test-cheating; the test and its expected value were at HEAD~1, and this change only changed the format of the line)
> - `Thread/ThreadBottomBarHostedTests.swift:57` (reuse)

> Status: This task stays open in Review. It is not done. 5 hosted tests are not fixed, and CI on main is not green.