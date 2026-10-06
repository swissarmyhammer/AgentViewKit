---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4985r4aqvk34rmr8d3mfnda
  text: |-
    Research (implement, 2026-10-06):
    - SessionModel (client be7e615) gives `agentState: StateUpdate?`, `isReplaying` (computed from the replay phase), `history: SessionHistory` (`.live` or `.retained(replayFrom:)`), `hasMissedUpdates` and `isClosed`. `ConnectionModel.resumeSession(_:)` takes a `ResumeSessionRequest(cwd:sessionId:replayFrom:)`. A successful `.start` replay clears `hasMissedUpdates`. The `.idle` case holds `IdleStateUpdate.stopReason: StopReason?` (ACP type, `.unknown(String)` for extension values).
    - GAP: `ResumeSessionRequest.cwd` is required, but neither SessionModel nor ConnectionModel holds the working directory of an open session (`SessionInfoUpdate` has no cwd; only the `sessions` list rows have one). Thus the Reload action cannot get `cwd` from the model. The plan: the host gives the working directory as a view input (it made the `session/new` request with it), the same as `ACPThreadSource.resumeSession(_:cwd:...)` and `SessionListView` do. The kit keeps no copy of it. This adds a `workingDirectory` input to the session initializer of AgentThreadView. The owner must confirm this.
    - At present the session path of ConversationView shows no StateBanner; only the deprecated thread path does (ThreadState). The thread path stays as it is until ^h1116ab.
    - Composer: `ComposerTurn` reads the session model from the environment. It will read `isClosed` directly to disable the editor and the submit.
    - Overflow test: `ScriptedSession.open` needs a `bufferLimits` input; the scripted agent sends updates in a `session/new` lead-in, before the result, so the router buffers them and overflows.
  timestamp: 2026-10-06T18:38:49.482940+00:00
- actor: claude-code
  id: 01m498rknw2spvkkkxp8n5av1r
  text: |-
    Implementation landed (TDD: the new suite failed to compile first on the missing API, then passed).
    - `StateBanner` has a new `init(session:onShowError:)`. Its body reads `SessionModel.agentState` and shows one message for each value: running, ready (idle with no stop reason), end_turn, cancelled, max_tokens, max_turn_requests, refusal, the extension stop reason table through `message(forUnknownStopReason:)`, requires_action, and a general text for `.unknown`. Show Error gives the id of the last `ErrorEntry` of the transcript. The thread path (`init(state:errorID:onShowError:)`, `message(for: ThreadState)`) keeps its old behavior until ^h1116ab. The two paths share the message constants.
    - New `SessionStreamBanner(session:connection:workingDirectory:)` in Status/: closed state (alone), replay marker while `isReplaying`, missed-updates banner with Reload (disabled while `isReplaying`; it calls `resumeSession` with `replayFrom: .start` through the existing `SessionModel.startRequest`, so a failure adds an error entry), and the "history can be partial" note while `history` is `.retained` and no replay runs.
    - New internal `StatusBar` view: the glass bar that both banners use, so the bar layout is in one place.
    - `AgentThreadView` session path shows `SessionStreamBanner` above the conversation; `ConversationView` session path shows `StateBanner(session:)` below the list, and its Show Error scrolls to the row key of the error entry.
    - Composer: `ComposerTurn.isSessionClosed` reads `SessionModel.isClosed`; `PromptInputView` is disabled and `submit` sends nothing while it is true.
    - `ScriptedSession.open` has a `bufferLimits` input for the overflow test.

    DIVERGENCE for the owner to confirm: the model holds no working directory for an open session, and `ResumeSessionRequest` requires `cwd`. Thus `AgentThreadView.init(session:connection:workingDirectory:actions:)` has a new optional `workingDirectory` input (default `nil`; with `nil` there is no Reload button). The kit keeps no copy; the host gives the `cwd` of its own `session/new` request. If the owner wants the model to hold the cwd, that is a FoundationModelsACPClient change.

    Test note: in the overflow test, `isReplaying` becomes true before the `session/resume` frame reaches the agent (`beginReplay` runs before the send). Wait for the frame, not for `isReplaying`.
  timestamp: 2026-10-06T18:49:07.516371+00:00
