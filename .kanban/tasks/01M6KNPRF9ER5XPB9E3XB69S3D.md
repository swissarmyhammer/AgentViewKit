---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6m0gxf2j06cq5557pvs2z2r
  text: |-
    Picked up 2026-11-04. The "Blocked" line is obsolete: EK ^d2fa1j4 is on EK origin at a2ae6249. `swift package update` ran in the root, IntegrationTests/ and ScreenshotTests/, and all three resolve EditorKit at a2ae6249.

    Build fixes for a2ae6249, the same as the main-checkout fix: `Field`/`FieldGroup` labels are now `FieldLabel(localized:bundle:)`, and runtime names are `.verbatim(...)` (Inspection/*.swift, Input/ToolToggles.swift, Config/ConfigOptionFields.swift; `InspectionLabel` now returns `FieldLabel`). Sources/AgentViewKitStyle/Symbols/LiveSymbolEffect.swift is deleted and EK's `liveSymbolEffect(isActive:)` is used instead. I removed its DocC entries, updated the StatusBar/ToolCallView doc text and ARCHITECTURE.md, and added `import EditorSwiftUI` to IntegrationTests StatusBarTests.

    Survey of single-value number, date and duration display:
    - EntryTimingView (tool call and turn timing: start time and duration) uses `Text(startText)` and `Text(durationText(.abbreviated))`. Both move to EK's DateText and DurationText.
    - Inspection Time group: Started/Ended stay optional dates, because EK's `.date` kind takes a non-optional Date. The duration row was missing and is added as `.duration`.
    - ReasoningView "Thought for 7 seconds" and the VoiceOver labels of the timing line put the duration inside a sentence (wide units). EK has no spoken format, and DurationFieldFormat's "0:07" doesn't fit in a sentence. So `spokenDuration` keeps Foundation's `Duration.UnitsFormatStyle(width: .wide)`. The abbreviated copy (`durationText`) and `startText` are deleted.
    - SessionListView session time: `Text(updatedAt, format: .relative(...))`. This is a relative date ("Yesterday"). EK has no relative format, and RelativeFormatStyle isn't parseable, so it can't be a ValueFieldFormat. It stays.
    - PendingRequestCountBadge `Text(count, format: .number)` uses the ui caption font. NumberText pins the ui body style, which would grow the badge. It stays.
    - UsageRingView percentText/detailText and ContextUsageView costText make numbers inside phrases ("1,200 of 4,000 tokens", percent, currency). They are not single-value displays and stay.
    - Elicitation number input (AgentOneLineField value form), slider readout and DatePicker: elicitation inputs draw in the display font role (FontRoleHostedTests), but EK's NumberField/NumberText pin `ui`. Moving them is a font decision outside this timing card, so I filed it as its own card.
    - Sibling grep (origin mains of KVK 701a93d, SVK and Testudo): no use of EntryTimingView.startText/durationText, LiveSymbolEffect or liveSymbolEffect in code, only in .kanban notes. Nothing to keep.

    Discovery: on EK a2ae6249 the inspector row ids are the scheme path (`inspection:<view>/object:<id>/field:<group>.<field>`). So every old-id check in ClientModelInspectionHostedTests (`tool-call.tool-call.title`, …) fails after the update, before any change of mine.
  timestamp: 2026-11-04T19:28:09.186758+00:00
position_column: doing
position_ordinal: '8580'
title: Adopt EditorKit number, date and duration (^d2fa1j4) for AVK's timing fields
---
**Unblocked (2026-11-04):** the old "Blocked on ^d2fa1j4" line is obsolete. EK ^d2fa1j4 is on EK origin at a2ae6249 (`NumberField`/`NumberText`, `DateField`/`DateText` with `DateFieldComponents`, `DurationField`/`DurationText` with `DurationFieldFormat`, the `.duration` inspection kind with `.durationFormat(_:)`). AVK builds on a2ae6249.

Boundary (user, 2026-11-04): single-value controls are EK's; compound views stay in AVK.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Survey AVK's timing fields (tool call timing such as start and duration, turn and session times, and any number or date formatting AVK does for one value). Replace each with EK's number, date/time or duration field. Delete AVK's own formatting and controls for them.

## Acceptance Criteria
- [ ] No AVK copy of a single number, date or duration control or formatter is left.
- [ ] Timing shows through EK's fields, with EK's theming.
- [ ] The review gallery shows the timing users, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.
- [ ] Timing tests move onto EK's API, or are dropped where EK covers them. Each dropped check is written on the card.