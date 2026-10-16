---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m52qe6wvacp2v12227h1gtd6
  text: |-
    ### Order decision (step owner, with ^nmy2ctx)
    - Condition of the step owner: if a test of the 13 paths waits after its press for an event that can fail to come, this card comes right after card 40 (^b94apm2), not after card 41.
    - Answer: yes. Example: ComposerSessionModelHostedTests.swift:362-363 (theStopButtonSendsSessionCancel) presses Stop and then does `await ObservationWait.until { !session.agent.messages(method: ScriptedSession.cancelMethod).isEmpty }`. ObservationWait.until (Sources/AgentViewKitTestSupport/ObservationWait.swift:20-24) loops until the predicate is true, with no other exit. If the Stop handler breaks, no cancel frame comes, and the test waits without end. The Fact list above says the same for each path.
    - Thus: do this card right after card 40, before card 41.
  timestamp: 2026-10-16T16:06:36.187433+00:00
- actor: claude-code
  id: 01m52xr1yskb609s5kh8akmq0p
  text: |-
    ### Research and design (implement step)
    - Fact: SessionModel is a type of the external package FoundationModelsACPClient. An extension cannot add a stored report to it. Thus the proof goes through the environment, as permissionAnswerReport and promptSubmitReport do.
    - One new internal environment value, requestStartReport (ObservationReport of String), in SessionModel+Requests.swift. The kit start functions startRequest, startCancel, startSetConfigOption, makeConfigBinding, startSelectPermission and startPrompt(content:) get an optional "reporting" parameter (default nil). Each function calls the report with the ACP method in the same step, before it starts its Task.
    - Views that pass the report: DefaultPromptAccessory (Stop), PromptInputView.cancel (Esc with no command scope), ConfigOptionControl (toggle and choice), PermissionView.switchToAuto (two reports), MessageActions.retry, SessionStreamBanner (Reload). AgentCommandScope gives the environment value to AgentCommandTarget (new var requestStartReport), and the cancel verb passes it to startCancel.
    - New internal report imageSelectReport (ImageView, the file name, before the write task).
    - New internal report sessionListPressReport (SessionListView, the identifier of the pressed button). A new private start(_:_:) helper reports and starts the Task for Refresh, Load More, resume row and delete.
    - New internal report elicitationBrowserReport with enum ElicitationBrowserStep (open, stop) in ElicitationURLConsentView: openBrowser reports open before the Task; cancel reports stop when it stops a browser task.
    - Test files that used a plain import of AgentViewKit and now need the internal values get the testable import: ComposerSessionModelHostedTests, SessionEntryRowsHostedTests, SessionStateBannersHostedTests, ElicitationURLConsentViewHostedTests.
    - Command tests: only the cancel command uses a handler of the Fact list (startCancel). The send, approve and reject commands use startPrompt(text:) and answerPermission, which are not in the Fact list. This step does not change them.
  timestamp: 2026-10-16T17:56:50.265657+00:00
