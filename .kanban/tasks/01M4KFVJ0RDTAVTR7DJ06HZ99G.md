---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4kg024j975x9115ajv5bk78
  text: |-
    Research (2026-10-10). No file of a different repository is changed.

    - Correct repository: `EventBroadcaster` and `SessionUpdateRouter` are in FoundationModelsACP (`Sources/FoundationModelsACP/Connection/`), not in FoundationModelsACPClient. FoundationModelsACPClient has no `EventBroadcaster`. I corrected the card description.
    - Session search: the `ListAgents` tool is not available in this session, so I could not list the peer sessions. The process check (`lsof -d cwd` on `claude` processes) found one CLI session only, in FoundationModelsACPAgent. I found no session in FoundationModelsACP or in FoundationModelsACPClient. Thus I sent no message, and I recorded the full report on the card for a person to send.
    - Lock order, confirmed from the code of FoundationModelsACP `main` at 2268ced (the AgentViewKit checkout has the same `EventBroadcaster.swift`): `State.publish` and `State.broadcast` yield in the body of `withState`, under the `Mutex`. `attach` also yields the replay events under the `Mutex`. `onTermination` of `subscribe(to:replay:)` calls `detach`, which takes the same `Mutex`. `finishAll` already finishes the continuations outside the lock, for the same reason, but the yield paths do not.
    - A second caller yields under the lock: `OutgoingRequestTracker` (`state.broadcast` of `.started` and `.finished`).
    - The fix must keep the event order ("no live event before a replayed event"). Thus "yield after the lock" needs a serial delivery path, or an `onTermination` that does not take the lock synchronously. The report on the card gives both.
  timestamp: 2026-10-10T18:07:56.050655+00:00
- actor: claude-code
  id: 01m4kg05dtc9n1cebwjexvv2jg
  text: |-
    ### implement — stuck
    - evidence: Card description updated: repository corrected to FoundationModelsACP, and a "Report for the owner of FoundationModelsACP" section added (lock order, files, callers, suggested fix, failing test). Lock order confirmed in `EventBroadcaster.swift` (read only). No source file changed in any repository. Subtasks checked: 0 of 3. The test is not written, because no session of FoundationModelsACP was found and that repository is read only for this step. The report is not sent, because `ListAgents` is not available and no peer session was found.
    - next: a person sends the report on the card to the owner of FoundationModelsACP (or starts a session there to write the failing test and the fix). After the fixed version is out, update the AgentViewKit dependency. The task stays in doing.
  timestamp: 2026-10-10T18:07:59.418803+00:00
- actor: claude-code
  id: 01m4kg0m5bxajetgz6w8z1j7rg
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the lock order is confirmed in FoundationModelsACP (not FoundationModelsACPClient) EventBroadcaster.swift. The report is on the card. No session of FoundationModelsACP was found, so the report is not sent. No files changed.
    - test: not run
    - commit: not run
    - review: not run
    - next: a person sends the report to the owner of FoundationModelsACP, or starts a session there for the failing test and the fix.
  timestamp: 2026-10-10T18:08:14.507605+00:00
position_column: doing
position_ordinal: '8180'
title: Find and report the EventBroadcaster lock-order deadlock of FoundationModelsACPClient
---
## What
A test process of AgentViewKitTests stopped for 30 minutes (found while ^kmkd5rx was researched, 2026-10-10). `sample` showed two threads that wait for each other:

- Main thread: ThreadExporterTests.theExportOfATranscriptHasOnlyTheMessageEntriesInTranscriptOrder -> release of `ScriptedSession` -> `SessionModel.deinit` -> `swift_task_cancel` (holds the status record lock of a task) -> `AsyncStream._Storage.cancel` -> `onTermination` of `EventBroadcaster.subscribe(to:replay:)` -> `EventBroadcaster.detach(token:from:)` -> waits for `os_unfair_lock`.
- Cooperative thread: `Connection.readLoop` -> `ClientSideConnection.serveNotification` -> `SessionUpdateRouter.deliver(_:for:)` -> `EventBroadcaster.withState` (holds the broadcaster lock) -> `EventBroadcaster.State.publish` -> `AsyncStream.Continuation.yield` -> `swift_continuation_resume` -> waits for the status record lock of the same task.

