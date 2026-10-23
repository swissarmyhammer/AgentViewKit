---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5k0ketetpb7t6h8pg95md76
  text: 'Research: field errors render from `ElicitationFieldContext.validation`, built in `ElicitationView.fieldContext` with the convenience init that always validates. Field errors were never announced (only the agent-refusal failure is). The default footer disables Submit, and `.keyboardShortcut(.defaultAction)` on a disabled button does nothing, so a "submit attempt" can only come from `ElicitationFooterContext.submit` (a custom footer that does not disable its button). Plan: ElicitationView keeps the set of edited field names and a submit-attempt flag; it passes `.satisfied` for a field that is neither edited nor attempted; it announces errors that appear (edit: .medium, submit attempt: .high). Tests in Tests/AgentViewKitTests/Elicitation/ElicitationFieldErrorsHostedTests.swift; RED run: 5 of 7 failed as expected.'
  timestamp: 2026-10-22T23:54:36.238760+00:00
- actor: claude-code
  id: 01m5k12pwyrch4746semqd55rw
  text: |-
    Implementation landed. ElicitationView keeps `editedFields` and `submitAttempted`; `shownValidation(of:)` gives `.satisfied` until the field was edited or a submit attempt happened. The binding setter (`edit(_:to:)`) ignores a write of the current answer, so a control that writes back the same value on appear does not mark the field. Errors that appear are announced: after an edit at .medium ("“<title>”: <messages>"), after a submit attempt at .high (each field that is not valid, in form order). New localized key "“%@”: %@".

    Decision on the disabled Submit (card: "decide ... or keep after an edit only"): the default footer keeps Submit disabled and Return does nothing on a disabled button, so in the default footer only "after an edit" applies. The submit-attempt rule is implemented in `ElicitationFooterContext.submit`: a custom footer that calls it while `canSubmit` is false now shows and announces every field error instead of doing nothing. Tested with a custom footer.

    Discovered: a field whose agent default breaks a constraint (PreviewFixtures.invalidFieldElicitation) now shows no error and Submit is disabled with no visible reason. Filed ^trg0ce9.

    Snapshots re-recorded with `AVK_SNAPSHOT_RECORD=1 swift test --filter "HostedSnapshotTests/(theElicitationForm|theRequestDeckInTheBar)"`: elicitation-form-{light,dark,reduce-transparency,increase-contrast}.png and request-deck-bar-{light,dark,reduce-transparency,increase-contrast}.png (the deck shows PreviewFixtures.formElicitation with the required Name field). No other snapshot failed.
  timestamp: 2026-10-23T00:02:56.030375+00:00
- actor: claude-code
  id: 01m5k12wczz4w9ke35ezb37cn4
  text: |-
    ### implement — changed
    - evidence: 9 files + 8 re-recorded PNGs — Sources/AgentViewKit/Elicitation/ElicitationView.swift, ElicitationFieldContext.swift, ElicitationCard.swift (preview renamed to "In content, before the user types: the required field shows no error yet"), Infrastructure/PreviewFixtures.swift, Platform/Announcer.swift, Resources/Localizable.xcstrings, Docs/decisions/accessibility.md, plan.md, new Tests/AgentViewKitTests/Elicitation/ElicitationFieldErrorsHostedTests.swift (7 tests; RED 5 failed, GREEN 7 passed). Re-recorded: HostedSnapshotTests/elicitation-form-{light,dark,reduce-transparency,increase-contrast}.png, request-deck-bar-{light,dark,reduce-transparency,increase-contrast}.png. Full `swift test`: 1671 tests in 204 suites passed (3 known issues, pre-existing), plus 219 + 1; exit 0.
    - next: /review
  timestamp: 2026-10-23T00:03:01.663992+00:00
- actor: claude-code
  id: 01m5k18jym4n4a7g7ca76as4m1
  text: |-
    ### test — green
    - evidence: `swift test` (after touching the changed Sources files and Localizable.xcstrings): Build complete, 1671 tests in 204 suites passed, 0 failures, 0 skipped; ElicitationFieldErrorsHostedTests suite passed. No project-code warnings; the only warning is the known SwiftPM mlx-swift "missing creator" notice. No catalog warnings; the key "“%@”: %@" is translated in Localizable.xcstrings and used by ElicitationView.fieldErrorText. The 3 known issues are the intentional expected-failure tests (SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests), not skips. No snapshots re-recorded; no package update.
    - next: review
  timestamp: 2026-10-23T00:06:08.596825+00:00
position_column: doing
position_ordinal: '8380'
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