---
assignees:
- claude-code
position_column: todo
position_ordinal: 8f80
title: Inspector Time rows in the timing-line styles (needs an EditorInspector Field format hook)
---
Split from ^sy19jd4. The inspector Time group (`ObservableTranscriptEntry.timeGroup` in `Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift`) should show Started and Ended in `EntryTimingView.startStyle(locale:timeZone:)` ("6:13 AM") and Duration in `EntryTimingView.lineDurationStyle(locale:)` ("1m 15s"), through EK's `DateText` / `DurationText`, which take any FormatStyle since EK b707d51a.

**Blocked on EditorKit.** At EK b707d51a, `EditorInspector.Field` takes for a `Date` only `.dateComponents(DateFieldComponents)` (`.date` / `.dateAndTime`, numeric), and for a `Duration` only `.durationFormat(DurationFieldFormat)` (a parseable positional format). `FieldReadOnlyRow` builds `DateText(_, components:)` and `DurationText(_, format: DurationFieldFormat)`. No Field modifier takes a `Date.FormatStyle` or a `Duration.UnitsFormatStyle` for the read-only row, and ARCHITECTURE.md forbids an AVK view inside an inspector. EK needs e.g. `Field.dateFormat(_: Date.FormatStyle)` and `Field.durationFormat(_: some FormatStyle<Duration, String>)` (read-only display) before AVK can adopt it.

## Tests
- [ ] Unit test: the Time rows of a timed entry show the start in `startStyle` and the duration in `lineDurationStyle` (inspection read through EK's inspector test support).