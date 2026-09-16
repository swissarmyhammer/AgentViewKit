---
comments:
- actor: claude-code
  id: 01m2p6vga0tmq4kytcp9tf1fad
  text: 'Note from ^h0m4ycm (done): `PromptInputView` does not submit while `thread.state == .running`. Return does nothing and the text stays, and `PromptSubmitAction.isEnabled` is false. The queue must change this rule: while a turn runs, a submit adds the text to the queue. The submit logic is `PromptInputView.submit()` and `canSubmit` in Sources/AgentViewKit/Input/PromptInputView.swift. Hosted tests use `threadViewHarness(size:actions:thread:content:)` and `harness.focusFirstEditableTextView(of:)` from AgentViewKitTestSupport.'
  timestamp: 2026-09-16T22:54:29.184584+00:00
depends_on:
- 01M21AF2MV082PZY3Q6H0M4YCM
position_column: todo
position_ordinal: '9980'
title: 'PromptQueueView: queued messages with reorder, edit, drop, send now (plan §9 D)'
---
## What
Create `Sources/AgentViewKit/Input/PromptQueue.swift` and `PromptQueueView.swift`, per plan.md §9 D.

- `PromptQueue` (`@MainActor @Observable`): an ordered list of `UserInput`. `enqueue`, `remove(id)`, `move(from:to:)`, `update(id, text)`, `dequeueNext()`. When `thread.state` returns to `idle`, the owner sends the next item through `AgentThreadActions.send`.
- `PromptInputView` integration: while `thread.state == .running`, Return enqueues instead of sending. Command-Return is "send now", which injects into the current turn by calling `send` at once.
- `PromptQueueView(queue:)`: a list above the composer with drag reorder (`reorderable()`), inline edit, a remove button, and a count badge. Hidden when empty.
- Esc while running calls `cancel` and keeps the queue.

## Acceptance Criteria
- [ ] Return while running adds to the queue and does not call `send`.
- [ ] When the state changes to `idle`, the first queued item is sent and removed.
- [ ] Command-Return while running calls `send` at once.
- [ ] Esc calls `cancel` and the queue count is unchanged.

## Tests
- [ ] `Tests/AgentViewKitTests/Input/PromptQueueTests.swift`: ordering and dequeue on state change.
- [ ] `Tests/AgentViewKitTests/Input/PromptQueueViewHostedTests.swift`: keys and the badge through `NoopThreadActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.