---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7t5qn9t8v85071079jp2qb1
  text: |-
    Research (FoundationModelsACPClient checkout, SessionModel.swift):
    - `entry(forWireID:)` reads `transcriptEntriesByWireID`, which is `@ObservationIgnored`. The model has no observable revision of the wire links. `wireEntries` reads the engine, which is also `@ObservationIgnored`.
    - A prompt links in one of two orders:
      1. Response first, echo after (the case of this task). `resolvePrompt` sets `messageId` and `sendState` on the response. Later, the echo arrives: `promptCorrelator.observe` gives the link, `linkPrompt` writes the map, and `addEntry` calls `update(from:)` on the local entry. `assign` writes a field only when the value changes. Thus, when the echo has the same content and meta, no observed value changes.
      2. Echo first (held), response after. The response sets `messageId` (nil to a value) and `sendState` (pending to sent) and links in the same call. These fields are observable.
    - Probe (a temporary test, now deleted): a preview model, `prompt` with `.respond`, then `apply(.userMessageChunk)` of the echo with the same text. Before the echo, `entry(forWireID:)` gave nil. After it, the call gave the local entry. `transcript.count` did not change. `withObservationTracking` on `transcript`, `agentState` and `messageId`, `sendState`, `content` and `meta` of each user message saw NO change.
    - `ScriptedWireAgent` cannot make order 2 with hits between the held echo and the response: the leadIn echo cannot have the message id of the response (the agent gives a random UUID), and `answerPrompt` sends the echo and the result one after the other. `PreviewSessionRequestSender` answers at once or never.
  timestamp: 2026-11-19T15:10:21.498693+00:00
- actor: claude-code
  id: 01m7t5qv7p7hf006xzrxf3yd81
  text: |-
    BLOCKER: no certain signal in AgentViewKit for the link of order 1 (response first, echo after). This is the case of the required test ("hits that come before the echo of their prompt ... when the echo links, with no new entry").
    - The view `TranscriptSearchDriver` evaluates its `onChange` values only when an observed value changes. The probe shows that the echo link changes no observed value. A value that calls `entry(forWireID:)` in the body does not help, because that read is not tracked. A unit test of such a value would pass while the real view stays wrong, so I did not write it.
    - The `updateTap()` stream gives each update before the model folds it, so a lookup on it can run before the link. It is not certain.
    - A signal on the `messageId` of the user messages makes order 2 (held echo) certain, but not order 1. It also has no unit test with the current fixtures.
    Proposed fix (needs a decision, outside this tree): FoundationModelsACPClient `SessionModel` gives an observable value that changes on each change of the wire-id map (for example a `wireLinkRevision: Int` that `linkPrompt`, `appendWireEntry` and the rollback increment, or an observable count of the map). Then the driver adds one `onChange` on that value, and the unit test can check it with no window. A second option: `ScriptedWireAgent` gets a way to send a held echo whose message id the response then gives, for order 2 only.
    No source file changed. The task stays in `doing`.
  timestamp: 2026-11-19T15:10:27.574710+00:00
- actor: claude-code
  id: 01m7t5qxs047wng1my3tk08n9q
  text: |-
    ### implement — stuck
    - evidence: no files changed. Probe `swift test --filter ZZProbeEchoLinkTests` (temporary, deleted): "Test run with 1 test in 1 suite passed"; output "before-unresolved=true after-resolved=true count-same=true observed-change=false".
    - next: a person decides on an observable wire-link revision in FoundationModelsACPClient SessionModel (or accepts a fix for the held-echo order only).
  timestamp: 2026-11-19T15:10:30.176147+00:00
- actor: claude-code
  id: 01m7t5rrdxfyj5wayvm5dm2725
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — no source change. The ACPClient SessionModel changes no observed value when an echo links to its local message (`transcriptEntriesByWireID` is @ObservationIgnored, and an echo with the same text changes no field). AVK has no certain signal.
    - Blocked: the request for an observable `wireLinkRevision` (or a similar value) went to foundationmodelsacpclient-1d on 2026-11-19. Restart the task when that sha is on ACPClient main.
  timestamp: 2026-11-19T15:10:57.469906+00:00
position_column: doing
position_ordinal: '8180'
title: Search hits look up again when a prompt echo links to its local message (D207 f)
---
Found in ^de77446 (ACPClient `entry(forWireID:)` adoption).

Now: the transcript search driver (Sources/AgentViewKit/Thread/TranscriptSearch.swift) looks up the hits again when the session identity changes or when `transcript.count` changes. When the echo of a prompt arrives and links to the local user message, the count does not change. Thus a hit on that prompt that came before the link does not reveal or mark until the next new entry.

Do:
- Look up the hits again also when an entry gets its wire id (for example, observe a value that changes on the link, such as the set of wire ids of the transcript or a revision of the model). Choose the smallest certain signal, and do not look up on each streamed token.
- TDD unit test: hits that come before the echo of their prompt reveal and mark the local message when the echo links, with no new entry.

Run `swift test`. Push, and send the sha to testudoapp-9a.