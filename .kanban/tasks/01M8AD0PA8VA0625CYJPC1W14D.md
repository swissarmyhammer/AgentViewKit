---
assignees:
- claude-code
position_column: todo
position_ordinal: '8880'
title: The Gallery detail shows no transcript row for the recorded session django__django-14672
---
CI run 45690990838 (commit 7b783755) failed in the Integration job. The last green run is bdce61a2. Local `swift test --no-parallel --package-path IntegrationTests --filter RecordedSessionsGalleryHostedTests` fails in the same way.

```text
✘ theGalleryDetailShowsATranscriptRowOfEachRecordedSession() at RecordedSessionsGalleryHostedTests.swift:52
↳ SessionId("01M4PK9Z6EC0GH5VCXH778X4RW")
↳ Self.transcriptRowIdentifiers(in: harness) → []
```

## What
- [ ] Find the commit between bdce61a2 and HEAD that causes the failure. Suspects: 574ebdf9 (one `TranscriptRowElement` for each ForEach element, `Sources/AgentViewKit/Thread/TranscriptRowElement.swift`) and 4ea3642f (`ProposalSizedLayout` in `Sources/AgentViewKit/Thread/ConversationView.swift`).
- [ ] Find the cause in that commit, and correct it. Keep the perf goal of the commit.
- [ ] Add a unit test in `Tests/AgentViewKitTests` that fails before the fix, if a headless test can show the cause.

## Acceptance Criteria
- [ ] `RecordedSessionsGalleryHostedTests` passes with `--no-parallel` (3 tests, 0 issues).
- [ ] The CI Integration job is green.

## Tests
- [ ] `swift test --no-parallel --package-path IntegrationTests --filter RecordedSessionsGalleryHostedTests` passes (a hosted run: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc).
- [ ] `swift test` passes with 0 failures and 0 warnings. A temp HOME is not possible, because the harness refuses the HOME override.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #bug