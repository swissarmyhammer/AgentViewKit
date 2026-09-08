---
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ABXR3PMT1VCWPJK80Z9E8
- 01M21ACSE9JBXMRD2FQQD4CYR6
- 01M21BDG310SH8A60AFWXKPSDC
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: todo
position_ordinal: 8d80
title: 'RouterThreadSource: SessionEvent stream, elicitation path, PersistableStructuredSegment conformance (plan §3.3)'
---
## What
Create `Sources/AgentViewKitRouter/RouterThreadSource.swift`, `RouterThreadActions.swift`, `SessionEventMapping.swift`, and `Catalog+Router.swift`, per plan.md §3.3.

- `SessionEventMapping.changes(for event: SessionEvent) -> [ThreadChange]`: a pure function over `FoundationModelsRouter.SessionEvent` (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/SessionEvent.swift`). Map text, reasoning, tool call, tool status and report, compaction to `.compaction`, `turnEnded(TokenUsage)` to `setUsage`, and `elicitationRequested(OperationEvent)` to `addElicitation`. Unknown events become `.unknown`.
- `RouterThreadSource` (`@MainActor`): takes a `RoutedSession`, seeds from `SessionProjection.transcript` (its four-case entry model, ids as given, `provisional-` ids replaced on `entryRecorded`), then consumes `streamSessionEvents()`.
- `RouterThreadActions: AgentThreadActions`, one behavior per verb: `send` through the session prompt path; `cancel` through the session cancel; `respond(to: ElicitationRequest,_:)` through `RoutedSession.respond(elicitationId:response:)` for form mode and `RoutedSession.complete(elicitationId:)` for URL mode, with `ElicitationResult` mapped to `FoundationModelsExtras.ElicitationResponse`; `connect(request)` presents the URL through the injected `AuthorizationPresenter` and then calls `complete(elicitationId:)` with the id from `request.meta["elicitationId"]`; `respond(to: PermissionRequest,_:)`, `setConfigOption`, `login`, `runTerminalAuth`, and `logout` log at `debug` and return, because the Router has no permission gate, config options, or auth methods.
- `Catalog+Router.swift`: conform each catalog payload to `PersistableStructuredSegment` with `schemaName` equal to the catalog name, so the Router persists and restores them.

## Acceptance Criteria
- [ ] Every `SessionEvent` case has a mapping test.
- [ ] An `elicitationRequested` event appears in `thread.pendingElicitations` and `respond` calls the session with the same id.
- [ ] `connect` calls the fake presenter once and then `complete(elicitationId:)` with the meta id.
- [ ] Each of the five no-op verbs returns without a throw and the fake session records no call.
- [ ] A catalog payload round-trips through `PersistableStructuredSegment.structuredSegment` and back.

## Tests
- [ ] `Tests/AgentViewKitRouterTests/SessionEventMappingTests.swift`: one test per case with synthetic events.
- [ ] `Tests/AgentViewKitRouterTests/RouterThreadSourceTests.swift`: a fake `RoutedSession` that records calls; scripted event stream.
- [ ] `Tests/AgentViewKitRouterTests/RouterThreadActionsTests.swift`: one test per verb.
- [ ] `Tests/AgentViewKitRouterTests/CatalogRouterTests.swift`: round-trip per payload.
- [ ] `swift test --filter AgentViewKitRouterTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.