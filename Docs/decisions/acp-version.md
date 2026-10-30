# ACP protocol version (R6)

Status: decided. Source: plan.md §3.7, §11 decision 20, and §14 R6.

This file records the ACP versions that agents and clients speak today, and
the versions that the ACP adapter of `AgentViewKit` accepts. The
`supported:` line matches `SupportedProtocolVersions.values`.

supported: `2`

## Protocol status

- ACP has two protocol version integers: `1` and `2`. The value is a bare
  integer in the `protocolVersion` field of `initialize`.
- v1 is the stable line. The latest stable schema is `schema-v1.21.0`
  (2026-08-20). The Rust schema crate `agent-client-protocol-schema` 1.7.0
  (2026-08-20) has `ProtocolVersion::LATEST = V1`. `V2` is available only
  behind the `unstable_protocol_v2` feature.
- v2 is a draft. The migration guide tells each side to keep v1 and to add v2
  behind version negotiation and feature flags. The kit builds against
  `schema-v2.0.0-alpha.8`: FoundationModelsACP `5f94484` and
  FoundationModelsACPClient `24643be` (plan.md §3.8). The earlier pins were
  `schema-v2.0.0-alpha.7` (FoundationModelsACP `fe0d82d`) and
  `schema-v2.0.0-alpha.3`.
- When a client sends `2` and the agent answers `1`, the client continues
  with v1 or disconnects.

Sources, read on 2026-09-16:

- https://agentclientprotocol.com/protocol/v2/migration
- https://github.com/agentclientprotocol/agent-client-protocol/releases
- https://crates.io/crates/agent-client-protocol-schema

## Survey

| peer | role | ACP library | protocol version | source | checked |
|---|---|---|---|---|---|
| Claude Code (`claude-agent-acp` 0.78.0, 2026-09-15) | agent | `@agentclientprotocol/sdk` 1.4.0 | `1` | https://github.com/agentclientprotocol/claude-agent-acp/blob/main/package.json | 2026-09-16 |
| Codex (`codex-acp` 1.12.0, 2026-09-15) | agent | `@agentclientprotocol/sdk` ^1.4.0 | `1` | https://github.com/agentclientprotocol/codex-acp/blob/main/package.json | 2026-09-16 |
| Gemini CLI (0.62.0 nightly, 2026-09-15) | agent | `@agentclientprotocol/sdk` 0.16.1 | `1` | https://github.com/google-gemini/gemini-cli/blob/main/packages/cli/package.json | 2026-09-16 |
| Zed | client | Rust `agent-client-protocol` =2.1.0 with the `unstable` feature, on schema crate 1.7.0 | `1` | https://github.com/zed-industries/zed/blob/main/Cargo.toml | 2026-09-16 |
| Xcode 27 | client | not published | `1` (inferred) | https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes | 2026-09-16 |
| FoundationModelsACPAgent | agent | `../FoundationModelsACP` | `2` | `../FoundationModelsACP/Sources/FoundationModelsACP/Core/ProtocolVersion.swift` | 2026-09-16 |

Notes on the table:

