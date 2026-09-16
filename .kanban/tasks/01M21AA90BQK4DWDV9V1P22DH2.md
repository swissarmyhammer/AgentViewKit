---
comments:
- actor: claude-code
  id: 01m2nc5c25h9syg75qpj4p3k77
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 4 files (2 sources, 2 test suites)
    - test: green — swift test, 316 passed (47 elicitation tests)
    - commit: e626af4
    - review: findings — ElicitationFieldSchema.swift:140 (duplication), ElicitationValidator.swift:286, 290, 298, 306, 307, 308, 309, 310, 312 (magic numbers)
    - decisions: the fields are in name order, because a JSON object does not keep key order. A property with an unknown type gives no field. A default with the wrong JSON type is ignored. A pattern that does not compile is ignored. An empty string or an empty array counts as no answer.
  timestamp: 2026-09-16T15:08:00.965815+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
- 01M21BCD7C9V8N4SED5GE34A4E
position_column: doing
position_ordinal: '8180'
title: Elicitation schema normalization and validation, pure (plan §13.1)
---
## What
Create `Sources/AgentViewKit/Elicitation/ElicitationFieldSchema.swift` and `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift`, per plan.md §13.1. Pure types, no SwiftUI.

- `ElicitationFieldSchema`: `name`, `title`, `description`, `required`, `kind` (`text(minLength, maxLength, pattern, format)`, `date(dateTime: Bool)`, `number(integer: Bool, minimum, maximum)`, `boolean`, `singleChoice([Choice])`, `multiChoice([Choice], minItems, maxItems)`), `defaultValue: JSONValue?`.
- `Choice { value: String; title: String; description: String? }`.
- `ElicitationFieldSchema.normalize(from requestedSchema: JSONValue) -> [ElicitationFieldSchema]`. It collapses the four choice encodings: plain `enum`, legacy `enumNames`, titled `oneOf`, and array `items.enum` or `items.anyOf`. Untitled choices get `title == value`.
- `FieldValidationState { errors: [String]; isSatisfied: Bool }`.
- `ElicitationValidator.validate(_ value: JSONValue?, against schema: ElicitationFieldSchema) -> FieldValidationState` for required, min and max length, pattern, format (`email`, `uri`, `date`, `date-time`), minimum and maximum, min and max items.
- `ElicitationValidator.isComplete(values: [String: JSONValue], schemas: [ElicitationFieldSchema]) -> Bool`.

## Acceptance Criteria
- [x] All four choice encodings normalize to the same `[Choice]` for the same options.
- [x] A `string` with `format: date-time` normalizes to `.date(dateTime: true)`.
- [x] `default` pre-populates `defaultValue` for every primitive type.
- [x] A missing required field fails; an empty optional field passes.
- [x] `pattern` is applied as a full-string regex.

## Tests
- [x] `Tests/AgentViewKitTests/Elicitation/ElicitationSchemaNormalizationTests.swift`: one fixture per encoding, taken from the ACP v2 schema examples in `../FoundationModelsACP/Schema/acp-v2.json`.
- [x] `Tests/AgentViewKitTests/Elicitation/ElicitationValidatorTests.swift`: one test per constraint.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #foundation #elicitation

## Review Findings (2026-09-16 10:03)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Elicitation/ElicitationFieldSchema.swift:140` `duplication/duplication` — The new Choice struct duplicates the existing SelectOption struct from ConfigOption.swift. Both are Identifiable, Sendable, Hashable structs representing a selectable option with an identifier, label, and optional description. They differ only in field names (id/name vs value/title) and how id is accessed. This duplication inflates the surface area and creates maintenance burden. Evaluate whether SelectOption can be reused directly in the elicitation context, or create a shared base type/protocol (e.g., 'SelectableOption' or a generic wrapper) to eliminate duplication. If field name differences are intentional, consider a typealias to provide domain-specific naming while sharing the underlying implementation.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:286` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:290` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:298` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:306` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:307` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:308` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:309` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:310` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationValidator.swift:312` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
