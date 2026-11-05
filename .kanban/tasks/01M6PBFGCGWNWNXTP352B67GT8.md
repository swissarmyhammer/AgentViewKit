---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6pj1h0yws3tyee6scde2y44
  text: 'Unblocked: EK 40928bc8 (^d2cjb2x) adds `DisplayField(label, format:) { }` for Date, Date?, Duration and Duration? (dash for nil, read-only by type, `.visible { }`). A `Date.FormatStyle` is re-zoned by EK to the view''s locale and `\.timeZone` (`ValueTextFormat` calls `zoned(locale:timeZone:)`); any other style gets `.locale(viewLocale)`. So AVK builds the styles with no fixed locale/zone. Research: the only reader of the rows is `ClientModelInspectionHostedTests.theDurationRowOfAToolCallShowsTheTimeToItsCompletion` (IntegrationTests), which expected `durationRowFormat` ("1:15"). Inspector tests need EditorInspectorTestSupport, which only IntegrationTests links, so the row tests are hosted.'
  timestamp: 2026-11-05T19:12:48.158386+00:00
- actor: claude-code
  id: 01m6pjqk5e2cwra9tvvj4r1r03
  text: 'Implementation landed. `EntryTimingView` gains locale-free `startStyle` and `lineDurationStyle` (static computed vars); `startStyle(locale:timeZone:)` / `lineDurationStyle(locale:)` now derive from them, and the private `durationStyle` builder no longer takes a locale. The Time group is three `DisplayField`s (Started/Ended in `startStyle`, Duration in `lineDurationStyle` of `timing.duration.map(Duration.seconds)`, still `.visible` on `shownDuration`); `durationRowFormat` (DurationFieldFormat) and the default DateFieldComponents rows are gone. `TimedSessionClock` (AgentViewKitTestSupport) now owns `zoneOtherThanTheMachines()` (moved from EntryTimingHostedTests) so the inspector suite reuses it. TDD: unit RED/GREEN in EntryTimingTextTests (2 tests); hosted RED (3 failed: duration showed "1:15", started/ended numeric) then GREEN (4 tests) in ClientModelInspectionHostedTests. Note: a failing hosted duration test took ~175 s (the render wait runs to its timeout), not a hang.'
  timestamp: 2026-11-05T19:24:51.246845+00:00
position_column: doing
position_ordinal: 9c80
title: Inspector Time rows in the timing-line styles (needs an EditorInspector Field format hook)
---
Split from ^sy19jd4. The inspector Time group (`ObservableTranscriptEntry.timeGroup` in `Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift`) should show Started and Ended in `EntryTimingView.startStyle(locale:timeZone:)` ("6:13 AM") and Duration in `EntryTimingView.lineDurationStyle(locale:)` ("1m 15s"), through EK's `DateText` / `DurationText`, which take any FormatStyle since EK b707d51a.

**Blocked on EditorKit.** At EK b707d51a, `EditorInspector.Field` takes for a `Date` only `.dateComponents(DateFieldComponents)` (`.date` / `.dateAndTime`, numeric), and for a `Duration` only `.durationFormat(DurationFieldFormat)` (a parseable positional format). `FieldReadOnlyRow` builds `DateText(_, components:)` and `DurationText(_, format: DurationFieldFormat)`. No Field modifier takes a `Date.FormatStyle` or a `Duration.UnitsFormatStyle` for the read-only row, and ARCHITECTURE.md forbids an AVK view inside an inspector. EK needs e.g. `Field.dateFormat(_: Date.FormatStyle)` and `Field.durationFormat(_: some FormatStyle<Duration, String>)` (read-only display) before AVK can adopt it.

## Tests
- [ ] Unit test: the Time rows of a timed entry show the start in `startStyle` and the duration in `lineDurationStyle` (inspection read through EK's inspector test support).