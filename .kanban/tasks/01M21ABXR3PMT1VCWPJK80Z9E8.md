---
depends_on:
- 01M21A9KJGPPJE0X01JE0B9V33
position_column: todo
position_ordinal: '8780'
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
- [ ] Every payload round-trips through JSON and compares equal.
- [ ] `decode` of an unknown name returns nil, never throws.
- [ ] `catalog.md` names every registered schema name and every stored property of every payload; a test compares both lists with `Mirror`.

## Tests
- [ ] `Tests/AgentViewKitTests/Catalog/StructuredCatalogTests.swift`: round-trip per payload, unknown name, and the doc-list match.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.