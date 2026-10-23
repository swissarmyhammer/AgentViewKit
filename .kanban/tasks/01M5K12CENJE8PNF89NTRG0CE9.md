---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5m4bah5mksn4xg8ngzsmbgw
  text: 'USER DECISION (2026-10-23): show its error at once. A field whose INITIAL value is non-empty and invalid (the agent''s default breaks a constraint) shows its error as soon as the form appears. Empty required fields still wait for an edit or a submit attempt (^r8bnszx stays). The user sees at once why Submit is disabled. Announce that error through VoiceOver when the form appears, like the existing field-error announcements (medium priority).'
  timestamp: 2026-10-23T10:19:18.437061+00:00
- actor: claude-code
  id: 01m5m4ecmw7nqfk686cy3v5mj7
  text: 'Research: `ElicitationView.shownValidation(of:)` gates errors on `submitAttempted || editedFields.contains(name)`. Plan per USER DECISION: seed the set of error-showing fields at init with each field whose default is non-empty and not valid (`ElicitationValidator.isEmpty` / `validate`), and announce those errors at `.medium` on appear. Empty required fields stay gated (^r8bnszx). Docs to update: ElicitationView doc comment, `PreviewFixtures.invalidFieldElicitation` doc comment (says the error shows only after an edit), `Docs/decisions/accessibility.md` announcement table. Snapshots: `HostedSnapshotTests.theElicitationForm` uses `formElicitation`, which has no defaults, so no snapshot should change; the "Form with a field that is not valid" preview is not snapshotted.'
  timestamp: 2026-10-23T10:20:58.908035+00:00
- actor: claude-code
  id: 01m5m4pfdh43qehv7rxnr9n34r
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Elicitation/ElicitationView.swift (`errorShowingFields` seeded at init with `fieldsWithInvalidDefault(_:)` / `hasInvalidDefault(_:)`; `.onAppear(perform: announceInvalidDefaults)` announces at `.medium`; shared `errorText(of:)` for that and the submit attempt), Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift (doc of `invalidFieldElicitation`), Sources/AgentViewKit/Elicitation/ElicitationCard.swift (preview renamed "Form with a default that is not valid: its error shows at once"), Docs/decisions/accessibility.md (new announcement row, "eight boundaries"), Tests/AgentViewKitTests/Elicitation/ElicitationFieldErrorsHostedTests.swift (4 new hosted tests).
    - red→green: `swift test --filter ElicitationFieldErrorsHostedTests` RED 3 failed (invalid default shows error, is announced, required-empty stays clear beside it) / 1 guard passed (valid default); GREEN 11/11.
    - full `swift test`: exit 0, 227 XCTest-hosted + 1687 Swift Testing tests passed, 0 failures; 4 known issues are pre-existing `withKnownIssue` tests. Only warning is the SwiftPM build-graph line "missing creator for mutated node ... mlx-swift_Cmlx.bundle" (dependency bundle, present before any edit).
    - snapshots re-recorded: none. `HostedSnapshotTests.theElicitationForm` uses `formElicitation` (no defaults); the invalid-default preview is not snapshotted.
    - next: /review
  timestamp: 2026-10-23T10:25:23.889836+00:00
- actor: claude-code
  id: 01m5m4vemsw5w0jz7fe1sfd1d8
  text: |-
    ### test — green
    - evidence: `swift test` (after touching ElicitationCard.swift, ElicitationView.swift, PreviewFixtures.swift so AgentViewKit recompiled) — exit 0; Swift Testing: 1687 tests in 206 suites passed, 0 failures, 0 skipped, 4 known issues (the expected ones: SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests, ComposerWindowUndoHostedTests); XCTest: 0 tests, 0 failures. ElicitationFieldErrorsHostedTests suite passed, including the 4 new tests. Build warnings: only the known SwiftPM mlx-swift "missing creator" notice; no warnings from project code.
    - next: review/commit. Nothing committed. .DS_Store and wip/69g4a69-drop-stock-editor untouched.
  timestamp: 2026-10-23T10:28:06.937269+00:00
- actor: claude-code
  id: 01m5m51dmheae834sy9fe104tg
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (9da9db7) — 1 finding (1 confirmed, 0 refuted): Sources/AgentViewKit/Elicitation/ElicitationView.swift:164
    - next: implement the open item in the Review Findings (2026-10-23 05:28) section; task stays in review
  timestamp: 2026-10-23T10:31:22.513484+00:00
