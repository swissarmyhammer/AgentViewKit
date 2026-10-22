---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5jqvjza482j1pyg5evfnxs9
  text: 'Research: none of the five views is public, so PreviewCoverageTests does not require them, but the card does. TranscriptMessageView/ReasoningBlock look the same while an entry streams (they never read agentState), so "streams" = a mid-stream entry: several chunks of one messageId folded by the merge engine (EntryContentView joins them), last chunk cut mid-word. TranscriptMessageView does not show SendState, so "a message with an error" = an agent message that reports a failed build with the compiler error in a code block. ThoughtEntryBlock closed/open is driven by an ExpandedBlocksStore(defaultExpanded:) in the environment. JSONDisclosure takes isExpanded in its init. Plan: PreviewFixtures.MessageSample / ThoughtSample enums (transcript + entry), contentOfEachKind, smallJSON / deepJSON; one private parameterized sample view per file. Note: ImageView and AudioPlayerView write their bytes to a cache file in the temporary directory (ContentBlockFile) when shown; the EntryContentView preview gives them in-memory bytes and reads no file, but that view-owned cache write is existing behavior and is not changed here.'
  timestamp: 2026-10-22T21:21:45.450589+00:00
- actor: claude-code
  id: 01m5jr9cq602c85qfvytvb199r
  text: |-
    Implementation landed (not committed):
    - PreviewFixtures (MARK: Transcript items): MessageSample (user, agent, streaming, failure, long) and ThoughtSample (complete, streaming) enums, each with `transcript`, `session` and `entry`; a streaming sample is chunk updates of one messageId (`streamedItems(_:as:)`), so the merge engine folds one entry with a block per chunk. contentOfEachKind (text, BMP image and WAVE sound with in-memory bytes, resource link, text and binary resource, unknown block), smallJSON / deepJSON, with named constants (reviewFindingCount, reviewFindingLine, waveMIMEType, reviewSummaryKind).
    - 10 new PreviewFixturesTests, written first; RED was the compile failure on the missing fixtures, then GREEN 60/60 in the suite.
    - Previews, one private parameterized sample view per file: TranscriptMessageSample (5), MessageLayoutSample (5), ThoughtEntryBlockSample(_:isOpen:) (3, the store is built in init so no assign-only property), JSONDisclosureSample (4: small/deep x closed/open), and one EntryContentView preview of each kind in order.
    - Note: run-watched.sh (the window monitor) is not on disk in this checkout, as ^m1dsrz2 recorded; the full suite ran with plain `swift test`.
    - Note: ImageView and AudioPlayerView still write their own cache file in the temporary directory (ContentBlockFile) when shown; the preview reads no file, but that view-owned write is existing behavior and was not changed.
  timestamp: 2026-10-22T21:29:17.798407+00:00
- actor: claude-code
  id: 01m5jr9j613p2w2sp1wrkvz553
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift, Sources/AgentViewKit/Items/TranscriptMessageView.swift, Sources/AgentViewKit/Items/MessageItemView.swift, Sources/AgentViewKit/Content/EntryContentView.swift, Sources/AgentViewKit/Items/ThoughtEntryBlock.swift, Sources/AgentViewKit/Items/JSONDisclosure.swift, Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift. `swift test --filter PreviewFixturesTests`: 60 passed. Full `swift test`: exit 0; 1649 tests in 203 suites passed (3 known issues, the existing withKnownIssue negative tests), 219 tests in 29 suites passed (PreviewCoverageTests and GlassPlacementTests passed), 1 test in 1 suite passed. No compiler warning; only the existing SwiftPM mlx-swift_Cmlx bundle build line. swiftlint no_magic_numbers/force_*: 0 on the changed files.
    - next: /review
  timestamp: 2026-10-22T21:29:23.393933+00:00
- actor: claude-code
  id: 01m5jv8xan6gxjc8xt9k766jae
  text: |-
    ### test — green
    - evidence: `swift test` (6 changed Sources files and PreviewFixturesTests.swift touched first) — 1649 tests in 203 suites passed, 0 failed, 0 skipped; PreviewFixturesTests suite passed; no warnings from project code (only the known mlx-swift "missing creator" notice). The 3 known issues are the intentional expected-failure tests (SnapshotStoreTests theCheckOfAViewThatChangedRecordsAnIssue, HostedLayoutExpectationsTests aWrappedTextWithAFixedVerticalSizeFails, ThemeHeightExpectationsTests aViewThatIgnoresTheThemeFails).
    - next: commit
  timestamp: 2026-10-22T22:21:27.765978+00:00
position_column: doing
position_ordinal: '8380'
title: 'AVK-14d Add #Preview blocks for the transcript item views'
---
## Goal

The user examines the look of each component in the Xcode canvas. These transcript views have no `#Preview`:

- `Sources/AgentViewKit/Items/TranscriptMessageView.swift` — `TranscriptMessageView`
- `Sources/AgentViewKit/Items/MessageItemView.swift` — `MessageLayout`
- `Sources/AgentViewKit/Content/EntryContentView.swift` — `EntryContentView`
- `Sources/AgentViewKit/Items/ThoughtEntryBlock.swift` — `ThoughtEntryBlock`
- `Sources/AgentViewKit/Items/JSONDisclosure.swift` — `JSONDisclosure`

## Change

Add `#Preview` blocks in the same file as each view. Use `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`, and add to it if a value is missing. Give each preview a name that tells its state.

- [x] `TranscriptMessageView` and `MessageLayout`: a user message, an agent message, a message that streams, a message with an error, and a very long message.
- [x] `EntryContentView`: each content kind that it shows, one after the other.
- [x] `ThoughtEntryBlock`: closed, open, and a thought that streams.
- [x] `JSONDisclosure`: closed, open, small JSON, and deep JSON with long values.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14