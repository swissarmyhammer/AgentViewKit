---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4qatsqd7zmtn4enrwp5s877
  text: |-
    Research (read only, ../FoundationModelsACPAgent at a6e97db):
    - A resume with replayFrom start replays the SessionMergeEngine history (session-history.json). The engine keeps entries; it keeps only the last value of state_update, usage_update, commands, config and session info. It never keeps notices.
    - session/request_permission: the agent never sends it. The Seatbelt sandbox is the only gate. No permission mode exists.
    - elicitation/create (form and URL): the agent sends it only when the model calls elicit() in code mode, or an MCP server elicits. It is a live request. It is not a session update, so a resume never replays it.
    - plan_update: the wiring exists (ToolContext.progress with a PlanSnapshot), but no production tool sends a plan. A plan needs a change in FoundationModelsACPAgent.
    - compaction_update: automatic compaction needs the live model. The /compact command works with the stub model.
    - notice: the agent never sends it.
    - Errors: idle state with stopReason error and an ACPError. Needs a real failure.
    - Attachments: resource and resource_link are replayed in user_message. Image and audio are not advertised.
    - Stop reasons: cancelled works with the paced stub model. refusal, max_tokens and the extension reasons need the live model. max_turn_requests has no producer.
    - Auth and connection: the agent advertises no authMethods and no auth capability. It never answers -32000.
    - Live model: MLX Qwen 27B and two other models (32 GB machine), not Apple SystemLanguageModel.
    - Stub: ACP_AGENT_STUB_MODEL=1 (EchoModel, no download) and ACP_AGENT_STUB_CHUNK_DELAY_MS (paced echo).

    Recording done with the stub model (no download, no long run, no change in the agent): 3 sessions in Examples/AgentViewKitDemo/RecordedSessions/stub-model-kinds, copied as they are. They give attachments (resource and resource_link), a /compact compaction entry, and the cancelled stop reason. A resume of each session with the agent and no stub replays them (checked with an ACP client script in the scratchpad).
  timestamp: 2026-10-12T05:54:38.445172+00:00
- actor: claude-code
  id: 01m4qbn5xyg2k44cf75pqy33wf
  text: |-
    ### implement — changed
    - evidence: new Sources/DemoSupport/{InMemoryDemoScript,DemoGallerySession,DemoGallery,DemoConnectionState}.swift; changed InMemoryDemoACPAgent.swift (script: scripted sessions, live permission and elicitation requests after each resume, rejected sign-in), InMemoryDemoAgent.swift (initialize with or without the sign-in method, list with the scripted sessions), DemoAgent.swift (public makeInProcess(script:workingDirectory:)), Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift (three sidebar sections: recorded, scripted, connection states), README.md and RecordedSessions/README.md; new recording RecordedSessions/stub-model-kinds (3 sessions of FoundationModelsACPAgent with its stub model, copied with cp -Rp); new Tests/AgentViewKitTests/ACP/DemoGalleryTests.swift (each scripted session and each connection state opens with a transcript; no content assertion).
    - Sources: attachments (resource, resource_link), /compact compaction and stop reason cancelled from FoundationModelsACPAgent (stub model). Permission, form and URL elicitation, plan, compaction of each status, notices of each severity, error, image attachment, 10 other stop reasons, and 4 sign-in and connection states from InMemoryDemoACPAgent. The card description lists each kind, the kinds that no source produces, and the owner steps for the live-model kinds.
    - Mutation check: with the history replay broken, all 18 scripted-session test cases failed; reverted.
    - swift test: 1163 tests in 129 suites passed (2 expected known issues), plus 118 PackageStructureTests and 1 ReadmeSnippets test; PackageStructureTests passed again (118) after the README edits. Load average 20.09 at the start, 13.20 at the end.
    - Demo: generate_xcodeproj.rb, then xcodebuild build-for-testing: TEST BUILD SUCCEEDED, no warning from the changed files. UI tests not run (rule).
    - Note: swift build prints "warning: missing creator for mutated node ... .build/out/Products/Debug/mlx-swift_Cmlx.bundle". It comes from old MLX products in .build/out, not from this change. I did not touch .build.
    - next: /review
  timestamp: 2026-10-12T06:09:02.910709+00:00
depends_on:
- 01M4P3B7BKPXEKTY742X7JCAT5
position_column: doing
position_ordinal: '80'
title: 'Demo Gallery: the entry kinds and states that the recorded sessions do not have'
---
## What
The recorded SWE-bench sessions of the Gallery card have no user interaction. They do not show permission requests, form and URL elicitations, plans, compaction, notices of each severity, errors, attachments, the other stop reasons, or connection and sign-in states. To judge the look of these views, the Gallery needs sessions that have them.

