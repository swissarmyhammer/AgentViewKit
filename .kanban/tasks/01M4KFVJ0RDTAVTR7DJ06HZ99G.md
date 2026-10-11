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
- actor: claude-code
  id: 01m4nc7qfz2bjr25t3jqpfg026
  text: '2026-10-11: The full report was sent to the FoundationModelsACP session (foundationmodelsacp-be). That session must add its own task, write the failing test, make the fix, and send back the commit. The title now names FoundationModelsACP. Next: when the fixed commit is pushed, update the AgentViewKit dependency.'
  timestamp: 2026-10-11T11:40:41.855679+00:00
- actor: claude-code
  id: 01m4nd4596ch8zp528znexnqsa
  text: |-
    2026-10-11, blocker for the third subtask (dependency update).

    - First subtask checked: the test and the fix are in FoundationModelsACP `main` at `5f94484` (parent `2268ced`, task ^mwxhbzz there).
    - How the pin works: `Package.swift` pins FoundationModelsACP and FoundationModelsACPClient with `branch: "main"`. `Package.resolved` is git-ignored. FoundationModelsACPClient pins FoundationModelsACP with `branch: "main"` and no revision, so no intermediate package blocks the revision. FoundationModelsACPAgent is not in the graph.
    - I set FoundationModelsACP to `5f94484`. The checkout had the fixed `EventBroadcaster.swift` (outbox, `delivery` lock, `detach` takes only the state lock).
    - The build failed. FoundationModelsACPClient `74fc2df` does not compile with `5f94484`: `'CompactionStatus' is not a member type of enum 'FoundationModelsACP.Unstable'`. Cause: `dc336cb` in `b2cec56..5f94484` re-vendors the schema to `schema-v2.0.0-alpha.8` and moves the `Unstable` types.
    - I set FoundationModelsACPClient to its `main` `24643be` (breaking refactor, "move to stable ACP types"). Then FoundationModelsACPClient compiled, but AgentViewKit failed: `Sources/AgentViewKit/Theme/AgentTheme.swift`: `'CompactionStatus' is not a member type of enum 'FoundationModelsACP.Unstable'`, and the same for `NoticeSeverity`.
    - Thus the update is a schema migration (alpha.7 to alpha.8), with source changes, behavior changes in 19 commits, and a change of the recorded schema pin in `Docs/decisions/acp-version.md`. That is more than this card orders, so I did not do it. I made task ^j6qef6x with the facts and the work.
    - I put the pins back to FoundationModelsACP `b2cec56` and FoundationModelsACPClient `74fc2df`, and copied the root `Package.resolved` into the demo project again. `swift build --build-tests`: Build complete. `swift test --skip-build --filter ResolvedPinsTests`: 2 tests passed.
    - Local tool problem: `swift package update FoundationModelsACP` stopped with `'editorkit': ... couldn't be removed`, because the sourcekit-lsp of `sah serve` (pid 12020) builds in `.build/checkouts/EditorKit/.build/index-build`. The failed update also removed the `editorkit` entry from `.build/workspace-state.json`. I added the entry again (same revision `235cbb7`), and then `swift package resolve` worked. To change a pin, edit the git-ignored `Package.resolved` and run `swift package resolve`; do not use `swift package update` while that indexer runs. I did not stop any process.
    - Next: a person decides if ^j6qef6x is done now. When ^j6qef6x is done, check the third subtask of this card.
  timestamp: 2026-10-11T11:56:13.478180+00:00
- actor: claude-code
  id: 01m4nd48ehn6w0n1wq4d6zeakd
  text: |-
    ### implement — stuck
    - evidence: no tracked source file changed. Card description: first subtask checked (FoundationModelsACP `5f94484`). The pin update to `5f94484` needs FoundationModelsACPClient `24643be` and a schema alpha.8 migration of AgentViewKit (build error `'CompactionStatus' is not a member type of enum 'FoundationModelsACP.Unstable'` in `Sources/AgentViewKit/Theme/AgentTheme.swift`). Pins put back to `b2cec56` / `74fc2df`; `swift build --build-tests` complete; `swift test --skip-build --filter ResolvedPinsTests` 2 of 2 passed. New task ^j6qef6x has the migration.
    - next: a person decides on ^j6qef6x. After it is done, check the third subtask here. The task stays in doing.
  timestamp: 2026-10-11T11:56:16.721338+00:00
