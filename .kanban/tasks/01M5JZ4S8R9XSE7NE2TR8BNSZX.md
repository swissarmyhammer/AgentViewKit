---
assignees:
- claude-code
position_column: todo
position_ordinal: a780
title: Show the required-field error of an elicitation form only after the user edits the field or presses Submit
---
## Problem

The `elicitation-form-*` snapshots (HostedSnapshotTests, `theElicitationForm`) show "This field is necessary." under the required `Name` field before the user types anything. The preview "In content, before the user types: the required field shows its error" in `Sources/AgentViewKit/Elicitation/ElicitationCard.swift` shows the same state (found in ^bbyfn3t).

Cause: `ElicitationFieldContext.init(schema:value:)` validates the current answer on each render with `ElicitationValidator.validate(_:against:)`, which gives `Message.required` for an empty required answer. Nothing records whether the user touched the field, so the error shows on the first render. An error before the user had a chance to answer goes against the Apple HIG guidance to validate after people enter information.

## Change

- Show the required message (and other field errors) only after the user changed the field, or after a press on Submit with an incomplete form. Submit stays disabled while the form is incomplete (`ElicitationValidator.isComplete`), so decide with the design how a press on a disabled Submit is shown, or keep "after an edit" only.
- Keep `FieldValidationState` public API. No backward compatibility code (ARCHITECTURE.md).
- Record the new snapshots of `elicitation-form-*` and check the preview.

## Tests

- A hosted test: a new form shows no error under a required empty field. After the user types and clears the field, the error shows. #avk-14