Owner rules (2026-10-11): use a real session model; do not write a new replay agent that gets out of step with FoundationModelsACPAgent; no assertions on the content of fixture sessions.

## Work
- [x] Find the best source for each missing kind: a recorded FoundationModelsACPAgent session that has it (preferred: record new sessions with FoundationModelsACPAgent that ask for permission, use a plan, compact, and so on, and copy them in as they are), or the existing `InMemoryDemoACPAgent` of `DemoSupport` where FoundationModelsACPAgent cannot produce the kind.
- [x] Add these sessions to the Gallery next to the SWE-bench sessions.
- [x] Record each kind that no source can produce, and why.

## Source of each kind
Recorded with FoundationModelsACPAgent and its stub model (`ACP_AGENT_STUB_MODEL=1`, no download, no change in the agent). The files are in `Examples/AgentViewKitDemo/RecordedSessions/stub-model-kinds`, copied as they are:
- Attachments: `resource_link` and `resource` blocks in a user message.
- Compaction: a `completed` compaction entry from the `/compact` command.
- Stop reason `cancelled`.

From `InMemoryDemoACPAgent` with the `gallery` script (`DemoGallery`, the "Scripted Sessions" section of the Gallery):
- Permission request: the agent never sends `session/request_permission`.
- Form elicitation and URL elicitation: the agent sends them only in a live turn, and a resume does not replay a request.
- Plan: no tool of the agent sends a plan. A plan needs a change in FoundationModelsACPAgent.
- Compaction of each status (completed with a summary, failed, cancelled, in progress): the agent makes only some of them, and only with the live model.
- Notices of each severity: the agent never sends a notice, and its history does not keep notices.
- Error: an idle state with stop reason `error` and an error object, and a failed tool call. The agent makes it only after a real failure.
- Attachments with an image: the agent does not advertise images.
- Stop reasons `max_tokens`, `max_turn_requests`, `refusal`, `_truncated`, `_ended_in_reasoning`, `_repeated`, `_reasoning_limit`, `_error`, `_no_output`, `_stalled`: each needs the live model, and `max_turn_requests` has no producer.

From `InMemoryDemoACPAgent` with the real `ConnectionModel` (`DemoConnectionState`, the "Connection States" section):
- Sign-in required (`authState` `.required`), signed in (`.authenticated`), sign-in failed (`.failed` with the request error), disconnected (connection state `.disconnected`, with a failed prompt and its error entry). FoundationModelsACPAgent has no auth methods and never answers `-32000`.

## Kinds that no source produces
- Connection state `.failed`: it needs a transport failure. The in-process transport closes with no failure, and FoundationModelsACPAgent does not make one. Only a fault transport (a fake) can make it.
- Connection state `.connecting`: it lasts only during the connect, so the Gallery cannot hold it.
- Sign-in state `.reconnectRequired`: it needs a `terminal` auth method and a terminal sign-in. FoundationModelsACPAgent has no auth method, and the in-process agent has no terminal sign-in runner.
- A live permission request or elicitation in a recorded session: a resume never replays a request. Only a live agent shows the card.

## Owner steps: record the live-model kinds
These need the live MLX model (the 27B default profile loads about 15 GB, and a turn is long). They were not run. For each run: make a scratch root with `work`, `transcripts` and `config/acp-agent/config.yaml` (`transcripts: location: "<root>/transcripts"`), start `../FoundationModelsACPAgent/.build/release/acp-agent acp` in `work` with `XDG_CONFIG_HOME=<root>/config` and no stub variable, send `initialize`, `session/new`, the prompts, then `session/close`, and copy `<root>/transcripts` into `RecordedSessions` with `cp -Rp`.
- Automatic compaction: set `compaction.trigger` and `compaction.target` low in `config.yaml` (for example 0.05 and 0.02), and send three long prompts.
- Stop reason `max_tokens`: send a prompt that is larger than the context of the model.
- Stop reason `refusal`: send a prompt that the guardrail of the model refuses.
- Stop reason `error`: start a turn when the model cannot load.
- Extension stop reasons (`_truncated`, `_repeated`, `_reasoning_limit`, `_no_output`, `_stalled`, `_ended_in_reasoning`): they depend on the output of the model, so no prompt makes them each time. Keep the runs that end with one.
- Plans: first add a tool to FoundationModelsACPAgent that calls `ToolContext.progress(_:plan:)`. Then record a turn that uses the tool.