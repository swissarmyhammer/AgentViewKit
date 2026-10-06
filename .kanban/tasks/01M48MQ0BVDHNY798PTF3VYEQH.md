---
assignees:
- claude-code
depends_on:
- 01M443PGJC9H955A0M1QSS6FR3
position_column: todo
position_ordinal: a880
title: 'Remove the turn gate from the composer: each submit calls SessionModel.prompt at once'
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. A view shows what the model holds and calls the model methods. The kit does no turn tracking and keeps no turn-gated queue. At present the composer counts the prompts that did not return (`promptsInFlight`) and holds the queue until `agentState` lets it go on. That is kit logic about turns.

Owner decision (2026-10-06): delete `PromptQueue` and `PromptQueueView`. Reason: in ACP v2 the agent accepts a `session/prompt` at once (the response names the inserted user message). The agent decides how to handle a message that comes while it runs. Thus the kit has nothing to hold back.

- [ ] `Sources/AgentViewKit/Input/PromptInputView.swift`: remove `promptsInFlight`, `isBusy`, `promptDidReturn()`, `sendNextQueuedPrompt()`, `.onChange(of: turn.session?.agentState)` and all use of `PromptQueue` and `PromptQueueView`. With a session model, each submit calls `SessionModel.prompt(_:meta:)` at once, also while `agentState` is `.running`.
- [ ] Delete the queue: delete `Sources/AgentViewKit/Input/PromptQueue.swift`, `Sources/AgentViewKit/Input/PromptQueueView.swift`, `Tests/AgentViewKitTests/Input/PromptQueueTests.swift` and `Tests/AgentViewKitTests/Input/PromptQueueViewHostedTests.swift`. Remove all use of the two types in `DefaultPromptAccessory`, in the README override and modifier tables, in the snippets and in the demo.
- [ ] `Sources/AgentViewKit/Input/ThreadActionTasks.swift`: remove the `onReturn` closure of `ComposerTurn.startPrompt(with:then:)`. No kit code waits for a prompt to return before it does a different step. `ComposerTurn.isRunning` reads `SessionModel.agentState` directly, only to show the Stop button.
- [ ] Change the doc comments of the files above. No text says that the composer waits for the end of a turn or keeps a queue.

Note: `ReadmeCoverageTests` makes the README "Components" list agree with plan.md §9. Thus this task does not remove the `PromptQueueView` line from the README "Components" list. The plan rewrite task ^g95wwbs removes that line from the README and from plan.md §9 together.

## Acceptance Criteria
- [ ] No type named `PromptQueue` or `PromptQueueView` is in `Sources/`.
- [ ] A submit while the model reports `agentState` `.running` sends a `session/prompt` frame at once. The pending user message shows from `SessionModel.transcript`.
- [ ] A second submit while `agentState` is `.running` sends a second `session/prompt` frame at once.
- [ ] A change of `agentState` (for example `.running` to `.idle`) sends no frame.
- [ ] The Stop button shows while the model reports `.running` and goes away when the model reports `.idle`. A press calls `SessionModel.cancel(meta:)` and sends `session/cancel`.
- [ ] No source in `Sources/AgentViewKit/Input/` reads `agentState` other than for the Stop button.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift`: a submit while running sends the frame at once (assert on the frames of the scripted agent); a second submit while running sends a second `session/prompt` frame at once; an `agentState` change sends no frame; the Stop button follows `agentState` of the model; Stop sends `session/cancel`.
- [ ] `Tests/PackageStructureTests/RemovedVocabularyTests.swift`: add `PromptQueue` and `PromptQueueView` to the list of removed names.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.