---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m48zbx60525tkh64rq2jymf1
  text: |-
    Research:
    - The queue is used only in `PromptInputView.swift`, `PromptQueue.swift`, `PromptQueueView.swift`, `PromptEditorContext.swift` (doc comments), and the tests `PromptQueueTests`, `PromptQueueViewHostedTests`, `ComposerSessionModelHostedTests`. The demo, the README snippets and `DefaultPromptAccessory` code do not use it. The README has only the "Components" line (stays, ^g95wwbs).
    - The scripted agent names are `heldMethods` and `releaseHeldAnswer()` (not `holdsPromptAnswers` / `releasePromptAnswer()`).
    - `SessionModel.isRunning` is in `Sources/AgentViewKit/Thread/SessionTranscriptEnvironment.swift`.
    Owner answers (2026-10-06, question tool):
    - Esc-to-stop and the hidden suggestion chips also read `agentState`. Keep both reads: yes.
    - With no queue, the old thread-actions composer path also sends each submit at once while the thread runs: yes. Thus `returnWhileTheThreadRunsSendsNothing` changes to send the text.
    Plan: with no gate, "send now" is the same as a submit. The composer stops passing its own `onSendNow`; the context default (`onSubmit`) applies.
  timestamp: 2026-10-06T16:04:54.080150+00:00
- actor: claude-code
  id: 01m490050cs60pqrfggy7tbsw0
  text: |-
    Implementation done (TDD).
    - RED: `aSubmitWhileTheAgentRunsSendsAPromptFrameAtOnce`, `aSecondSubmitWhileTheAgentRunsSendsASecondPromptFrameAtOnce`, `returnWhileTheThreadRunsSendsTheTextAtOnce` and `sourcesUseNoRemovedSymbol` failed for the expected cause (the composer held the submit while the agent ran; `Sources/` used `PromptQueue`). `aChangeOfTheAgentStateSendsNoFrame` and `theStopButtonShowsWhileTheAgentRunsAndGoesAwayWhenItIsIdle` passed at once: they guard behavior that already exists and that the old queue path could break.
    - GREEN: deleted `PromptQueue.swift`, `PromptQueueView.swift`, `PromptQueueTests.swift`, `PromptQueueViewHostedTests.swift`. `PromptInputView` has no `promptsInFlight`, `isBusy`, `promptDidReturn()`, `sendNextQueuedPrompt()`, `threadStateDidChange`, `sendNow()` and no `.onChange`. Each submit calls `ComposerTurn.startPrompt(with:)` at once. `startPrompt` has no `onReturn`. `canSubmit` is only "the text is not blank". The composer no longer passes its own `onSendNow`; the context default (`onSubmit`) applies.
    - `agentState` reads that stay in `Sources/AgentViewKit/Input/`: `ComposerTurn.isRunning` (Stop button, Esc-to-stop, the suggestion chips of `DefaultPromptAccessory`). The owner approved the Esc and chip reads.
    - Doc comments changed in `PromptInputView.swift`, `ThreadActionTasks.swift`, `PromptEditorContext.swift`, and the `canSubmit` comments of `AgentCommandTarget.swift` and `AgentCommandScope.swift` ("sends or queues" became "sends").
    - README: only the "Components" line for `PromptQueueView` remains (^g95wwbs removes it). There are no queue rows in the README tables. The demo and the snippets did not use the queue.
    - Gates: `swift test` passed: 1295 tests in 118 suites, 77 tests in 12 suites, 1 test in 1 suite. Only warning: mlx-swift `missing creator for mutated node`. `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo` passed (2 tests). The unstable test of ^et6e0ps passed in this run.

    ### implement — changed
    - evidence: Sources/AgentViewKit/Input/PromptInputView.swift, Sources/AgentViewKit/Input/ThreadActionTasks.swift, Sources/AgentViewKit/Input/PromptEditorContext.swift, Sources/AgentViewKit/Commands/AgentCommandTarget.swift, Sources/AgentViewKit/Commands/AgentCommandScope.swift, Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift, Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift; deleted Sources/AgentViewKit/Input/PromptQueue.swift, Sources/AgentViewKit/Input/PromptQueueView.swift, Tests/AgentViewKitTests/Input/PromptQueueTests.swift, Tests/AgentViewKitTests/Input/PromptQueueViewHostedTests.swift; swift test, Scripts/check-readme.sh, Scripts/test-examples.sh AgentViewKitDemo all pass
    - next: /review
  timestamp: 2026-10-06T16:15:57.452931+00:00
