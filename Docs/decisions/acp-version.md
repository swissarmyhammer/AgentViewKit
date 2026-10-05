# ACP protocol version (R6)

Status: decided. Source: plan.md §3.3, §11 decision 20, and §14 R6.

This file records the ACP versions that agents and clients speak today, and
the versions that the ACP adapter of `AgentViewKit` accepts.
`Tests/AgentViewKitTests/ACP/ProtocolVersionTests.swift` reads the
`supported:` line and compares it with
`SupportedProtocolVersions.values`. Keep the form of the `supported:` line: a
list of integers in backticks, with a comma between two integers.

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
  `schema-v2.0.0-alpha.7`: FoundationModelsACP `fe0d82d` (update.md §5). The
  earlier pin was `schema-v2.0.0-alpha.3`.
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
- The thread model follows the v2 update stream (plan.md §3.2, §11 decision
  3). v1 has no `tool_call_update` upsert with `PatchField`, no agent-owned
  terminals, no `state_update`, and no `usage_update` with cost. A v1 adapter
  must make these records from other v1 messages.
- The first agent of the kit is FoundationModelsACPAgent, which speaks v2.

The result: `ACPThreadSource` cannot show Claude Code, Codex, or Gemini CLI
today. Each of these agents answers `initialize` with `1`, and the source
shows one error record that names the sent version and the received version.

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
| `NewSessionResponse.availableCommands` and `ResumeSessionResponse.availableCommands` are new and optional. | `ConnectionModel` seeds the commands of the session model from the response. `ACPThreadSource` seeds the thread from the session model. |
| `ResumeSessionRequest.replayFrom` means the retained history. No value means no replay. `{"type": "start"}` means all retained history. | A resume sends `replayFrom: .start`. The agent decides how much history it retains, so the replayed history can be partial. |

## Adapter

- `SupportedProtocolVersions.values`
  (`Sources/AgentViewKit/ACP/SupportedProtocolVersions.swift`) lists the
  integers that the kit accepts.
- `ACPThreadSource.initialize(over:request:)` sends `initialize` through the
  `ConnectionModel` of FoundationModelsACPClient. When the agent answers with
  a version that is not in the list, or when the wire package throws
  `ProtocolVersionMismatchError`, the source adds one `.error` record that
  names the two versions, and `run()` reads no update.
- `ACPThreadSource.acceptProtocolVersion(_:requested:)` does the same check
  for a host that sends `initialize` itself.
