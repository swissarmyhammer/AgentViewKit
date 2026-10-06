---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m48rj3dq5z3z54yrj30jwj59
  text: 'Note from ^rdk4w45: `ACPSessionList` and `ACPSessionListTests` are already removed. The session picker binds to `ConnectionModel.sessions`, so this card has no session list file to remove. `ACPThreadSource.resumeSession(_:cwd:on:thread:agentName:)` now has only its test as a caller.'
  timestamp: 2026-10-06T14:05:57.047344+00:00
depends_on:
- 01M443S0EDEB23N7RPAR39TGZ5
- 01M443RTQWKFHNWK4SH96PTE46
- 01M48MQS1Q5HBNDFMBD2CT0C6C
- 01M48MR5W3YAB8VFA4KTJZVCYN
- 01M48MRPTCY92MXNFB1XZHAA2A
position_column: todo
position_ordinal: a080
title: 'Remove the ACP adapter: ACPThreadSource, SessionUpdateMapping, ACPSessionList and ACPThreadActions'
---
## What
When all view groups, the demo app and the README snippets use `SessionModel` and `ConnectionModel`, the bridge of the pin-move task has no user. Source: update.md §4.5 (rows 2, 3, 4, 6, 7). This also removes the double fold of each update. Owner rule (2026-10-06): each view binds directly to the observable model of FoundationModelsACPClient and calls the model methods. After this task no kit code converts a model value into a kit copy.

- [ ] Delete `Sources/AgentViewKit/ACP/ACPThreadSource.swift`, `SessionUpdateMapping.swift`, `ACPSessionList.swift`, `TranscriptSeed.swift` (only `ACPThreadSource` uses it), and the deprecated `AgentThreadView(thread:actions:)` initializer.
- [ ] Before the delete, make sure that no file outside `Sources/AgentViewKit/ACP/` calls `SessionUpdateMapping` (the three content tasks remove the calls in the entry views and the request cards). If a call stays, move it to the task that owns its view; do not add a new kit conversion.
- [ ] Delete `ACPThreadActions.swift`, or reduce it to what the views still need that the models do not give (for example the terminal auth process). Each view calls the model methods directly.
- [ ] Move the protocol version check: `ACPThreadSource.acceptProtocolVersion` goes to `Sources/AgentViewKit/ACP/SupportedProtocolVersions.swift` (or to the caller of `ConnectionModel.initialize(_:)`). Change `ProtocolVersionTests` to call the new place.
- [ ] Delete their tests: `ACPThreadSourceTests`, `SessionUpdateMappingTests`, `SessionUpdateFixtures`, `ACPSessionListTests`, `ACPThreadActionsTests`, and the tests of `TranscriptSeed`. Change `AgentViewKitACPModuleTests` and `ScriptedWireAgent+Bounded.swift` where they use the removed types. Move each test that still checks view behaviour into the view test of its group, as a binding test: a model change shows in the view, and a view action calls the model method.
- [ ] Add `ACPThreadSource`, `SessionUpdateMapping`, `ACPSessionList` and `TranscriptSeed` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [ ] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` refers to the removed types or the old initializer.
- [ ] No source in `Sources/AgentViewKit/` converts a `TranscriptEntry` value, a pending request or a `ConnectionModel` value into a kit copy.
- [ ] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `ProtocolVersionTests` passes against the new place of the version check.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.