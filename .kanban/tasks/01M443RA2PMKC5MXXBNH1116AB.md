---
assignees:
- claude-code
depends_on:
- 01M443S0EDEB23N7RPAR39TGZ5
- 01M443RTQWKFHNWK4SH96PTE46
position_column: todo
position_ordinal: a080
title: 'Remove the ACP adapter: ACPThreadSource, SessionUpdateMapping, ACPSessionList and ACPThreadActions'
---
## What
When all view groups, the demo app and the README snippets use `SessionModel` and `ConnectionModel`, the bridge of the pin-move task has no user. Source: update.md §4.5 (rows 2, 3, 4, 6, 7). This also removes the double fold of each update.

- [ ] Delete `Sources/AgentViewKit/ACP/ACPThreadSource.swift`, `SessionUpdateMapping.swift`, `ACPSessionList.swift`, and the deprecated `AgentThreadView(thread:actions:)` initializer.
- [ ] Delete `ACPThreadActions.swift`, or reduce it to what the views still need that the models do not give. Each view calls the model methods directly.
- [ ] Move the protocol version check: `ACPThreadSource.acceptProtocolVersion` goes to `Sources/AgentViewKit/ACP/SupportedProtocolVersions.swift` (or to the caller of `ConnectionModel.initialize(_:)`). Change `ProtocolVersionTests` to call the new place.
- [ ] Delete their tests: `ACPThreadSourceTests`, `SessionUpdateMappingTests`, `SessionUpdateFixtures`, `ACPSessionListTests`, `ACPThreadActionsTests`. Change `AgentViewKitACPModuleTests` and `ScriptedWireAgent+Bounded.swift` where they use the removed types. Move each test that still checks view behaviour into the view test of its group.
- [ ] Add `ACPThreadSource`, `SessionUpdateMapping` and `ACPSessionList` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [ ] No file in `Sources/`, `Tests/`, `Examples/` or `README.md` refers to the removed types or the old initializer.
- [ ] `swift test`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `ProtocolVersionTests` passes against the new place of the version check.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.