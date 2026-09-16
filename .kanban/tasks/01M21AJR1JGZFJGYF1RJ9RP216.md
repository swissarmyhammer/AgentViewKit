---
comments:
- actor: claude-code
  id: 01m2p6vga0tmq4kytcp9tf1fad
  text: 'Note from ^h0m4ycm (done): `PromptInputView` does not submit while `thread.state == .running`. Return does nothing and the text stays, and `PromptSubmitAction.isEnabled` is false. The queue must change this rule: while a turn runs, a submit adds the text to the queue. The submit logic is `PromptInputView.submit()` and `canSubmit` in Sources/AgentViewKit/Input/PromptInputView.swift. Hosted tests use `threadViewHarness(size:actions:thread:content:)` and `harness.focusFirstEditableTextView(of:)` from AgentViewKitTestSupport.'
  timestamp: 2026-09-16T22:54:29.184584+00:00
- actor: claude-code
  id: 01m2p7ef7gms3rmjwfy3vfwxqm
  text: |-
    ### finish iteration 1 — findings
    - implement: added PromptQueue, PromptQueueView, the promptQueue environment value, and the queue, send-now, and Esc keys in PromptInputView and StockPromptEditor.
    - test: swift test exit 0. AgentViewKitTests 894, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 20, AgentViewKitFoundationModelsTests 1. No new warnings.
    - commit: 7c5e749
    - review: 2 findings (duplication in the identifier functions of PromptQueueView; magic numbers at PromptQueueView.swift:122).
  timestamp: 2026-09-16T23:04:50.672446+00:00
- actor: claude-code
  id: 01m2p7jnjw9m5rhh3db433yfc1
  text: |-
    ### finish iteration 2 — done
    - implement: added the shared itemIdentifier builder and the editLineRange constant in PromptQueueView. This fixes the 2 findings of iteration 1.
    - test: swift test exit 0. AgentViewKitTests 894, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 20, AgentViewKitFoundationModelsTests 1. No new warnings.
    - commit: 5d3edb6
    - review: 0 findings. All prior items are checked. The task moved to done.

    Decisions: the queue is in the `promptQueue` environment value, and PromptInputView sends the next item when the state changes to idle. A turn that stops with the `cancelled` reason holds the queue, so that Esc keeps the queued items. An item that an edit made blank is removed and not sent.
  timestamp: 2026-09-16T23:07:08.252431+00:00
depends_on:
- 01M21AF2MV082PZY3Q6H0M4YCM
position_column: done
position_ordinal: ae80
title: 'PromptQueueView: queued messages with reorder, edit, drop, send now (plan §9 D)'
---
## What
Create `Sources/AgentViewKit/Input/PromptQueue.swift` and `PromptQueueView.swift`, per plan.md §9 D.

- `PromptQueue` (`@MainActor @Observable`): an ordered list of `UserInput`. `enqueue`, `remove(id)`, `move(from:to:)`, `update(id, text)`, `dequeueNext()`. When `thread.state` returns to `idle`, the owner sends the next item through `AgentThreadActions.send`.
- `PromptInputView` integration: while `thread.state == .running`, Return enqueues instead of sending. Command-Return is "send now", which injects into the current turn by calling `send` at once.
- `PromptQueueView(queue:)`: a list above the composer with drag reorder (`reorderable()`), inline edit, a remove button, and a count badge. Hidden when empty.
- Esc while running calls `cancel` and keeps the queue.

## Acceptance Criteria
- [x] Return while running adds to the queue and does not call `send`.
- [x] When the state changes to `idle`, the first queued item is sent and removed.
- [x] Command-Return while running calls `send` at once.
- [x] Esc calls `cancel` and the queue count is unchanged.

## Tests
- [x] `Tests/AgentViewKitTests/Input/PromptQueueTests.swift`: ordering and dequeue on state change.
- [x] `Tests/AgentViewKitTests/Input/PromptQueueViewHostedTests.swift`: keys and the badge through `NoopThreadActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 18:01)

> Scope: `review sha HEAD~1..HEAD` (7c5e749). 8 files reviewed.

- [x] `Sources/AgentViewKit/Input/PromptQueueView.swift:62` `duplication/duplication` — Three identifier functions (`editIdentifier`, `sendNowIdentifier`, `removeIdentifier`) differ only by string literal. This is duplication that should be extracted to a shared function with the suffix as a parameter. Extract to a shared helper: `private static func queueIdentifier(_ suffix: String, _ id: QueuedPromptID) -> String { "prompt-queue-\(suffix)-\(id.rawValue)" }`. Then implement the three public functions as one-liners forwarding to it.
- [x] `Sources/AgentViewKit/Input/PromptQueueView.swift:122` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.

## Review Findings (2026-09-16 18:05)

> Scope: `review sha HEAD~1..HEAD` (5d3edb6). 1 file reviewed. No findings.