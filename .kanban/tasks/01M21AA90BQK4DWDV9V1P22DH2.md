---
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
- [ ] All four choice encodings normalize to the same `[Choice]` for the same options.
- [ ] A `string` with `format: date-time` normalizes to `.date(dateTime: true)`.
- [ ] `default` pre-populates `defaultValue` for every primitive type.
- [ ] A missing required field fails; an empty optional field passes.
- [ ] `pattern` is applied as a full-string regex.

## Tests
- [ ] `Tests/AgentViewKitTests/Elicitation/ElicitationSchemaNormalizationTests.swift`: one fixture per encoding, taken from the ACP v2 schema examples in `../FoundationModelsACP/Schema/acp-v2.json`.
- [ ] `Tests/AgentViewKitTests/Elicitation/ElicitationValidatorTests.swift`: one test per constraint.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #foundation #elicitation