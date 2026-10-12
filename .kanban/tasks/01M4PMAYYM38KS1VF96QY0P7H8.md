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
- actor: claude-code
  id: 01m4qxjxc3z4yc1ksxy9sbst3t
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit 109389c): 1 finding, 1 confirmed, 0 refuted. Tests/PackageStructureTests/RemovedVocabularyTests.swift:276 (reuse/reuse).
    - next: Make one shared regex helper for the removed-input patterns, and make threadActionsInputUse, workingDirectoryInputUse and messageDateInputUse use it. Then do the review again.
  timestamp: 2026-10-12T11:22:22.979254+00:00
- actor: claude-code
  id: 01m4qxk7a08at0tkcash9exd3k
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — host date removed from the message views; RemovedVocabularyTests scans; README and comparison.md
    - test: green — swift test, 1163 tests passed, 2 expected known issues, load average 8 to 11
    - commit: 109389c
    - review: findings — Tests/PackageStructureTests/RemovedVocabularyTests.swift:276
  timestamp: 2026-10-12T11:22:33.152924+00:00
- actor: claude-code
  id: 01m4qxzt5ner02nd95b3nrd35n
  text: 'Fix of the reuse finding: `RemovedVocabularyTests.removedInputUse(of:input:)` now builds the removed-input pattern with RegexBuilder from the type names and the input label. `threadInitializerCall`, `workingDirectoryInputUse`, `threadActionsInputUse` and `messageDateInputUse` each call it with their own names. `threadInitializerCall` had the same shape (type name, open parenthesis, label and colon), so it also uses the helper. Its pattern now also finds `thread:` after other arguments and in a DocC link; no file matches. All four patterns now accept one level of parentheses in an argument (before, two of them stopped at the first `)`). The helper is not throwing, because `ReadmeCoverageTests` calls `threadInitializerCall()` inside `#expect`. A string `Regex(...)` would throw, so the helper folds the type names into a `ChoiceOf` with `reduce`. New test: `theRemovedInputPatternFindsTheInputOfEachTypeAfterNestedParentheses`. RED: compile error, no member `removedInputUse`. `RemovedInitializer.pattern()` has a different shape (labels in order, no type name), so it does not change.'
  timestamp: 2026-10-12T11:29:25.685235+00:00
- actor: claude-code
  id: 01m4qxzxc1p68hrjakmm2c4g8d
  text: |-
    ### implement — changed
    - evidence: 1 file, Tests/PackageStructureTests/RemovedVocabularyTests.swift. RED: `swift test --filter PackageStructureTests.RemovedVocabularyTests` gave a compile error (no member `removedInputUse`). GREEN: RemovedVocabularyTests and ReadmeCoverageTests, 37 tests passed. Full `swift test`: 1163 tests in 129 suites passed (2 known issues, the existing withKnownIssue tests), PackageStructure 122 tests passed. The one build warning is the existing `missing creator for mutated node` of the mlx-swift_Cmlx bundle (a dependency, not this change). Load average 5.84 at start, 4.70 at end. No UI tests run. Finding at RemovedVocabularyTests.swift:276 is checked.
    - next: /review
  timestamp: 2026-10-12T11:29:28.961858+00:00
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

## Review Findings (2026-10-12 06:20)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 7 file(s) reviewed, 4 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file
> - `comparison.md` — no validator matches this file

- [x] `Tests/PackageStructureTests/RemovedVocabularyTests.swift:276` `reuse/reuse` — The new messageDateInputUse pattern rebuilds the same regex shape as the existing threadActionsInputUse and workingDirectoryInputUse helpers: a call-site name list, an optional /init, an argument pattern, a parameter name followed by a colon, and simple word boundaries. Each new use adds another copy of this shape, so a fix to the pattern must be made in three places. The near-match should be generalized into one helper that takes the type names and the removed input name as parameters. Add one static helper, for example removedInputUse(of types: [String], input: String) -> Regex<Substring>, that builds the pattern from its parameters. Have threadActionsInputUse, workingDirectoryInputUse and messageDateInputUse call it with their own names. Keep the per-case names in each call so the data stays in the file that owns it.