- `@agentclientprotocol/sdk` 1.4.0 (2026-08-20) and 0.16.1 both export
  `PROTOCOL_VERSION = 1`
  (https://github.com/agentclientprotocol/typescript-sdk/blob/main/src/schema/index.ts).
- The `unstable` feature of the Rust crate `agent-client-protocol` 2.1.0 does
  not include `unstable_protocol_v2`. The major version 2 of that crate is the
  version of the SDK, not the version of the protocol.
- Apple does not publish the ACP version of Xcode 27. Xcode 27 runs Claude
  Code and Codex through their ACP adapters, and these adapters speak only
  v1. Thus Xcode 27 speaks v1. This row is an inference, not a documented
  value.
- No surveyed third-party agent or client speaks v2 today.

## Decision

v2 only. The kit accepts protocol version `2` and refuses each other version.

Reasons:

- The wire package `../FoundationModelsACP` implements v2 only. It has no v1
  types, and its `ClientSideConnection.initialize(_:)` throws
  `ProtocolVersionMismatchError` when the agent answers with a version that
  the client did not send. A v1 adapter needs a v1 wire package first. That
  work belongs to the FoundationModelsACP repository, not to this kit.
- The client models follow the v2 update stream (plan.md §3.2, §11 decision
  3). v1 has no `tool_call_update` upsert with `PatchField`, no agent-owned
  terminals, no `state_update`, and no `usage_update` with cost. A v1 adapter
  must make these values from other v1 messages.
- The first agent of the kit is FoundationModelsACPAgent, which speaks v2.

The result: the kit cannot show Claude Code, Codex, or Gemini CLI today. Each
of these agents answers `initialize` with `1`, and the kit refuses the agent
with an error that names the sent version and the received version.

Do this decision again when one of these events occurs:

- FoundationModelsACP adds a v1 surface. Then add `1` to the `supported:`
  line and write a v1 adapter.
- A surveyed agent starts to speak v2.
- Upstream marks v2 as stable.

## Schema alpha.7

The protocol version integer stays `2`. The schema changes from alpha.3 to
alpha.7 change these parts of the wire:

| change | effect on the kit |
|---|---|
| `PromptResponse.messageId` is required. It is the id of the user message that the agent added. The agent echoes that message in a `user_message` update with the same id, before or after the response. | A prompt result with no `messageId` does not decode. The scripted demo agents send a `messageId` and echo the user message. |
| `ToolCallUpdate.name` is new and optional, with patch rules. It is the program name of the tool. `title` stays the label for people. | The tool call views select the registry entry by `name` and show `title` as the label (a later view task). |
| `NewSessionResponse.availableCommands` and `ResumeSessionResponse.availableCommands` are new and optional. | `ConnectionModel` seeds the commands of the session model from the response. The views read the commands from the session model. |
| `ResumeSessionRequest.replayFrom` means the retained history. No value means no replay. `{"type": "start"}` means all retained history. | A resume sends `replayFrom: .start`. The agent decides how much history it retains, so the replayed history can be partial. |

## Schema alpha.8

The protocol version integer stays `2`. FoundationModelsACP `5f94484`
vendors `schema-v2.0.0-alpha.8` (commit `dc336cb`). The schema changes from
alpha.7 to alpha.8 change these parts of the wire:

| change | effect on the kit |
|---|---|
| `StopReason` has the new value `error`. The agent sends it when the active work fails after the agent inserted the user message. A failure before that point is an error response to `session/prompt`. | `StateBanner` shows "The response failed" with the identifier `state-banner-error`. The VoiceOver announcement of the end of the work of a prompt speaks the same title. Before, a switch over `StopReason` did not compile. |
| `IdleStateUpdate.error` is new and optional. It is a JSON-RPC error object (`code`, `message`, `data`). | When the stop reason is `error` and the agent gives the error object, `StateBanner` shows its `message` in the explanation. With no error object, the bar shows a general explanation. |
| The `notice`, `compaction_update` and `compaction_summary_chunk` session updates are stable. Their wire names and their fields do not change. | The Swift types are top-level types now: `CompactionId`, `CompactionStatus`, `CompactionUpdate`, `CompactionSummaryChunk`, `Notice` and `NoticeSeverity`. The `Unstable.` prefix is gone from `AgentTheme`, `CompactionEntryView`, `SessionNoticeBanner` and the tests. FoundationModelsACPClient `24643be` uses the same names. |

The other commits in `b2cec56..5f94484` change the behavior of the
connections, not the wire. Their effect on the kit:

| commit | change | effect on the kit |
|---|---|---|
| `7b3ee45` (breaking) | `AgentSideConnection.insertUserMessage(_:messageId:into:)` takes a history closure. The connection calls it only after a success response. | None. `InMemoryDemoACPAgent` uses `insertUserMessage(_:)`, which has no history closure. Its replayed history is the fixed script of `InMemoryDemoAgent`. |
| `6181fe3` | The connection sends no `user_message` echo when the prompt handler fails. | None. The prompt handler of the demo agent does not fail after it inserts the user message. |
| `dd8996e` | `AgentSideConnection.sessionUpdate(_:)` refuses an update that breaks a schema rule: a custom stop reason that does not start with `_`, a negative `size` or `used`, or a cost currency that is not three capital letters. | None. The demo agent sends `end_turn`, counts of zero or more, and no cost. `ScriptedWireAgent` writes raw frames, so the tests can still send each value that a client must accept. |
| `a8736dc` | `ClientSideConnection` answers each pending `session/request_permission` request of a session with `cancelled` when the client cancels the session. The first answer wins. | None. `SessionModel.cancel(meta:)` of FoundationModelsACPClient already answers each pending permission with `cancelled` before it sends `session/cancel`. |
| `1cc2dd5` | `ClientSideConnection.promptWithEcho(_:)` is new. | None. The kit sends prompts through the `SessionModel` of FoundationModelsACPClient. |
| `5f94484` | `EventBroadcaster` yields the events outside its state lock. | The deadlock of the event stream (task ^06hz99g) is gone. |

## Adapter

- `SupportedProtocolVersions.values`
  (`Sources/AgentViewKit/ACP/SupportedProtocolVersions.swift`) lists the
  integers that the kit accepts.
- `ConnectionModel.initializeCheckingProtocolVersion(_:)` sends `initialize`
  through the `ConnectionModel` of FoundationModelsACPClient. When the agent
  answers with a version that is not in the list, or when the wire package
  throws `ProtocolVersionMismatchError`, the call throws
  `UnsupportedProtocolVersionError`, which names the two versions.
- `SupportedProtocolVersions.accept(_:requested:)` does the same check for a
  host that sends `initialize` itself.
