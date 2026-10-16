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