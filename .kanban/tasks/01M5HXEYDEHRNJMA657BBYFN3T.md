---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5jyqnwdckazw42qmjjay1s0
  text: |-
    Research:
    - Pattern: private parameterized `*Sample`/`*Preview` view per file (ThoughtEntryBlockSample, AttachmentActionsPreview), state held in `@State` set in init; fixtures in PreviewFixtures with PreviewFixturesTests.
    - Elicitation answers: `SessionModel.preview(pendingElicitations:)` records each answer in its `PreviewSessionRequestSender` (no agent, no network). So the card's owner is a preview session.
    - `WithdrawnRequest.init` is internal to FoundationModelsACPClient and the preview factory has no withdrawn records, so the WithdrawnNoticeRow previews build `WithdrawnNotice(id:text:)` with `RequestDeck.withdrawnText(title:reason:)`.
    - Deck place: a RequestDeck in the composer slot of AgentThreadView is in the bar (floatingGlassContainerCount > 0, deck on glass, bordered buttons); a card alone is in content (glass buttons).
    - `ElicitationFieldSchema.normalize` keeps a `default` of the right JSON type without range checks, so a form whose default breaks a constraint shows a field that is not valid at first render.
    - Snapshot elicitation-form-light.png (OCR): "This field is necessary." shows under Name before any input. Cause: `ElicitationFieldContext.init(schema:value:)` validates on each render, and `ElicitationValidator.validate` gives the required message for an empty required answer; nothing tracks whether the user touched the field.
  timestamp: 2026-10-22T23:21:57.389515+00:00
- actor: claude-code
  id: 01m5jz5y1dwfapvbtceg4yhk86
  text: |-
    Implementation landed (not committed):
    - ElicitationCard: private `ElicitationCardSample(_:in:)` with `Place` `.content` / `.bottomBar`. There are 5 previews: "Form with a field of each kind", "Form with a field that is not valid", "In content, before the user types: the required field shows its error", "URL consent request", and "In the request deck in the bottom bar of a thread" (AgentThreadView with RequestDeck + DefaultThreadComposer over `scrolledTranscript`). The owner is a preview session from `PreviewFixtures.elicitationCardSession(asking:transcript:)`, so `PreviewSessionRequestSender` records each answer.
    - ElicitationWhoAsksLine: `ElicitationWhoAsksLineSample(whoAsks:)` at `narrowWidth`. There are 2 previews: `WhoAsks.short` and `WhoAsks.long`. The long one uses `longAgentName` and a long tool name, so the middle truncates.
    - WithdrawnNoticeRow: `WithdrawnNoticeRowSample(notice:)` at `narrowWidth`. There are 2 previews: `withdrawnNotice` and `longTitleWithdrawnNotice`.
    - New PreviewFixtures values: `WhoAsks` (short/long/meta), `eachKindFormElicitation`, `invalidFieldElicitation` (Retries default `retriesAboveMaximum` = 9 > max 5; Name default `validPackageName`), `elicitationCardSession(asking:transcript:)`, `scrolledTranscript` (scrolledSession now reads it), `withdrawalReason`, `longWithdrawnTitle`, `withdrawnNotice`, `longTitleWithdrawnNotice`, and `ElicitationFields.platformChoices`/`checkChoices`. The each-kind JSON reads the names, titles and choices from these, so the choice data is not written twice. `formElicitation` now goes through `formRequest(message:properties:required:)` with the same JSON as before, so the elicitation-form snapshots are unchanged.
    - The 11 PreviewFixturesTests were written first. RED: each one did not compile because its fixture was missing. GREEN: 70/70 in the suite.

    Finding: "This field is necessary." before the user types is NOT correct. The snapshot and the new preview show the required error under the empty `Name` field on the first render, before the user had a chance to answer. Cause: `ElicitationFieldContext.init(schema:value:)` validates on each render, and nothing records whether the user edited the field. Apple HIG says to validate after people enter information. The Submit gate (`isComplete`) is right; only the error text comes too early. Filed follow-up ^r8bnszx (#avk-14) to show field errors only after an edit or a Submit attempt.
  timestamp: 2026-10-22T23:29:44.493126+00:00
- actor: claude-code
  id: 01m5jz62jsnwhpnhzptjh9bcfy
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Elicitation/ElicitationCard.swift, Sources/AgentViewKit/Elicitation/ElicitationWhoAsks.swift, Sources/AgentViewKit/HumanInTheLoop/RequestDeckWithdrawn.swift, Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift, Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift. Full `swift test`: 1659 tests in 203 suites passed (3 known issues, which tests expect on purpose and which were there before), plus the 219 package structure tests. There are 0 compiler warnings. The only warning is the SwiftPM build-graph line "missing creator for mutated node … mlx-swift_Cmlx.bundle", which comes from a dependency and was there before this change.
    - next: /review
  timestamp: 2026-10-22T23:29:49.145420+00:00
- actor: claude-code
  id: 01m5jzb5sntnw9hvdcx0j1e78p
  text: |-
    ### test — green
    - evidence: swift test (after touching the 4 changed Sources files and PreviewFixturesTests.swift) — 1659 tests in 203 suites passed, 0 failed, 0 skipped; 3 known issues are the intentional withKnownIssue negative-path tests (SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests). Only warning: the known SwiftPM mlx-swift "missing creator" notice; no project-code warnings.
    - next: review/commit
  timestamp: 2026-10-22T23:32:36.277599+00:00
- actor: claude-code
  id: 01m5jzhptsffgzrrzb5qm38zr6
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (831fcf8) — 0 findings, 0 confirmed, 1 refuted, 7 attempted, 0 failed; 5 files reviewed, 4 .kanban/ files excluded by .reviewignore
    - next: task moved to done
  timestamp: 2026-10-22T23:36:10.329861+00:00
- actor: claude-code
  id: 01m5jzj16acrfjasa5b9ynb4dr
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — previews in ElicitationCard.swift (5), ElicitationWhoAsks.swift, RequestDeckWithdrawn.swift; PreviewFixtures + 11 PreviewFixturesTests (red first); follow-up ^r8bnszx (show field errors only after an edit or a submit)
    - test: green — swift test 1659 passed, 0 failed, 0 skipped
    - commit: 831fcf8
    - review: clean — 0 findings (1 refuted), task in done
  timestamp: 2026-10-22T23:36:20.938625+00:00
position_column: done
position_ordinal: ffffbc80
title: 'AVK-14b Add #Preview blocks for ElicitationCard, ElicitationWhoAsksLine and WithdrawnNoticeRow'
---
## Goal

The user examines the look of each component in the Xcode canvas. These request views have no `#Preview`:

- `Sources/AgentViewKit/Elicitation/ElicitationCard.swift` — `ElicitationCard`
- `Sources/AgentViewKit/Elicitation/ElicitationWhoAsks.swift` — `ElicitationWhoAsksLine`
- `Sources/AgentViewKit/HumanInTheLoop/RequestDeckWithdrawn.swift` — `WithdrawnNoticeRow`

## Change

Add `#Preview` blocks in the same file as each view. Use `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`, and add to it if a value is missing. Give each preview a name that tells its state.

- [x] `ElicitationCard`: a form with each field kind, a form with a field that is not valid, a URL consent request, and the card in content and in the request deck in the bottom bar.
- [x] `ElicitationWhoAsksLine`: a short and a long name of the agent or the tool.
- [x] `WithdrawnNoticeRow`: one withdrawn request, and a long title.

Also examine the `elicitation-form-*` snapshot: the message "This field is necessary." shows before the user types. Show that state in a preview, and record on this card whether it is correct.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14