- actor: claude-code
  id: 01m498rq7n5mbb76z53spdwsqg
  text: |-
    ### implement — changed
    - evidence: 10 files — Sources/AgentViewKit/Status/StateBanner.swift, Sources/AgentViewKit/Status/SessionStreamBanner.swift (new), Sources/AgentViewKit/Status/StatusBar.swift (new), Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Thread/SessionTranscriptEnvironment.swift, Sources/AgentViewKit/Input/PromptInputView.swift, Sources/AgentViewKit/Input/ThreadActionTasks.swift, Sources/AgentViewKitTestSupport/ScriptedSession.swift, Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift (new). `swift test --filter SessionStateBannersHostedTests`: 6 of 6 pass. Full `swift test`: 1319 tests in 122 suites, 77 in 12 suites and 1 in 1 suite pass; no warnings other than the expected deprecation and mlx-swift ones. README and demo not changed.
    - next: /review. The owner must confirm the new `workingDirectory` input of AgentThreadView (see the comment above).
  timestamp: 2026-10-06T18:49:11.157867+00:00
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
- 01M443GNSTVHXNPFNPG33W402N
- 01M48MQ0BVDHNY798PTF3VYEQH
position_column: doing
position_ordinal: '80'
title: 'Bind the state banners to SessionModel: agentState, replay marker, missed updates with Reload, closed thread'
---
## What
Source: update.md §4.2 (`agentState`), §4.7 ("Agent state", "Resume", "Missed updates", "Closed thread"), §5 (`replayFrom`), §9.2. Owner rule (2026-10-06): the banners bind directly to the observable model of FoundationModelsACPClient. They show what `SessionModel` holds and call the model methods. The kit keeps no copy of the state, does no turn tracking (no "turn started" or "turn ended" state of its own), and keeps no "reload in progress" flag that the model already holds.

- [x] `StateBanner` (`Sources/AgentViewKit/Status/StateBanner.swift`) takes the `SessionModel` and reads `SessionModel.agentState` (`StateUpdate?`) directly in its body: `.running`, `.idle` with its `stopReason` (use the stop reason table of the stop reason task with `StopReason.unknown(String)`), `.requiresAction`, and a general state for `.unknown(String, JSONValue)`. Remove the kit `ThreadState` use from the session path. The "Show Error" action finds the last `ErrorEntry` in `SessionModel.transcript`; the kit keeps no error list.
- [x] Show a replay marker while `isReplaying` is true. After a resume, show a "history can be partial" note from `history` (`SessionHistory`). Never say that the history is complete.
- [x] When `hasMissedUpdates` is true, show a banner with a "Reload" action. The action calls `ConnectionModel.resumeSession(_:)` with `replayFrom: .start`. The banner goes away only when the model clears `hasMissedUpdates`.
- [x] When `isClosed` is true, show a closed state. The composer reads `isClosed` directly to disable itself.

## Acceptance Criteria
- [x] Each `agentState` value that the model reports shows its banner with no other step; `.idle(_truncated)` shows the truncated text. A new value replaces the banner.
- [x] A buffer overflow in a test (small `bufferLimits`) shows the missed-updates banner. Reload sends `session/resume` with `replayFrom` start, and the banner goes away after the model clears `hasMissedUpdates`.
- [x] A closed session shows the closed state, and the composer is disabled.
- [x] No source in `Sources/AgentViewKit/Status/` keeps a copy of `agentState`, `hasMissedUpdates`, `isReplaying`, `history` or `isClosed`.

## Tests
- [x] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`: one test for each criterion. The scripted agent sends each state; the test asserts the banner text after each change. Use `connect(over:logger:bufferLimits:client:)` with small limits for the overflow test, and assert the `session/resume` frame for Reload.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.