- actor: claude-code
  id: 01m52y9n6m7aaqwfpryanjqea8
  text: |-
    ### implement — changed
    - evidence: 13 Sources files and 12 test files changed (git diff: 27 files with the 2 card files, 373 insertions, 76 deletions). No public API change. All new values are internal.
    - Handler and proof:
      - PermissionView.switchToAuto: requestStartReport gets session/request_permission then session/set_config_option. Test switchToAutoAllowsThenSetsTheMode.
      - DefaultPromptAccessory Stop: requestStartReport gets session/cancel. Test theStopButtonSendsSessionCancel.
      - PromptInputView Esc (cancel with no scope, and AgentCommandTarget cancel in a scope): session/cancel. Test escapeStopsTheRunningTurn.
      - ConfigOptionControl toggle and choice (makeConfigBinding then startSetConfigOption): session/set_config_option. Tests aChangeSendsSetConfigOption..., changingAToggleSendsABooleanValue, selectingTheCurrentValueSendsNothing (empty after the current value, one value after the fence), aFailedCallKeepsTheModelValue..., and SessionEntryRowsHostedTests aConnectionThatClosesBeforeTheAnswer...
      - ImageView tap: imageSelectReport gets the file name before the write task. Test aPressOnAWireImageSelectsItsBytesInTheInspector.
      - MessageActions Retry: session/prompt. Test retryOnAnAgentEntrySendsTheContentOfTheEarlierUserEntry.
      - SessionStreamBanner Reload: session/resume. Tests anOverflowShowsTheMissedUpdatesBanner... and reloadSendsTheWorkingDirectory...
      - SessionListView Refresh, Load More, resume row, delete (new private start helper): sessionListPressReport gets the button identifier. Helper pressAndRenderTheCall, so the 6 picker tests that use it.
      - ElicitationURLConsentView Retry (openBrowser) and Cancel while waiting: elicitationBrowserReport gets open and stop. Tests retryOpensTheBrowserAgain... ([open, open]) and cancelWhileWaitingStopsTheBrowser... ([open, stop]).
      - Commands: the cancel verb calls startCancel, a handler of the Fact list, so dispatchingCancelSendsSessionCancel and theCancelCommandOfASessionSendsSessionCancelWhileTheAgentRuns require session/cancel. The send, approve and reject commands call startPrompt(text:) and answerPermission, which are not in the Fact list; this step did not change them.
    - Mutation run (one build with 10 mutations: each handler returns or skips before the report and the task; the Esc test had both PromptInputView.cancel and the target cancel verb broken): timeout 900 swift test --skip-build --filter of the 22 named tests. Result: 22 tests in 12 suites failed after 1.759 seconds, each at its new try require line. No hang. Sources restored from copies, cmp equal, no mutation text left.
    - Normal run: swift build --build-tests (no warning in Sources or Tests), then swift test --skip-build --filter of the 12 changed suites: 177 tests in 12 suites passed after 9.644 seconds.
    - Test files that now use the testable import: ComposerSessionModelHostedTests, SessionEntryRowsHostedTests (its doc comment that said the file has no testable import is changed), SessionStateBannersHostedTests, ElicitationURLConsentViewHostedTests.
    - next: review
  timestamp: 2026-10-16T18:06:27.028926+00:00
- actor: claude-code
  id: 01m52yj1kq0hnm1ve2rcvhr5zj
  text: |-
    ### test — green
    - No other build: pgrep showed one swift-build of FoundationModelsKanban (index build) and one swiftpm-testing-helper of FoundationModelsAgents. Neither belongs to this package.
    - Sources diff check: git diff -- Sources shows only the intended report changes. Each handler calls its report, then starts its Task. No early return before a Task. No mutation text found.
    - swift build --build-tests: Build complete, exit 0. One build-system warning only: "missing creator for mutated node" for the mlx-swift_Cmlx.bundle in .build/out. It is not in Sources/ or Tests/ of this package.
    - swift test --skip-build: exit 0. Swift Testing: 1258 tests in 147 suites passed, 0 failed, 0 skipped. XCTest: 0 tests, 0 failures.
    - Known issues: 2 (existing withKnownIssue marks): aWrappedTextWithAFixedVerticalSizeFails (HostedLayoutExpectationsTests.swift) and aViewThatIgnoresTheThemeFails (ThemeHeightExpectationsTests.swift).
    - Scripts/check-readme.sh: not run. README.md and Examples/ReadmeSnippets did not change.
    - No commit. No push.
    - next: review
  timestamp: 2026-10-16T18:11:01.879942+00:00
- actor: claude-code
  id: 01m52z46xvcy3a0hbz5akav21e
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD: engine 0 findings (28 attempted, 0 failed). The code reading found 7 findings of the same cause (the send, approve and reject command tests have no synchronous proof before a wait with no time limit): Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift:288, :307, :341, :530, :544; Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift:217, :326. The production change and the tests of the changed press paths pass the code reading: each report is set after the guards, in the same step, before the Task; each new parameter has the default nil; no public API changed.
    - next: give startPrompt(text:) and answerPermission(_:option:comment:) a reporting parameter, and require the report (or promptSubmitReport .sent) in each listed test after the dispatch and before the wait.
  timestamp: 2026-10-16T18:20:57.147843+00:00
- actor: claude-code
  id: 01m52z5pkxtqas31qe9y6jewse
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 13 source files (internal reports set before each Task), 12 test suites; mutation run: 22 of 22 named tests failed at once
    - test: green — swift test --skip-build, 1258 tests in 147 suites passed, 2 known issues
    - commit: 75bc2ae
    - review: findings — Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift:288, :307, :341, :530, :544; Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift:217, :326 (send, approve and reject commands have no synchronous proof)
  timestamp: 2026-10-16T18:21:45.981670+00:00