- actor: claude-code
  id: 01m5m51x4vg5ece7pacxk8ftaz
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ElicitationView (errorShowingFields seeded with invalid non-empty defaults; medium-priority announcement on appear), PreviewFixtures doc, ElicitationCard preview title, accessibility.md, 4 tests (3 red first)
    - test: green — swift test 1687 passed, 0 failed, 0 skipped
    - commit: 9da9db7
    - review: findings — Sources/AgentViewKit/Elicitation/ElicitationView.swift:164 (reuse/reuse: hasInvalidDefault reimplements ElicitationValidator.hasValidAnswer)
  timestamp: 2026-10-23T10:31:38.395616+00:00
- actor: claude-code
  id: 01m5m57qj18qcxpvsge4svd2q2
  text: |-
    ### implement — changed
    - evidence: 1 source file — Sources/AgentViewKit/Elicitation/ElicitationView.swift. `hasInvalidDefault(_:)` now gets its validation from `!ElicitationValidator.hasValidAnswer(value:against:)` and no longer calls `validate(...).isSatisfied`. It keeps the `isEmpty` guard because an empty default must give `false`.
    - NOT taken: the finding's literal one-liner `!hasValidAnswer(value: schema.defaultValue, against: schema)`. `hasValidAnswer` is `false` for an empty answer, so a required field with no default would show its error on a new form, which breaks ^r8bnszx (`aNewFormShowsNoErrorUnderARequiredEmptyField`, `aDefaultThatIsNotValidShowsNoErrorUnderARequiredEmptyField`). The doc comment now says why the guard stays.
    - Checked the rest of the file for copied validation: `shownValidation`, `edit`, `errorText(of:)`, the footer `canSubmit`, `submit` and `answerContent` already call `ElicitationValidator` (`validate`, `isComplete`, `isEmpty`). None was copied.
    - tests: `swift test --filter ElicitationFieldErrorsHostedTests` 11/11 passed. Full `swift test` exit 0: 1687 tests in 206 suites passed, 4 known issues (pre-existing withKnownIssue), XCTest 0 failures. The only warning is the pre-existing SwiftPM mlx-swift "missing creator" one. No new test was needed because behavior did not change.
    - Finding flipped to [x]. Task left in doing. Nothing committed.
    - next: /review
  timestamp: 2026-10-23T10:34:49.281834+00:00
- actor: claude-code
  id: 01m5m5cdazrspavnjw7ceq5w8k
  text: |-
    ### test — green
    - evidence: touched Sources/AgentViewKit/Elicitation/ElicitationView.swift, then `swift test` in /Users/wballard/github/swissarmyhammer/AgentViewKit: Test run with 1687 tests in 206 suites passed, 0 failures, 0 skipped, 4 known issues (as expected). Build recompiled AgentViewKit; no warnings from project code. Only the known SwiftPM mlx-swift "missing creator for mutated node" notice appeared. No `swift package update` run; nothing committed.
    - next: review
  timestamp: 2026-10-23T10:37:22.655426+00:00
position_column: doing
position_ordinal: '8580'
title: Tell the user why Submit of an elicitation form is disabled when an untouched default is not valid
---
## Problem

Since ^r8bnszx, `ElicitationView` shows the errors of a field only after the user changes the field, or after a call of `ElicitationFooterContext.submit` while the form is not complete. The default footer disables Submit while the form is not complete, so that call never comes from the default footer.

A field whose agent-given `default` breaks a constraint (for example `PreviewFixtures.invalidFieldElicitation`: `Retries` default 9 above its maximum) is not valid on the first render. The default form now shows no error for it, and Submit is disabled with no visible reason until the user happens to change that field. For a required empty field the required mark `*` explains the disabled Submit; for an invalid default nothing does.

## Change

Decide with the design how the form explains a disabled Submit when an untouched field is not valid. Options: show the errors of a non-empty answer at once (keep the delay only for the required message of an empty field), or let a press on the disabled Submit (or Return) count as a submit attempt.

## Tests

- A hosted test: a form whose default breaks a constraint tells the user why Submit is disabled, in the visible form and for VoiceOver. #avk-14

## Review Findings (2026-10-23 05:28)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 7 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `Docs/decisions/accessibility.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Elicitation/ElicitationView.swift:164` `reuse/reuse` — hasInvalidDefault reimplements validation logic that already exists in ElicitationValidator.hasValidAnswer. The new function checks if a field's default is not empty and fails validation—the exact inverse of hasValidAnswer. Instead of duplicating the validation check, it should call the existing function and negate the result. Replace the reimplemented validation logic with: `static func hasInvalidDefault(_ schema: ElicitationFieldSchema) -> Bool { !ElicitationValidator.hasValidAnswer(value: schema.defaultValue, against: schema) }`.
