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

- [ ] `Sources/AgentViewKit/Input/PromptInputView.swift`: remove `promptsInFlight`, `isBusy`, `promptDidReturn()`, `sendNextQueuedPrompt()` and `.onChange(of: turn.session?.agentState)`. With a session model, a submit calls `SessionModel.prompt(_:meta:)` at once, also while `agentState` is `.running`. With a session model, the composer does not add a submit to the `PromptQueue`.
- [ ] `Sources/AgentViewKit/Input/PromptQueue.swift`: remove `dequeueNext(afterAgentState:)`. No kit code reads `agentState` to send a queued item.
- [ ] `Sources/AgentViewKit/Input/ThreadActionTasks.swift`: remove the `onReturn` closure of `ComposerTurn.startPrompt(with:then:)`. No kit code waits for a prompt to return before it does a different step. `ComposerTurn.isRunning` reads `SessionModel.agentState` directly, only to show the Stop button.
- [ ] `Sources/AgentViewKit/Input/PromptQueueView.swift` and the three files above: change the doc comments. No text says that the composer waits for the end of a turn.

## Acceptance Criteria
- [ ] A submit while the model reports `agentState` `.running` sends a `session/prompt` frame at once. The pending user message shows from `SessionModel.transcript`.
- [ ] A change of `agentState` (for example `.running` to `.idle`) sends no frame.
- [ ] The Stop button shows while the model reports `.running` and goes away when the model reports `.idle`. A press calls `SessionModel.cancel(meta:)` and sends `session/cancel`.
- [ ] No source in `Sources/AgentViewKit/Input/` reads `agentState` other than for the Stop button.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift`: a submit while running sends the frame at once (assert on the frames of the scripted agent); an `agentState` change sends no frame; the Stop button follows `agentState` of the model; Stop sends `session/cancel`.
- [ ] `Tests/AgentViewKitTests/Input/PromptQueueTests.swift`: remove the tests of `dequeueNext(afterAgentState:)`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.