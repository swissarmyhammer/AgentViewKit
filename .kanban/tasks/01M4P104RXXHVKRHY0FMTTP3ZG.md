---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4p11v4dvxy0b3nmkd23xne4
  text: '2026-10-11: FoundationModelsACPClient accepted the per-entry times as its task ^gs1cx8r (names can change): each TranscriptEntry gets `startedAt: Date?`, `endedAt: Date?`, computed `duration: TimeInterval?`, each written one time only. `endedAt` of a message or thought is when the next entry starts or an idle `state_update` arrives; of a tool call, when its status first becomes `completed` or `failed`. Replayed and history entries have nil times. Injectable clock `now: @Sendable () -> Date` on ConnectionModel and SessionModel. Schema alpha.8 has no timestamp on session updates, so every time comes from the client clock. Turn times (prompt sent, first update, stop) are NOT in that task: the owner said earlier that the client has no turn concept; the client session asked the owner. The client pushes only with the owner''s approval. If there are no turn times, the turn-duration item of this card is dropped (the kit must not record times itself).'
  timestamp: 2026-10-11T17:44:29.069201+00:00
position_column: todo
position_ordinal: '8580'
title: 'Message timing: show entry and turn times from the client model'
---
## What
Decision of the owner (2026-10-11), from `comparison.md` (row "Message timing" and row "Thought for N seconds", section 4 note "Do not show Thought for N seconds. The model has no times"): the kit shows message timing. assistant-ui has a message timing element. Vercel AI Elements `Reasoning` shows "Thought for N seconds".

Decision of the owner (2026-10-11): the time is a decorator. A view modifier wraps a message (or another transcript row) with a view that tells when. The message views do not show times by themselves. A host attaches the decorator, or does not.

The times come from the FoundationModelsACPClient models, not from the kit. The kit keeps no parallel state. The request was sent to the FoundationModelsACPClient session (foundationmodelsacpclient-62) on 2026-10-11: start and end times for each transcript entry, turn times (prompt sent, first update, stop), nil times for replayed history unless the wire has a time, an injectable clock, and no per-chunk time updates. This card waits for that commit.

## Work
- [ ] When the client commit is pushed, move the FoundationModelsACPClient pin.
- [ ] A timing decorator: a view modifier (for example `.entryTiming(_ entry:)` or `.transcriptTiming()`) that wraps a transcript row with a small view that shows when the entry started and, when it ended, its duration. It reads the times from the client entry. It has no style protocol and no style override (owner decision 2026-10-11): its colors and fonts come from the EditorKit theme.
- [ ] A way to attach the decorator to every row of `ConversationView` and `AgentThreadView` in one place (for example an environment value or a row decorator slot), so that the host does not wrap each row by hand. The default is no decorator.
- [ ] The same decorator works on user messages, agent messages, thoughts and tool calls. The turn duration shows at the end of the turn through the same pattern.
- [ ] `ReasoningView`: "Thought for N seconds" comes from the thought entry duration. Remove the kit `duration` parameter that is always `nil` (`Sources/AgentViewKit/Items/ReasoningView.swift:91`, `:105`, `:156`, `:200`), or bind it to the client value.
- [ ] Replayed entries with no time show no time (the decorator shows nothing).
- [ ] Format with the system formatters (`Date.FormatStyle`, `Duration.UnitsFormatStyle`), localized; VoiceOver reads the time with the message.
- [ ] Tests with the injectable clock of the client: the decorator shows the expected time and duration; with no decorator, no time shows; a replayed entry shows none.
- [ ] README: show how to attach the decorator. Update `comparison.md` (rows "Message timing" and "Thought for N seconds", the note in section 4, and section 5 cross-cutting concerns).