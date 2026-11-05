---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6nt1h7xpvr3xsq7trdfs7gq
  text: |-
    User decisions, 2026-11-05:
    1. Font role: the elicitation value inputs use the **ui** role, as EK does. EK's NumberField, NumberText and DateField are used as they are (no EK option). FontRoleHostedTests `theNumberInputOfAnElicitationNumberFieldDrawsInTheDisplayRole` becomes `...DrawsInTheUIRole` and expects `.ui`.
    2. Date: the `date`/`date-time` field becomes EK `DateField(model:id:selection: Binding<Date?>, components:)` (`.date` / `.dateAndTime`). It replaces the system DatePicker and the Set Date / Remove Date buttons (an empty field is no answer: a commit of empty text clears it).

    Research:
    - AgentOneLineField is internal; its value-form init is used only by ElicitationNumberField. `ElicitationDateField.clearIdentifier(for:)` is public: grep of origin/main of KanbanViewKit (d73069b), SnapshotViewKit (b03783e) and TestudoApp (52615e5) for clearIdentifier / ElicitationDateField / ElicitationNumberField: no hits, so it is removed.
    - EK (dc2b242): NumberField(model:id:value: Binding<Int|Double>) uses `.integer` / `.floatingPoint` formats in the env locale; it writes only when the committed text's value differs from the bound value's text. NumberText(value) draws `theme.font(for: .ui, style: .body)`. DateField's calendar button id is `DateField.pickerAccessibilityIdentifier(of: textIdentifier)`; InspectorDriver.pick(_:in:) presses it and sets the popover NSDatePicker. `onEditorCommit` is on EditorSlotComposing, so the kit's `onFieldSubmit` can move from SingleLineField to EditorSlotComposing and serve NumberField and DateField.
    - The number input's max width scales with `@ThemeFontScale(.display)`; with the ui role it must scale with `.ui`.
  timestamp: 2026-11-05T12:13:22.557011+00:00
position_column: doing
position_ordinal: 8d80
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