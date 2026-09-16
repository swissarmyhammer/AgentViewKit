---
comments:
- actor: claude-code
  id: 01m2nbah3gycz07zvhqx88gg34
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — TerminalRecord.swift, ConfigOption.swift, two test files
    - test: green — swift test, 239 + 20 + 3 tests passed
    - commit: a9db6b5
    - review: findings — ConfigOption.swift:5, ConfigOption.swift:197, TerminalRecord.swift:8

    Decisions:
    - The ACP v2 schema has no example payloads. The tests use inline JSON fixtures that follow the `SessionConfigOption` wire shape of the schema.
    - `ConfigOption.Kind` has a third case `unknown(type:raw:)`, because plan.md §3.2 tells that each model enum has an unknown case. The ACP schema has an "other" option type.
    - `SelectGroup` has an `id` (the ACP `groupId`), so that a view can use it in `ForEach`.
    - `TerminalRecord` does not conform to `ThreadRecord`: `ThreadRecord` requires a `String` id, and `AgentThread.terminals` is keyed by `TerminalID`. It has its own `revision` and `bump()`.
  timestamp: 2026-09-16T14:53:21.392537+00:00
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
- 01M21BCD7C9V8N4SED5GE34A4E
position_column: doing
position_ordinal: '8180'
title: TerminalRecord and ConfigOption types (plan §3.2, §3.4)
---
## What
Create `Sources/AgentViewKit/Model/TerminalRecord.swift` and `Sources/AgentViewKit/Model/ConfigOption.swift`, per plan.md §3.2 and §3.4.

- `TerminalRecord`: `@Observable final class` with `id`, `command`, `cwd`, `exitStatus: ExitStatus?` (`code: Int?`, `signal: String?`), `output: Data`, `revision`, and `bump()`. `appendOutput(_ chunk: Data)` appends and bumps.
- `ConfigOption`: `id: ConfigOptionID`, `name`, `description`, `category` (`mode, model, modelConfig, thoughtLevel, unknown(String)`), `kind`: `select(current: String, choices: SelectChoices)` or `boolean(current: Bool)`. `SelectChoices`: `flat([SelectOption])` or `grouped([SelectGroup])`. `SelectOption { id, name, description }`. `SelectGroup { name, options }`.
- `ConfigValue`: `id(String)`, `boolean(Bool)`.
- `ConfigOption.Category(wireValue:)` maps the four ACP strings and gives `.unknown` for the rest.

## Acceptance Criteria
- [x] `ConfigOption.Category(wireValue: "thought_level")` gives `.thoughtLevel`; `"other"` gives `.unknown("other")`.
- [x] Decoding the grouped select fixture gives two groups with their options in order.
- [x] `appendOutput` increments `revision` by one per call.

## Tests
- [x] `Tests/AgentViewKitTests/Model/ConfigOptionTests.swift`: category mapping, flat and grouped decode from the ACP v2 fixtures in `../FoundationModelsACP/Schema/acp-v2.json`.
- [x] `Tests/AgentViewKitTests/Model/TerminalRecordTests.swift`: append and revision.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 09:48)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Sources/AgentViewKit/Model/ConfigOption.swift:5` `duplication/duplication` — ConfigOptionID duplicates TerminalID—both define identical ID wrapper types, differing only in type name. Code duplication forces maintenance of two copies, which can drift. Extract one generic ID type to serve both ConfigOptionID and TerminalID. Remove duplication.
- [x] `Sources/AgentViewKit/Model/ConfigOption.swift:197` `completeness/inverse-operation-coverage` — ConfigValue is a public type meant to be sent to the API (per docstring: 'AgentThreadActions.setConfigOption takes this type'), but it lacks Codable conformance for encoding and has no encode test. Related types like ConfigOption have comprehensive Codable implementations with round-trip tests; ConfigValue should too. Add Codable conformance to ConfigValue and test round-trip encoding/decoding, similar to ConfigOption. The encode test should verify that both case variants (id and boolean) encode correctly in the ACP v2 wire format.
- [x] `Sources/AgentViewKit/Model/TerminalRecord.swift:8` `duplication/duplication` — TerminalID duplicates ConfigOptionID—both define identical ID wrapper types, differing only in type name. Code duplication forces maintenance of two copies, which can drift. Extract one generic ID type to serve both ConfigOptionID and TerminalID. Remove duplication.