depends_on:
- 01M443PGJC9H955A0M1QSS6FR3
position_column: doing
position_ordinal: '80'
title: 'Remove the turn gate from the composer: each submit calls SessionModel.prompt at once'
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. A view shows what the model holds and calls the model methods. The kit does no turn tracking and keeps no turn-gated queue. At present the composer counts the prompts that did not return (`promptsInFlight`) and holds the queue until `agentState` lets it go on. That is kit logic about turns.

Owner decision (2026-10-06): delete `PromptQueue` and `PromptQueueView`. Reason: in ACP v2 the agent accepts a `session/prompt` at once (the response names the inserted user message). The agent decides how to handle a message that comes while it runs. Thus the kit has nothing to hold back.

- [x] `Sources/AgentViewKit/Input/PromptInputView.swift`: remove `promptsInFlight`, `isBusy`, `promptDidReturn()`, `sendNextQueuedPrompt()`, `.onChange(of: turn.session?.agentState)` and all use of `PromptQueue` and `PromptQueueView`. With a session model, each submit calls `SessionModel.prompt(_:meta:)` at once, also while `agentState` is `.running`.
- [x] Delete the queue: delete `Sources/AgentViewKit/Input/PromptQueue.swift`, `Sources/AgentViewKit/Input/PromptQueueView.swift`, `Tests/AgentViewKitTests/Input/PromptQueueTests.swift` and `Tests/AgentViewKitTests/Input/PromptQueueViewHostedTests.swift`. Remove all use of the two types in `DefaultPromptAccessory`, in the README override and modifier tables, in the snippets and in the demo.
- [x] `Sources/AgentViewKit/Input/ThreadActionTasks.swift`: remove the `onReturn` closure of `ComposerTurn.startPrompt(with:then:)`. No kit code waits for a prompt to return before it does a different step. `ComposerTurn.isRunning` reads `SessionModel.agentState` directly, only to show the Stop button.
- [x] Change the doc comments of the files above. No text says that the composer waits for the end of a turn or keeps a queue.

Note: `ReadmeCoverageTests` makes the README "Components" list agree with plan.md §9. Thus this task does not remove the `PromptQueueView` line from the README "Components" list. The plan rewrite task ^g95wwbs removes that line from the README and from plan.md §9 together.

## Acceptance Criteria
- [x] No type named `PromptQueue` or `PromptQueueView` is in `Sources/`.
- [x] A submit while the model reports `agentState` `.running` sends a `session/prompt` frame at once. The pending user message shows from `SessionModel.transcript`.
- [x] A second submit while `agentState` is `.running` sends a second `session/prompt` frame at once.
- [x] A change of `agentState` (for example `.running` to `.idle`) sends no frame.
- [x] The Stop button shows while the model reports `.running` and goes away when the model reports `.idle`. A press calls `SessionModel.cancel(meta:)` and sends `session/cancel`.
- [x] No source in `Sources/AgentViewKit/Input/` reads `agentState` other than for the Stop button. (Owner, 2026-10-06: Esc-to-stop and the hidden suggestion chips can also read it.)

## Tests
- [x] `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift`: a submit while running sends the frame at once (assert on the frames of the scripted agent); a second submit while running sends a second `session/prompt` frame at once; an `agentState` change sends no frame; the Stop button follows `agentState` of the model; Stop sends `session/cancel`.
- [x] `Tests/PackageStructureTests/RemovedVocabularyTests.swift`: add `PromptQueue` and `PromptQueueView` to the list of removed names.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.