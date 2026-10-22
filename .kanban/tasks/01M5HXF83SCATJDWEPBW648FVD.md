---
assignees:
- claude-code
position_column: todo
position_ordinal: a280
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

- [ ] `TranscriptMessageView` and `MessageLayout`: a user message, an agent message, a message that streams, a message with an error, and a very long message.
- [ ] `EntryContentView`: each content kind that it shows, one after the other.
- [ ] `ThoughtEntryBlock`: closed, open, and a thought that streams.
- [ ] `JSONDisclosure`: closed, open, small JSON, and deep JSON with long values.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14