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
position_column: todo
position_ordinal: a080
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
- [ ] For each handler above, decide one synchronous proof that the press reached the handler, for example an internal `ObservationReport` in the same step (as `permissionAnswerReport` and `promptSubmitReport` do), or a visible state such as a disabled button.
- [ ] Add a `try #require` of that proof after the press and before the wait in each test.
- [ ] Prove each one with one mutation run that breaks the handler, and one normal run.

#elicitation-phase-6 #bug