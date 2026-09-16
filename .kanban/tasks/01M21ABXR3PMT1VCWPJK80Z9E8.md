---
comments:
- actor: claude-code
  id: 01m2na1k1a50axx4mvvm24g5qg
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 8 new files in Sources/AgentViewKit/Catalog (StructuredPayload, StructuredCatalog, 6 payloads, catalog.md); PlanEntry and the ContextUsage parts are now Codable; Package.swift excludes catalog.md.
    - test: green — swift test, 211 tests pass (188 in AgentViewKitTests), no new warnings.
    - commit: 92c58c3
    - review: clean — review sha HEAD~1..HEAD, 0 findings.
    - decisions: (1) A WireValueEnum that is Codable encodes as its wire string; an unknown string decodes to `unknown`, so PlanEntry keeps new ACP values. (2) ContextUsage.Quota encodes as `{"status": "belowLimit", "approaching": bool}` or `{"status": "limitReached"}`; another status is a decode error, because Quota has no unknown case (usage-model decision). (3) StructuredPayload adds `init(content:)`, `jsonValue()`, and `isEqual(to:)`. (4) The AuthorizationRequest conversion stays with the source tasks (^d317w6 has the type). (5) catalog.md also documents PlanEntry, CitationSource, CitationMarker, and the ContextUsage parts; the test checks each with Mirror.
  timestamp: 2026-09-16T14:30:59.882612+00:00
depends_on:
- 01M21A9KJGPPJE0X01JE0B9V33
position_column: done
position_ordinal: '8980'
title: 'schemaName catalog: Codable payloads for approval, plan, citation, artifact, authorization, usage (plan §3.3, §11#5)'
---
## What
Create `Sources/AgentViewKit/Catalog/` with one `Codable & Sendable & Equatable` payload per custom structured segment, per plan.md §3.3 and decision 5.

- `ApprovalPayload { id, title, description, options: [String] }`.
- `PlanPayload { id, entries: [PlanEntry] }`.
- `CitationPayload { sources: [CitationSource]; markers: [CitationMarker] }`. `CitationSource { id, title, url, snippet, iconURL? }`. `CitationMarker { sourceID, paragraphIndex, offset }`. `SourcesView` and `InlineCitation` read these fields.
- `ArtifactPayload { id, title, type (UTType identifier string), url? , inlineText? }`.
- `AuthorizationPayload { id, serverName, scopes, authorizationURL, elicitationId? }`. The sources turn it into an `AuthorizationRequest` with `elicitationId` in `meta`.
- `UsagePayload` with the `ContextUsage` fields.
- `StructuredCatalog`: a registry from `schemaName` string to a decoder closure `(JSONValue) throws -> any StructuredPayload`. Schema names are full type names in the form `AgentViewKit.<Payload>`, the same convention as `FoundationModelsRouter.OperationEventSegment` in `../FoundationModelsRouter/Sources/FoundationModelsRouter/Recording/PersistableStructuredSegment.swift`.
- `StructuredCatalog.decode(schemaName:content:)` returns the typed payload or `nil` for an unknown name, so the caller falls back to `StructuredRecord`.
- A `catalog.md` in `Sources/AgentViewKit/Catalog/` lists every name and its payload fields. This is the document the Router agrees to (research R5).

## Acceptance Criteria
- [x] Every payload round-trips through JSON and compares equal.
- [x] `decode` of an unknown name returns nil, never throws.
- [x] `catalog.md` names every registered schema name and every stored property of every payload; a test compares both lists with `Mirror`.

## Tests
- [x] `Tests/AgentViewKitTests/Catalog/StructuredCatalogTests.swift`: round-trip per payload, unknown name, and the doc-list match.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.