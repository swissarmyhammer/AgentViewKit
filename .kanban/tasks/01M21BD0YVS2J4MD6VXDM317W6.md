---
comments:
- actor: claude-code
  id: 01m2ng163yfcq281gpxfmfp5a4
  text: |-
    Research and decisions (from the ACP v2 schema in ../FoundationModelsACP/Schema/acp-v2.json):
    - Each request id is a typed `Identifier`: `PermissionRequestID`, `PermissionOptionID`, `ElicitationRequestID`, `AuthorizationRequestID`, `AuthMethodID` (plan §3.4 names `AuthMethodID`). The ACP requests have no id field; the source makes the id (for example from the JSON-RPC id).
    - `PermissionRequest.subject` is optional, because the ACP subject is optional. An unknown subject type gives `nil`, and the view shows a generic prompt. The tool call id is `String`, the same as `ToolCallRecord.id`.
    - `AuthMethod` has nested `Agent` and `Terminal` structs, because plan §3.4 names `AuthMethod.Terminal` for `runTerminalAuth`. `Terminal` also keeps `description`. `env` is `[String: String]` (ACP names are unique; the last value wins). Decode follows the ACP "default on error" and "skip invalid items" marks. Encode writes `env` in name order.
    - `AuthMethod` requires `type` (ACP v2). An unknown `type` gives `.unknown(type)`. `ElicitationRequest.Mode` requires `mode`; an unknown mode throws, because ACP tells a client not to show it as a known mode.
    - Only `PermissionOption`, `ElicitationRequest.Mode`, and `AuthMethod` are `Codable`. The request structs are not, because their ids and `server` are not on the wire.

    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Model/Requests/{PermissionRequest,PermissionDecision,ElicitationRequest,AuthorizationRequest,AuthMethod}.swift, Tests/AgentViewKitTests/Model/RequestTypesTests.swift
    - next: test, commit, review

    ### test — green
    - evidence: swift test — 395 tests in 34 suites passed, plus 20 and 1; RequestTypesTests 18 tests passed; no new warnings
  timestamp: 2026-09-16T16:15:38.110069+00:00
- actor: claude-code
  id: 01m2ng6cdbt82j2hayrswmdckp
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 6 files
    - test: green — swift test, 395 + 20 + 1 tests passed
    - commit: 3c114dd
    - review: clean — review sha HEAD~1..HEAD, 0 findings; task moved to done
  timestamp: 2026-09-16T16:18:28.395498+00:00
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
position_column: done
position_ordinal: '9280'
title: 'Pending request types: PermissionRequest, ElicitationRequest, AuthorizationRequest, AuthMethod (plan §3.2, §12, §13)'
---
## What
Create the pending-request value types in `Sources/AgentViewKit/Model/Requests/`, per plan.md §3.2, §12, and §13.

- `PermissionRequest.swift`: `id`, `title`, `description`, `subject` (`toolCall(id)` or `command(command, cwd, toolCallId, terminalId)`), `options: [PermissionOption]`, `meta: JSONValue?`. `PermissionOption { id, name, kind }` with `kind`: `allowOnce, allowAlways, rejectOnce, rejectAlways, unknown(String)`.
- `PermissionDecision.swift`: `outcome` (`selected(optionId)`, `cancelled`) and `comment: String?`.
- `ElicitationRequest.swift`: `id`, `server`, `message`, `mode` (`form(requestedSchema: JSONValue)` or `url(URL, elicitationId)`), `meta`. `ElicitationResult`: `accept(JSONValue?)`, `decline`, `cancel`. The kit uses `JSONValue` here, not `GeneratedContent`; the FoundationModels target converts.
- `AuthorizationRequest.swift`: `id`, `serverName`, `scopes`, `authorizationURL`, `meta`.
- `AuthMethod.swift`: `agent(id, name, description)`, `terminal(id, name, args, env)`, `unknown(String)`.

## Acceptance Criteria
- [x] `PermissionOption.Kind(wireValue: "allow_once")` gives `.allowOnce`; an unknown string gives `.unknown`.
- [x] `ElicitationRequest.mode` decodes both forms from the ACP-shaped JSON fixtures.
- [x] `AuthMethod` decodes both wire forms and keeps `args` and `env` on `terminal`.

## Tests
- [x] `Tests/AgentViewKitTests/Model/RequestTypesTests.swift`: the three cases above.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.