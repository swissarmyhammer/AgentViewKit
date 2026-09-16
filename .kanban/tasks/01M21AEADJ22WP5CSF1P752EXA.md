---
comments:
- actor: claude-code
  id: 01m2nmdhkjjqnkg6fw8p4dmf0m
  text: |-
    ### Design decisions (implement)
    - The Router protocol `PersistableStructuredSegment` is internal to FoundationModelsRouter (commit ^dvkxz7n and earlier made it internal). An adapter cannot conform to it. plan.md §3.3 says "conforms to the Router's PersistableStructuredSegment shape". So `Catalog+Router.swift` declares a public protocol with the same name and the same shape in AgentViewKitRouter, and `CatalogSegment<Payload>` conforms (typealiases `ApprovalSegment` ... `UsageSegment`). The Router records any `.structure` segment as `SegmentPayload.structure(id:schemaName:contentJSON:)`, so these segments persist and restore with no Router change. A test sends each payload through that persisted form.
    - `RoutedSession` is a large actor protocol. The new `RouterSessionPort` protocol holds only the six calls that the adapter uses. `RoutedSessionPort` sends them to a real session. The tests use `FakeRouterSession`.
    - `streamSessionEvents()` has no text fragments. `send` uses `streamEvents(to:)` and gives only `textDelta` and `textReset` to the source. The session stream gives the other events.
    - A URL-mode `respond(.accept)` sends `respond(accept nil)` and then `complete(elicitationId:)`. The Router ignores `complete` for an id that is not accepted. `ElicitationURLConsentView` (^rqrsb2r) opens the browser before it calls `respond(.accept(nil))`, so the verb does not open a browser.
    - `connect` presents the URL, then sends `respond(accept nil)` and `complete` for `meta["elicitationId"]`, for the same reason. The callback scheme is `meta["callbackScheme"]` or the init value (default `agentviewkit`). No elicitation id: throws `RouterThreadActionsError.missingElicitationId`.
    - `turnEnded` sets `ContextUsage(used: tokensIn + tokensOut, size: used / contextFill)`; size is 0 when the fill is not positive. `FinishReason.completed` maps to `endTurn`.
    - `toolInvocation`, `runSettled`, `discoveryPrimingFailed`, and `generationStalled` become `.unknown` records. `toolCallReport` gives one `.structured` record for each attachment.
    - Known limit: `SessionProjection` drops prompts, so a seeded thread has no user messages.
    - Tests use `@testable import FoundationModelsRouter` in RouterFixtures.swift only, because `TurnStart` has no public init.
  timestamp: 2026-09-16T17:32:17.394867+00:00
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ABXR3PMT1VCWPJK80Z9E8
- 01M21ACSE9JBXMRD2FQQD4CYR6
- 01M21BDG310SH8A60AFWXKPSDC
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: doing
position_ordinal: '8180'
title: 'RouterThreadSource: SessionEvent stream, elicitation path, PersistableStructuredSegment conformance (plan §3.3)'
---
## What
Create `Sources/AgentViewKitRouter/RouterThreadSource.swift`, `RouterThreadActions.swift`, `SessionEventMapping.swift`, and `Catalog+Router.swift`, per plan.md §3.3.

- `SessionEventMapping.changes(for event: SessionEvent) -> [ThreadChange]`: a pure function over `FoundationModelsRouter.SessionEvent` (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/SessionEvent.swift`). Map text, reasoning, tool call, tool status and report, compaction to `.compaction`, `turnEnded(TokenUsage)` to `setUsage`, and `elicitationRequested(OperationEvent)` to `addElicitation`. Unknown events become `.unknown`.
- `RouterThreadSource` (`@MainActor`): takes a `RoutedSession`, seeds from `SessionProjection.transcript` (its four-case entry model, ids as given, `provisional-` ids replaced on `entryRecorded`), then consumes `streamSessionEvents()`.
- `RouterThreadActions: AgentThreadActions`, one behavior per verb: `send` through the session prompt path; `cancel` through the session cancel; `respond(to: ElicitationRequest,_:)` through `RoutedSession.respond(elicitationId:response:)` for form mode and `RoutedSession.complete(elicitationId:)` for URL mode, with `ElicitationResult` mapped to `FoundationModelsExtras.ElicitationResponse`; `connect(request)` presents the URL through the injected `AuthorizationPresenter` and then calls `complete(elicitationId:)` with the id from `request.meta["elicitationId"]`; `respond(to: PermissionRequest,_:)`, `setConfigOption`, `login`, `runTerminalAuth`, and `logout` log at `debug` and return, because the Router has no permission gate, config options, or auth methods.
- `Catalog+Router.swift`: conform each catalog payload to `PersistableStructuredSegment` with `schemaName` equal to the catalog name, so the Router persists and restores them.

## Acceptance Criteria
- [x] Every `SessionEvent` case has a mapping test.
- [x] An `elicitationRequested` event appears in `thread.pendingElicitations` and `respond` calls the session with the same id.
- [x] `connect` calls the fake presenter once and then `complete(elicitationId:)` with the meta id.
- [x] Each of the five no-op verbs returns without a throw and the fake session records no call.
- [x] A catalog payload round-trips through `PersistableStructuredSegment.structuredSegment` and back.

## Tests
- [x] `Tests/AgentViewKitRouterTests/SessionEventMappingTests.swift`: one test per case with synthetic events.
- [x] `Tests/AgentViewKitRouterTests/RouterThreadSourceTests.swift`: a fake `RoutedSession` that records calls; scripted event stream.
- [x] `Tests/AgentViewKitRouterTests/RouterThreadActionsTests.swift`: one test per verb.
- [x] `Tests/AgentViewKitRouterTests/CatalogRouterTests.swift`: round-trip per payload.
- [x] `swift test --filter AgentViewKitRouterTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.