- actor: claude-code
  id: 01m4nd4xd1fahtcwgdgjmq9hz8
  text: |-
    ### finish iteration 2 — stuck
    - implement: stuck — FoundationModelsACP 5f94484 needs FoundationModelsACPClient 24643be and a migration of AgentViewKit to schema alpha.8 (AgentTheme.swift: 'CompactionStatus' is not a member type of enum 'FoundationModelsACP.Unstable'). The pins are set back to b2cec56 / 74fc2df. No tracked source file changed.
    - test: not run
    - commit: not run
    - review: not run
    - next: do the migration in ^j6qef6x, then update the pin and check the third subtask.
  timestamp: 2026-10-11T11:56:38.177586+00:00
- actor: claude-code
  id: 01m4nebcj5k0jx6mc8tnqjhha6
  text: |-
    ### implement — no-change
    - evidence: Read only. The root `Package.resolved` pins FoundationModelsACP `5f94484eaed1f47e1432b689b9bda8194ecb95a0` and FoundationModelsACPClient `24643be3817912251e93705443012013b6b6e177`. The `.build/checkouts/FoundationModelsACP` HEAD is `5f94484`, with no local changes. Its `EventBroadcaster.swift` has the outbox, the `delivery` lock (`withState` takes it around the state step and the yield), and `detach` takes only `state.withLock`. Third subtask checked: done in f3f5c2d (^j6qef6x). Subtasks: 3 of 3. No source file changed. Only the card changed. No commit.
    - next: the task stays in doing. It is ready for review.
  timestamp: 2026-10-11T12:17:38.885883+00:00
position_column: doing
position_ordinal: '8180'
title: Find and report the EventBroadcaster lock-order deadlock of FoundationModelsACP
---
## What
A test process of AgentViewKitTests stopped for 30 minutes (found while ^kmkd5rx was researched, 2026-10-10). `sample` showed two threads that wait for each other:

- Main thread: ThreadExporterTests.theExportOfATranscriptHasOnlyTheMessageEntriesInTranscriptOrder -> release of `ScriptedSession` -> `SessionModel.deinit` -> `swift_task_cancel` (holds the status record lock of a task) -> `AsyncStream._Storage.cancel` -> `onTermination` of `EventBroadcaster.subscribe(to:replay:)` -> `EventBroadcaster.detach(token:from:)` -> waits for `os_unfair_lock`.
- Cooperative thread: `Connection.readLoop` -> `ClientSideConnection.serveNotification` -> `SessionUpdateRouter.deliver(_:for:)` -> `EventBroadcaster.withState` (holds the broadcaster lock) -> `EventBroadcaster.State.publish` -> `AsyncStream.Continuation.yield` -> `swift_continuation_resume` -> waits for the status record lock of the same task.

Thus the broadcaster yields to a continuation while it holds its lock, and the cancel handler of the stream takes that lock. The code is in the FoundationModelsACP dependency (`Sources/FoundationModelsACP/Connection/EventBroadcaster.swift`, `SessionUpdateRouter.swift`), not in FoundationModelsACPClient and not in this repository. (The first text of this card said FoundationModelsACPClient. That was incorrect.)

The hang occurred one time, when the output of the test process went through a slow pipe reader. It can occur in each run where a `SessionModel` is released while a notification for it arrives.

- [x] Write a test in FoundationModelsACP that releases a subscribed `SessionModel` (or cancels the task that iterates a subscribed stream) while the router delivers updates to it, and that stops in the deadlock. (Done in FoundationModelsACP `main` at commit `5f94484`, parent `2268ced`, task ^mwxhbzz there: `EventBroadcasterTests.aCancelWhileAYieldResumesTheConsumerDoesNotDeadlock`. The same commit has the fix: each step collects its events in an outbox under the state lock, and yields after the lock is released. A separate delivery lock keeps the event order. `detach` takes only the state lock.)
- [x] Report the deadlock to the owner of FoundationModelsACP with the two stacks (do not change the dependency checkout in this repository).
- [x] When the fixed version is out, update the dependency of AgentViewKit. (Done in f3f5c2d (^j6qef6x). The root `Package.resolved` pins FoundationModelsACP `5f94484` and FoundationModelsACPClient `24643be`. The `.build/checkouts` FoundationModelsACP `EventBroadcaster.swift` has the fix: outbox, delivery lock, and `detach` takes only the state lock.)

## Report for the owner of FoundationModelsACP
Sent to the FoundationModelsACP session (foundationmodelsacp-be) on 2026-10-11. Checked against `main` at 2268ced. The checkout of AgentViewKit has the same `EventBroadcaster.swift`.

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