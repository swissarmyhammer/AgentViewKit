---
depends_on:
- 01M21AA90BQK4DWDV9V1P22DH2
- 01M21ACHJYSF8G8R7HY3M70Z7F
- 01M21ABMYXZQRNRDGB3DR6RK73
position_column: todo
position_ordinal: b780
title: Elicitation field views and their typed override modifiers (plan §13.1, §13.2)
---
## What
Create `Sources/AgentViewKit/Elicitation/ElicitationFieldContext.swift`, `ElicitationFieldViews.swift`, and `ElicitationOverrides.swift`, per plan.md §13.1 and §13.2.

- `ElicitationFieldContext { schema: ElicitationFieldSchema; value: Binding<JSONValue?>; validation: FieldValidationState }`.
- Field views: `ElicitationTextField` (an EditorKit single-line field, or multi-line when `maxLength` is nil or above 200), `ElicitationNumberField` (stepper, or slider when both bounds exist; integer step when `integer`), `ElicitationToggleField`, `ElicitationDateField` (`DatePicker`, date or date-time), `ElicitationSingleChoiceField` (radio group up to five, `Picker` menu above), `ElicitationMultiChoiceField` (checkboxes; disables new checks at `maxItems`).
- Each field shows its title, description, required mark, and the current validation errors under it.
- Typed override modifiers in the environment: `.elicitationTextField`, `.elicitationNumberField`, `.elicitationToggleField`, `.elicitationDateField`, `.elicitationSingleChoiceField`, `.elicitationMultiChoiceField`, each `(ElicitationFieldContext) -> some View`.
- `ElicitationFieldView(context:)`: switches on `schema.kind`, reads the override, else the default.
- Accessibility identifier `elicitation-field-<name>`.

## Acceptance Criteria
- [ ] Each kind mounts its default control and writes back through the binding.
- [ ] Six choices render a menu; five render radios.
- [ ] At `maxItems` a further check is disabled.
- [ ] An override for one kind replaces only that kind.

## Tests
- [ ] `Tests/AgentViewKitTests/Elicitation/ElicitationFieldViewsHostedTests.swift`: the four cases with the harness.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.