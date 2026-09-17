# Source-side branches

Status: decided. Source: plan.md §9 A, `Docs/decisions/checkpoints.md`.

The kit keeps the branches of a thread local (`AgentThread.branches`,
`ThreadChange.addBranch`, `ThreadChange.selectBranch`). No source sends a
branch. This file records how each source stays in step with the branch that
the thread shows.

## Rules for each source

- A branch swap never sends `ThreadChange.clear`, because `.clear` removes the
  checkpoints and the branch sets.
- A source does not apply a change to an item that is in a branch that the
  thread does not show (`AgentThread.isInHiddenBranch(_:)`). Such a change puts
  the item back in the thread, after the items of the shown branch.
- After Regenerate, `BranchNavigator` shows a new empty branch after the user
  message, and sends the input of the message again. The thread then ends with
  that user message. `AgentThread.regeneratedUserMessage(for:)` finds it. A
  source that gets this send does not add a second user message.

## FoundationModels

`LanguageModelSession.transcript` is writable on macOS 27, and
`Transcript.Prompt.id` is a `var`.

- `SessionThreadSource` keeps the state of each entry that it applied, also
  after the transcript drops the entry.
- When the thread has a branch set, `SessionThreadSource.stream(_:)` first
  writes the entries of the shown items to `session.transcript`. Thus the
  model sees only the shown branch.
- For a Regenerate turn, the source also removes the prompt entry of the
  regenerated user message from the transcript. The session adds a new prompt
  entry with a new id. The source shows that entry with the id of the user
  message. Thus the model does not see the old answer, and the thread has one
  user message for the turn.
- When the session removes the new prompt (for example with the
  `.revertTranscript` policy), the source writes the old prompt entry back to
  the transcript. The thread keeps the user message.
- The source writes the transcript only when the session does not respond.

## Router

`RoutedSession` has no public call that removes entries from a session
(`Docs/decisions/checkpoints.md`: `replacingTranscript(_:)` is not public).
`RoutedSession.fork(workingDirectory:)` copies the full transcript at the
newest point, so a fork also keeps the old answer.

decision: the Router keeps the old context.

- `RouterThreadActions.send(_:)` does not add a user message for a Regenerate
  send. The thread has one user message for the turn.
- The new turn of the session has the old answer in its context. A future
  public Router call that removes entries, or a fork at an earlier point,
  changes this decision.
- `RouterThreadSource` does not apply an event change to an item in a hidden
  branch.

## ACP

`session/fork` is unstable and has no message id
(`Docs/decisions/checkpoints.md`). Thus the ACP agent keeps the old context,
as the Router does. This decision does not change the ACP source: the agent
sends the user messages of the thread.
