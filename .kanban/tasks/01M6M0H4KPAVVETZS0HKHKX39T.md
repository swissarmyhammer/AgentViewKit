---
assignees:
- claude-code
position_column: todo
position_ordinal: '8780'
title: Elicitation number and date inputs onto EK NumberField/NumberText/DateField (font role decision)
---
Found while working ^xb69s3d (timing fields onto EK ^d2fa1j4).

`ElicitationNumberField` builds its number input from AVK's `AgentOneLineField(value:format:)`, the value form of `SingleLineField`. That is the same thing as EK's `NumberField`. Its slider readout is `Text(number, format: .number)`. `ElicitationDateField` uses the system `DatePicker` with Set Date and Remove Date buttons.

Open decision: elicitation inputs draw in the **display** font role (FontRoleHostedTests `theNumberInputOfAnElicitationNumberFieldDrawsInTheDisplayRole`). EK's `NumberField`, `NumberText` and `DateField` pin the **ui** role (`.editorFontRole(.ui)`). Moving the inputs changes the font of the elicitation form, or needs an EK option for the role.

## What
- Decide the font role of the elicitation value inputs (user or EK).
- Move the number input to `NumberField`, and the slider readout to `NumberText`. Then delete `AgentOneLineField`'s value-form initializer if nothing else uses it.
- Decide whether the `date`/`date-time` field becomes `DateField(selection: Binding<Date?>, components:)`, which would replace the DatePicker and the Set/Remove buttons.

## Tests
- Elicitation number and date hosted tests move to the new controls. Each changed check is written on the card.