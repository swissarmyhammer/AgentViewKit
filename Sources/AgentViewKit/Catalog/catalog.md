# Structured segment catalog

This document is the agreement between AgentViewKit and
FoundationModelsRouter about custom structured segments (plan.md §3.3,
§11#5, research R5).

A FoundationModels source carries custom content in a `.structure` segment.
The segment has a `schemaName` and a JSON body. `StructuredCatalog.standard`
maps each name below to its payload type. A name that is not in the catalog
gives `nil`, and the source keeps the segment as a raw structured record.

Each name is the full Swift type name, `String(reflecting:)`. The Router
`PersistableStructuredSegment` uses the same convention. Each payload is
`Codable`, `Sendable`, and `Equatable`, which is the `Content` shape of that
protocol. The JSON keys are the field names below.

`StructuredCatalogTests` makes sure that each registered name has a section
and that each section lists every stored property of its type, in
declaration order.

## `AgentViewKit.ApprovalPayload`

A request for the user to approve an action.

| field | type | note |
|---|---|---|
| `id` | string | The identifier of the request. |
| `title` | string | The short title of the action. |
| `description` | string | The full text about the action. |
| `options` | array of string | The labels of the answers, in display order. |

## `AgentViewKit.PlanPayload`

The task list of an agent. A new plan replaces the full entry list.

| field | type | note |
|---|---|---|
| `id` | string | The identifier of the plan in the thread. |
| `entries` | array of `PlanEntry` | The entries, in the order that the agent gave. |

## `AgentViewKit.CitationPayload`

The sources of a response and the places that cite them. `SourcesView` and
`InlineCitation` read this payload.

| field | type | note |
|---|---|---|
| `sources` | array of `CitationSource` | The cited sources, in display order. |
| `markers` | array of `CitationMarker` | The places in the response that cite a source. |

## `AgentViewKit.ArtifactPayload`

A file or document that the agent made. The payload has a `url`, an
`inlineText`, or both.

| field | type | note |
|---|---|---|
| `id` | string | The identifier of the artifact. |
| `title` | string | The title of the artifact. |
| `type` | string | The uniform type identifier, such as `public.plain-text`. |
| `url` | URL string, optional | The location of the artifact. |
| `inlineText` | string, optional | The text of the artifact. |

## `AgentViewKit.AuthorizationPayload`

A request to connect to an MCP server that needs authorization. The source
turns it into an `AuthorizationRequest` and puts `elicitationId` in `meta`.

| field | type | note |
|---|---|---|
| `id` | string | The identifier of the request. |
| `serverName` | string | The display name of the MCP server. |
| `scopes` | array of string | The OAuth scopes that the server asks for. |
| `authorizationURL` | URL string | The location where the user authorizes. |
| `elicitationId` | string, optional | The URL-mode elicitation that the request answers. |

## `AgentViewKit.UsagePayload`

The context usage of a thread. The fields are the stored properties of
`ContextUsage`. `Docs/decisions/usage-model.md` tells which source fills each
field.

| field | type | note |
|---|---|---|
| `used` | integer | The number of tokens in the context window now. |
| `size` | integer | The number of tokens that the context window holds. |
| `cost` | `ContextUsage.Cost`, optional | The cumulative cost of the session. |
| `input` | `ContextUsage.Input`, optional | The input token counts. |
| `output` | `ContextUsage.Output`, optional | The output token counts. |
| `quota` | quota object, optional | `{"status": "belowLimit", "approaching": <bool>}` or `{"status": "limitReached"}`. Another status is a decode error. |

## `PlanEntry`

One task in a plan.

| field | type | note |
|---|---|---|
| `content` | string | The text of the task. |
| `priority` | string | The ACP wire string: `high`, `medium`, or `low`. Another string is kept as an unknown priority. |
| `status` | string | The ACP v2 wire string: `pending`, `in_progress`, `completed`, or `cancelled`. Another string is kept as an unknown status. |

## `CitationSource`

One source that a response cites.

| field | type | note |
|---|---|---|
| `id` | string | The identifier that a `CitationMarker` refers to. |
| `title` | string | The title of the source. |
| `url` | URL string | The location of the source. |
| `snippet` | string | A short part of the source text. It is empty when the source gives none. |
| `iconURL` | URL string, optional | The location of the icon of the source. |

## `CitationMarker`

One place in a response that cites a source.

| field | type | note |
|---|---|---|
| `sourceID` | string | The `id` of the cited `CitationSource`. |
| `paragraphIndex` | integer | The zero-based index of the paragraph. |
| `offset` | integer | The zero-based character offset in the paragraph. |

## `ContextUsage.Cost`

| field | type | note |
|---|---|---|
| `amount` | number | The cost. |
| `currency` | string | The ISO 4217 currency code, such as `USD`. |

## `ContextUsage.Input`

| field | type | note |
|---|---|---|
| `total` | integer | The number of input tokens. |
| `cached` | integer | The part of `total` that came from a cache. |

## `ContextUsage.Output`

| field | type | note |
|---|---|---|
| `total` | integer | The number of output tokens. |
| `reasoning` | integer | The part of `total` that the model used to reason. |
