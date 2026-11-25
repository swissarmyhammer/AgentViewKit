---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'Scroll perf 2: the Copy Thread availability check does not render the thread'
---
User request (2026-11-25): "scrolling is still way too slow", stay with SwiftUI. The scroll profile found this is 14.7% of main-thread time at rest and 26.9% while an answer streams.

## What

- `Sources/AgentViewKit/Commands/AgentCommandTarget.swift` (about line 475): `case .copyThread: !Self.plainText(of: session).isEmpty` renders the whole thread through the `copy-text` Stencil template (`plainText(of:)`, about line 954) only to find out if the text is empty. One call costs 2.66 ms for 312 entries. The button is in each message footer (`Sources/AgentViewKit/Items/MessageActions.swift`, about lines 202 and 252), and `EditorButtonSourceReader.body` asks for the availability. Each streamed chunk changes the transcript, so each realized footer button asks again (about 6 renders of the whole thread per chunk).
- [ ] Add a cheap check, for example `ThreadExporter.hasMessageText(in:)`, that returns `true` at the first message with text that the copy would keep, with no template render. It must give the same answer as `!plainText(of:).isEmpty` for each transcript.
- [ ] Use it at `case .copyThread`.

## Acceptance Criteria

- [ ] The availability check of Copy Thread renders no template.
- [ ] Copy Thread is available in the same cases as before (an empty thread and a thread with only tool calls keep their current answers).

## Tests

- [ ] New tests in `Tests/AgentViewKitTests/Commands/`: the new check and `!plainText(of:).isEmpty` agree for an empty transcript, only tool calls, only a user message, a message with empty text, and a long mixed transcript.
- [ ] A counter test: a package counter on the template render of `plainText`. Mount 20 message rows with footers (window never ordered in), stream 50 agent message chunks with `session.apply`, one layout pass each, and expect 0 renders.
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf