---
depends_on:
- 01M21A961W19N9FWQ92FETNVP6
- 01M21BCD7C9V8N4SED5GE34A4E
position_column: todo
position_ordinal: c180
title: TerminalRecord and ConfigOption types (plan §3.2, §3.4)
---
## What
Create `Sources/AgentViewKit/Model/TerminalRecord.swift` and `Sources/AgentViewKit/Model/ConfigOption.swift`, per plan.md §3.2 and §3.4.

- `TerminalRecord`: `@Observable final class` with `id`, `command`, `cwd`, `exitStatus: ExitStatus?` (`code: Int?`, `signal: String?`), `output: Data`, `revision`, and `bump()`. `appendOutput(_ chunk: Data)` appends and bumps.
- `ConfigOption`: `id: ConfigOptionID`, `name`, `description`, `category` (`mode, model, modelConfig, thoughtLevel, unknown(String)`), `kind`: `select(current: String, choices: SelectChoices)` or `boolean(current: Bool)`. `SelectChoices`: `flat([SelectOption])` or `grouped([SelectGroup])`. `SelectOption { id, name, description }`. `SelectGroup { name, options }`.
- `ConfigValue`: `id(String)`, `boolean(Bool)`.
- `ConfigOption.Category(wireValue:)` maps the four ACP strings and gives `.unknown` for the rest.

## Acceptance Criteria
- [ ] `ConfigOption.Category(wireValue: "thought_level")` gives `.thoughtLevel`; `"other"` gives `.unknown("other")`.
- [ ] Decoding the grouped select fixture gives two groups with their options in order.
- [ ] `appendOutput` increments `revision` by one per call.

## Tests
- [ ] `Tests/AgentViewKitTests/Model/ConfigOptionTests.swift`: category mapping, flat and grouped decode from the ACP v2 fixtures in `../FoundationModelsACP/Schema/acp-v2.json`.
- [ ] `Tests/AgentViewKitTests/Model/TerminalRecordTests.swift`: append and revision.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.