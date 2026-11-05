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
- actor: claude-code
  id: 01m6nvxmn7sd4xewk0zevrgnf7
  text: |-
    Implementation landed (e901e988, branch worktree-agent-a45dc85096880823e, not pushed or merged).

    Code:
    - ElicitationNumberField: number input = EK `NumberField(model:id:value:format:)` with `.integer` / `.floatingPoint`; max width now scales with `@ThemeFontScale(.ui)`. Slider readout = EK `NumberText(value)` (`.monospacedDigit()` kept), with the new internal id `ElicitationNumberField.readoutIdentifier(for:)` (`elicitation-field-<name>-readout`).
    - ElicitationDateField: EK `DateField(model:id:selection: Binding<Date?>, components: .date | .dateAndTime)` over `ElicitationDateCoding`; empty commit = no answer; Return presses Submit (`elicitationReturnAction`), as the number input does. DatePicker, Set Date / Set Date and Time / Remove Date buttons, `clearIdentifier(for:)` (public), `removeDateTitle`, `setDateTitle(dateTime:)` and the 3 strings in Localizable.xcstrings are gone.
    - AgentOneLineField: value-form init deleted (only ElicitationNumberField used it). `onFieldSubmit` moved from `SingleLineField` to `EditorSlotComposing`; new `EditorSlotComposing.agentOneLineInput(identifier:placeholder:onSubmit:)` holds the kit one-line slots (submit, `.intrinsic` sizing, placeholder, text identifier + label) for AgentOneLineField, the number input and the date input. No field gets a fixed height or an inner scroll.
    - plan.md §13.1 table names the EK controls.

    Changed checks:
    - FontRoleHostedTests: `theNumberInputOfAnElicitationNumberFieldDrawsInTheDisplayRole` -> `theNumberInputOfAnElicitationNumberFieldDrawsInTheUIRole`: same mount, moved to the ui section, `expectEditor(in:drawsIn: .ui)`. New `theReadoutOfAnElicitationSliderDrawsInTheUIRole` (`expectText` on the readout id, `.ui`) and `theInputOfAnElicitationDateFieldDrawsInTheUIRole` (`expectEditor`, `.ui`). Suite doc names the value inputs as ui.
    - ElicitationFieldViewsHostedTests: `theNumberInputBesideTheStepperShowsTheAnswer` reads `inspectorDriver.value(of:)` (was `element(identifier:)?.value`); `theNumberInputShowsAChangeOfTheAnswer` reads `inspectorDriver.textView(_:)` (was SingleLineFieldChecks.textView). New `theReadoutOfTheSliderShowsTheAnswer` (readout label "5"). Date: `theDateButtonWritesAFullDateAndTheClearButtonRemovesIt` and `theDateTimeButtonWritesAValidDateTime` deleted (buttons gone), replaced by `theDateInputShowsTheAnswerInTheNumericDateOfTheLocale` ("2026-11-05" shows "11/5/2026" in en_US/UTC), `aTypedDateWritesAFullDate` (driver `replace` + `commit` -> "2026-11-05"), `anEmptyDateRemovesTheAnswer` (driver `replace("")` + `commit` -> nil), `aPickedDateTimeWritesItsTimeInUTC` (driver `pick` -> "2026-11-05T14:30:00Z").
    - New ElicitationDateFieldEditingHostedTests.returnWritesTheTypedDateAndSubmitsTheForm (driver replace + commit in a scoped ElicitationView -> accepted with the day).
    - ElicitationNumberFieldEditingHostedTests: doc names `NumberField`; checks unchanged and green (SingleLineFieldChecks stays for Esc and Command-Return, which InspectorDriver has no verb for). ElicitationFieldErrorsHostedTests unchanged and green. OneLineFieldSubmitTests: doc names `EditorSlotComposing.onFieldSubmit(_:)`.

    Discoveries / dead ends:
    - `InspectorDriver.pick` on a `HostedViewHarness` fails ("no date picker opened"): the harness window is never ordered in, so the calendar popover cannot open. The pick test mounts with EK's `makeHostedWindow(rootView:width:height:)` + `InspectorDriver(window:root:)` inside `withAccessibilityTree`, as EK's InspectorBed does.
    - RED seen for every new/changed check before the code (font role x3, readout, 4 date checks); the Return-submits test was seen RED by removing the date input's return action, then restored.
    - Gallery: ScreenshotTests ran once (24 tests passed). Its `elicitation-form` image shows only the Name tab of the fixture form, so no gallery image shows the number or date inputs.
  timestamp: 2026-11-05T12:46:12.135621+00:00
- actor: claude-code
  id: 01m6nvxvnv9s1ykezkzc4x1cd7
  text: |-
    ### implement — changed
    - evidence: commit e901e988 (branch worktree-agent-a45dc85096880823e). 9 files — Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift, Sources/AgentViewKit/Input/AgentOneLineField.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, plan.md, Tests/AgentViewKitTests/Input/OneLineFieldSubmitTests.swift, IntegrationTests/.../Theme/FontRoleHostedTests.swift, IntegrationTests/.../Elicitation/ElicitationFieldViewsHostedTests.swift, IntegrationTests/.../Elicitation/ElicitationNumberFieldEditingHostedTests.swift, IntegrationTests/.../Elicitation/ElicitationDateFieldEditingHostedTests.swift (new). Root `swift test`: 969 tests / 107 suites + 65 / 10 passed; IntegrationTests `swift test`: 951 tests / 124 suites passed, 5 known issues (the intentional withKnownIssue checks of FontRoleExpectationsTests); ScreenshotTests: 24 tests passed (gallery capture run once). Warnings: only the known mlx-swift_Cmlx "missing creator" dependency warning; zero in AVK targets.
    - next: /review
  timestamp: 2026-11-05T12:46:19.323114+00:00
position_column: done
position_ordinal: ffffffa380
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