- actor: claude-code
  id: 01m52zqk3xsy49ekemdrdjbbpv
  text: |-
    ### Research (implement, iteration 2)
    - answerPermission(_:option:comment:) does not remove the request from the model in the same step. It starts a Task, and the Task calls selectPermission of the external SessionModel. Thus a require of the model state cannot be the proof, and the function needs the report.
    - startPrompt(text:) has one caller: AgentCommandTarget.send(payload:to:). answerPermission has the callers AgentCommandTarget.respond(payload:rejects:), PermissionView.answer(with:comment:) and two tests. The new parameter has the default nil, so the other callers do not change.
    - The composer path of the send command (no payload) calls the hook submit, and that is PromptInputView.submit(). That function already calls promptSubmitReport with .sent in the same step, before onSubmit. Thus the composer test needs only a test change: the mount helper of AgentCommandScopeHostedTests now takes a submitReport and puts it in the environment.
    - RED run before the production change: 6 of the 7 tests failed at the new require. The composer test passed, as expected, because the report already exists.
  timestamp: 2026-10-16T18:31:32.221694+00:00
- actor: claude-code
  id: 01m52zqw2g0vwhdjbdbta05ea5
  text: |-
    ### implement — changed
    - evidence: 6 files (no public API change, all internal): Sources/AgentViewKit/Input/SessionModel+Requests.swift (startPrompt(text:reporting:) and answerPermission(_:option:comment:reporting:) call the report after the guards, in the same step, before the Task; default nil), Sources/AgentViewKit/Commands/AgentCommandTarget.swift (send and respond give requestStartReport; doc of requestStartReport and respond), Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift (doc name only), Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift (5 tests require starts.values after the dispatch), Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift (mount takes submitReport; the composer test requires [.sent]; the approve test requires session/request_permission), Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift (doc name only).
    - Mutation run: one build with 3 mutations (startPrompt(text:) and answerPermission return before the report and the Task; PromptInputView.submit returns after its guard, before startPrompt and the .sent report). timeout 900 swift test --skip-build --filter of the 7 named tests: 7 tests in 2 suites failed after 0.389 seconds, each at its new try require line (AgentCommandsTests.swift:292, :315, :353, :546, :564; AgentCommandScopeHostedTests.swift:226, :339). No timeout. Sources put back from copies, cmp equal, no mutation text left; git diff -- Sources shows only the intended changes.
    - Normal run: swift build --build-tests (only the known build-system warning for mlx-swift_Cmlx.bundle in .build/out; none in Sources or Tests), then swift test --skip-build --filter 'AgentCommandsTests|AgentCommandScopeHostedTests|PendingRequestsSessionModelHostedTests|PermissionViewHostedTests': 67 tests in 4 suites passed after 7.866 seconds.
    - All 7 Review Findings are checked. No commit, no push. The task stays in doing.
    - next: review
  timestamp: 2026-10-16T18:31:41.392860+00:00
- actor: claude-code
  id: 01m52zz7z550xdbbt778nb06m6
  text: |-
    ### test — green
    - conflict check: no swift-build for tests and no swift test of this package ran. Only IDE index builds ran (index-build), and one test helper of another package (FoundationModelsAgents).
    - Sources diff: only the report changes. The report call comes before the Task in startPrompt and answerPermission. No mutation text stays in Sources.
    - swift build --build-tests: Build complete, 0 warnings in Sources or Tests. One build system message about the mlx-swift_Cmlx bundle is not from this package code.
    - swift test --skip-build: Swift Testing 1258 tests in 147 suites passed, 0 failed, 0 skipped. 2 known issues (existing withKnownIssue marks: aWrappedTextWithAFixedVerticalSizeFails, aViewThatIgnoresTheThemeFails). XCTest ran 0 tests, 0 failures.
    - README.md and Examples are unchanged, so check-readme.sh did not run.
    - next: review
  timestamp: 2026-10-16T18:35:42.949077+00:00
position_column: doing
position_ordinal: '80'
title: Give a synchronous proof to the press paths that answer only in a task, so that their hosted tests cannot wait without end
---
Found during ^nmy2ctx. Write all text in STE.

## Fact
- These hosted tests do a press or a key, and then wait for an agent frame or a model change. The handler of the press only starts a Task, and no model state changes in the same step. Thus a broken handler makes the wait go on without end. The only synchronous proof now is that `HostedViewHarness.press(identifier:)` did not throw (the press action ran).
  - PermissionViewHostedTests/switchToAutoAllowsThenSetsTheMode (switchToAuto starts two tasks, and does not call permissionAnswerReport)
  - ComposerSessionModelHostedTests/theStopButtonSendsSessionCancel and EditorKitPromptEditorHostedTests/escapeStopsTheRunningTurn (SessionModel.startCancel)
  - ConfigOptionsSessionModelHostedTests (the toggle and choice presses: startSetConfigOption) and SessionEntryRowsHostedTests/aConnectionThatClosesBeforeTheAnswerShowsTheClientTextInTheErrorRow
  - WireContentBlockViewHostedTests/aPressOnAWireImageSelectsItsBytesInTheInspector (ImageView writes the file in a task)
  - MessageActionsHostedTests/retryOnAnAgentEntrySendsTheContentOfTheEarlierUserEntry (retry can log and return)
  - SessionStateBannersHostedTests: the Reload press tests
  - SessionPickerConnectionModelHostedTests.pressAndRenderTheCall (SessionListView buttons start a task)
  - ElicitationURLConsentViewHostedTests/retryOpensTheBrowserAgainWithNoSecondAnswer and cancelWhileWaitingStopsTheBrowserAndSendsNoSecondAnswer (browser task)
