---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4qwp7n5cr798jgg0am7tmb1
  text: 'Decision of the owner (2026-10-12): remove the host `date:` parameter from UserMessageView and MessageHeader (and any other message view that takes a host date). The timing decorator (`EntryTimingView`, `.entryTiming(_:)`, `.transcriptTiming()`) is the only way to show a time. This is a breaking API change; update the README, the demo, the tests and comparison.md.'
  timestamp: 2026-10-12T11:06:43.237888+00:00
- actor: claude-code
  id: 01m4qwtraw9msa5ye1jzhppr9x
  text: 'Research: the host date goes through 5 types. `UserMessageView(entry:date:)`, `AssistantMessageView(entry:date:)` (also takes a date, the card did not name it), `TranscriptMessageView.date`, `MessageLayout.date` and `MessageHeader(role:date:)` with `relativeText(for:now:)` and `dateIdentifier`. No caller in Sources, the demo, the README or the README snippets gives a date. Only `MessageViewsHostedTests` uses it (3 tests). README and comparison.md do not name the parameter. The `MessageLayout` doc names `MessageBodyView`, a type that does not exist (stale DocC link). Plan: a RemovedVocabularyTests scan for the removed symbols and for a `date:` argument of a message view (RED), then remove the parameter.'
  timestamp: 2026-10-12T11:09:11.388180+00:00
- actor: claude-code
  id: 01m4qx7z57g6sx2r776p213k42
  text: |-
    ### implement — changed
    - evidence: 8 files. Sources/AgentViewKit/Items/{MessageHeader,UserMessageView,AssistantMessageView,TranscriptMessageView,MessageItemView}.swift; Tests/PackageStructureTests/RemovedVocabularyTests.swift; Tests/AgentViewKitTests/Items/MessageViewsHostedTests.swift; README.md; comparison.md. RED: `swift test --filter RemovedVocabularyTests` failed 2 new tests (noFileGivesADateToAMessageView, noFileUsesTheRelativeTimeOfTheMessageHeader). Full `swift test`: 1163 tests in 129 suites passed (2 known issues, the existing withKnownIssue tests), PackageStructure 121 tests passed. Load average 11.25 at start, 9.28 at end. Demo: xcodebuild build-for-testing of AgentViewKitDemo, TEST BUILD SUCCEEDED (load 10.62 to 11.64). README snippets: extraction gives no change. No UI tests run.
    - notes: `AssistantMessageView` also took a host date; the change removes it too. The `MessageLayout` doc named `MessageBodyView`, a type that does not exist; the change removes that sentence. `MessageHeader` is now one `Text`, so it does not read `agentTheme`.
    - next: /review
  timestamp: 2026-10-12T11:16:24.359664+00:00
position_column: doing
position_ordinal: '80'
title: 'Message views: decide on the host date parameter of UserMessageView and MessageHeader'
---
## What
Found during ^mttp3zg. The owner decided (2026-10-11) that the time of an entry is a decorator (`EntryTimingView`, `.transcriptTiming()`, `.entryTiming(_:)`), and that the message views do not show times by themselves.

The kit still has a host `date:` parameter that makes a message view show a relative time in its header:
- `UserMessageView(entry:date:)` (`Sources/AgentViewKit/Items/UserMessageView.swift`)
- `AssistantMessageView(entry:date:)` (`Sources/AgentViewKit/Items/AssistantMessageView.swift`)
- `TranscriptMessageView(entry:date:)` and `MessageLayout.date` (`Sources/AgentViewKit/Items/MessageItemView.swift`, `Items/TranscriptMessageView.swift`)
- `MessageHeader(role:date:)` and `MessageHeader.relativeText(for:now:)` (`Sources/AgentViewKit/Items/MessageHeader.swift`)

`ItemRow` always gives `nil`, so the default rows show no date. A host that gives a date gets a second time display, beside the decorator.

## Decision of the owner (2026-10-12)
Remove the host `date:` parameter from each message view. The timing decorator is the one way to show a time.

## Work
- [x] Ask the owner: remove the `date:` parameters (the decorator is the one way to show a time), or keep them. The owner decided: remove them.
- [x] Remove `date:` from `UserMessageView`, `AssistantMessageView`, `TranscriptMessageView`, `MessageLayout` and `MessageHeader`. Remove `MessageHeader.relativeText(for:now:)`, `MessageHeader.dateIdentifier`, and the doc text of the date.
- [x] Tests: `RemovedVocabularyTests` finds no `date:` argument of a message view and no use of `relativeText` or `dateIdentifier` in the sources, the tests, the examples and the README. `MessageViewsHostedTests` replaces the date tests with a test that the header shows only the name of the sender.
- [x] README (Message timing) and comparison.md (section 5.17) state that the message views take no date. The README snippets and the demo used no date, so they do not change.