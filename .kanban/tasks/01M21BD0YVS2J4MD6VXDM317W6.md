---
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
position_column: todo
position_ordinal: b080
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
- [ ] `PermissionOption.Kind(wireValue: "allow_once")` gives `.allowOnce`; an unknown string gives `.unknown`.
- [ ] `ElicitationRequest.mode` decodes both forms from the ACP-shaped JSON fixtures.
- [ ] `AuthMethod` decodes both wire forms and keeps `args` and `env` on `terminal`.

## Tests
- [ ] `Tests/AgentViewKitTests/Model/RequestTypesTests.swift`: the three cases above.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.