- The AgentCommandsTests and AgentCommandScopeHostedTests command tests now require the Bool of `perform`, but that Bool does not prove that the handler started its task.

## To do
- [x] For each handler above, decide one synchronous proof that the press reached the handler, for example an internal `ObservationReport` in the same step (as `permissionAnswerReport` and `promptSubmitReport` do), or a visible state such as a disabled button.
- [x] Add a `try #require` of that proof after the press and before the wait in each test.
- [x] Prove each one with one mutation run that breaks the handler, and one normal run.

#elicitation-phase-6 #bug

## Review Findings (2026-10-16 13:11)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 25 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

The engine found 0 items. The items below come from the code reading that the caller asked for. Each item has the same cause as the subject of this card: the Fact list names the command tests of AgentCommandsTests and AgentCommandScopeHostedTests, and these tests still have no synchronous proof. `AgentCommandTarget.run(_:payload:)` returns `true` before the task of the handler runs. `SessionModel.startPrompt(text:)` and `SessionModel.answerPermission(_:option:comment:)` only start a Task, and they have no `reporting:` parameter. `ObservationWait.until` and `ScriptedSession.result(ofRequest:)` have no time limit. Thus a broken handler makes each test below wait without end.

- [x] `Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift:288` `card/synchronous-proof` — approveSelectsTheAllowOnceOptionOfTheFirstRequest dispatches approve and then waits on `session.result(ofRequest:)` with no synchronous proof that `answerPermission` started its task. Give `answerPermission(_:option:comment:)` a `reporting:` parameter (as `startSelectPermission` has), give `requestStartReport` of the target to it in `respond(payload:rejects:)`, and add a `try #require` of the report after the dispatch and before the wait.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift:307` `card/synchronous-proof` — rejectAnswersTheRequestOfThePayloadAndSendsTheComment dispatches reject and then waits on `session.result(ofRequest:)` and on `session.promptTexts` with no synchronous proof that `answerPermission` started its task. Add a `try #require` of the `answerPermission` report after the dispatch and before the waits.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift:341` `card/synchronous-proof` — approveAnswersTheFrontRequestWhenItIsAPermission dispatches approve and then waits on `session.result(ofRequest:)` with no synchronous proof that `answerPermission` started its task. Add a `try #require` of the `answerPermission` report after the dispatch and before the wait.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift:530` `card/synchronous-proof` — theAnswerCommandsFollowThePendingPermissionsOfTheSessionModel dispatches reject and then waits on `session.result(ofRequest:)` with no synchronous proof that `answerPermission` started its task. Add a `try #require` of the `answerPermission` report after the dispatch and before the wait.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift:544` `card/synchronous-proof` — sendWithATextPayloadSendsAPromptOfTheSessionModel dispatches send with a text payload and then waits for a `session/prompt` frame with no synchronous proof that `startPrompt(text:)` started its task. Give `startPrompt(text:)` a `reporting:` parameter, give `requestStartReport` of the target to it in `send(payload:to:)`, and add a `try #require` of the report after the dispatch and before the wait.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift:217` `card/synchronous-proof` — sendSubmitsTheComposerInTheScopeOfASessionAsAPrompt dispatches send with no payload and then waits for a `session/prompt` frame with no synchronous proof that the composer submit started the prompt. `PromptInputView.submit()` calls `promptSubmitReport` with `.sent` in the same step. Mount that report and add a `try #require` of `.sent` after the dispatch and before the wait.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift:326` `card/synchronous-proof` — theApproveCommandOfASessionSendsTheFirstAllowOptionAndTheCardGoesAway dispatches approve and then waits on `session.result(ofRequest:)` with no synchronous proof that `answerPermission` started its task. Mount `requestStartReport` and add a `try #require` of the `answerPermission` report after the dispatch and before the wait.