Thus the broadcaster yields to a continuation while it holds its lock, and the cancel handler of the stream takes that lock. The code is in the FoundationModelsACP dependency (`Sources/FoundationModelsACP/Connection/EventBroadcaster.swift`, `SessionUpdateRouter.swift`), not in FoundationModelsACPClient and not in this repository. (The first text of this card said FoundationModelsACPClient. That was incorrect.)

The hang occurred one time, when the output of the test process went through a slow pipe reader. It can occur in each run where a `SessionModel` is released while a notification for it arrives.

- [ ] Write a test in FoundationModelsACP that releases a subscribed `SessionModel` (or cancels the task that iterates a subscribed stream) while the router delivers updates to it, and that stops in the deadlock.
- [ ] Report the deadlock to the owner of FoundationModelsACP with the two stacks (do not change the dependency checkout in this repository).
- [ ] When the fixed version is out, update the dependency of AgentViewKit.

## Report for the owner of FoundationModelsACP
Send this text to the session or person that owns FoundationModelsACP. Checked against `main` at 2268ced. The checkout of AgentViewKit has the same `EventBroadcaster.swift`.

**Title:** ABBA deadlock: `EventBroadcaster` yields to a stream continuation while it holds its `Mutex`.

**Lock order:**
1. Thread B (cooperative pool, `Connection.readLoop` -> `ClientSideConnection.serveNotification` -> `SessionUpdateRouter.deliver(_:for:)`) calls `broadcaster.withState`. This takes the `Mutex<State>` (`os_unfair_lock`). In the body, `State.publish(_:to:)` calls `continuation.yield(event)`. The consumer task waits in `next()`, so `yield` resumes it (`swift_continuation_resume`). This needs the status record lock of the consumer task.
2. Thread A (main thread, `SessionModel.deinit`) cancels the consumer task (`swift_task_cancel`). Cancel holds the status record lock of that task and runs the cancel handler of `AsyncStream.next()`. That handler terminates the stream and runs `onTermination`, which `subscribe(to:replay:)` sets to `detach(token:from:)`. `detach` calls `state.withLock`, and waits for the `Mutex` that thread B holds.
3. A holds the task lock and waits for the `Mutex`. B holds the `Mutex` and waits for the task lock. Both stop for all time.

**Code that causes it (EventBroadcaster.swift):**
- `State.publish(_:to:)` and `State.broadcast(_:)` call `continuation.yield` in the body of `withState(_:)`, thus under the lock.
- `attach(_:to:replay:)` also yields the replay events under the lock (smaller risk, because the new stream has no waiter yet).
- `subscribe(to:replay:)` sets `onTermination` to call `detach(token:from:)`, which takes the same lock.
- `finishAll(_:)` already finishes the continuations outside the lock, "so a synchronous `onTermination` callback never re-enters the lock". `yield` needs the same rule, because cancel runs `onTermination` on a different thread while it holds a runtime lock.

**Callers that yield under the lock:** `SessionUpdateRouter.deliver(_:for:)` (`state.publish`), `OutgoingRequestTracker` (`state.broadcast` of `.started` and `.finished`).

**Suggested fix:** Yield after the lock is released. In the lock, change the state and collect the continuations and the events to send (an outbox). After `withLock` returns, call `yield` on each one. Keep the order of events: the router and the tracker need "no live event before a replayed event" and the order of updates. Two possible ways:
- Make the delivery serial: one delivery lock, separate from the state lock, that `onTermination` never takes. Take it around "state step + yield", and let `detach` take only the state lock. Then `detach` never waits for a yield.
- Or let `onTermination` not take the lock synchronously (for example, mark the token as gone in an `Atomic`, and remove it in the next `withState`).

**Failing test to write first:** Subscribe to a session of `SessionUpdateRouter` and iterate the stream in a task. In a loop, deliver updates from one thread and cancel the iterating task from a different thread at the same time. Bound the test with a time limit. Before the fix, it stops (the deadlock). After the fix, it ends.

**Evidence:** `sample` of the stopped AgentViewKitTests process, in the comment of ^kmkd5rx (AgentViewKit) of 2026-10-10, test ThreadExporterTests.theExportOfATranscriptHasOnlyTheMessageEntriesInTranscriptOrder.

## Evidence
The `sample` output is in the comment of ^kmkd5rx of 2026-10-10.