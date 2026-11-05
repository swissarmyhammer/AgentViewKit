---
assignees:
- claude-code
position_column: todo
position_ordinal: 8f80
title: Inspector object ids of transcript entries and sessions are debug descriptions
---
Found while working ^j5c8yfv (AttachmentInspector scheme ids).

EK's `InspectorScheme.objectID(of:key:)` makes the object part of a row's scheme id from `String(describing: object.id)`. For the AVK `Inspectable` conformances of FoundationModelsACPClient models, that id is a type AVK does not own and that has no readable description:

- Each transcript entry (`ToolCallEntry`, `TerminalEntry`, `UserMessageEntry`, `AgentMessageEntry`, `ThoughtEntry`, `SessionMessageEntry`, `PlanTranscriptEntry`, `CompactionEntry`, `ErrorEntry`, `UnknownEntry`) has `id: TranscriptEntry.ID`, an enum (`.wire(SessionEntry.ID)` / `.local(UUID)`) with no `CustomStringConvertible`, so the object part is a debug description such as `wire(FoundationModelsACP.SessionEntry.ID.toolCall(...))`, escaped.
- `SessionModel.id` is FMACP `SessionId`, a `RawRepresentable` struct with no description, so it reads `SessionId(rawValue: "...")`, escaped. This also reaches `ConfigOptionsView`'s `inspection:config-options/object:<session>` ids.

AVK cannot change these: the `Identifiable` conformances live in FMACP/FMACPClient, and AttachmentInspector's fix (an AVK-owned wrapper object with a `String` id) does not apply to `InspectorView(entry)` of the model itself.

- [ ] Decide where the fix goes: a readable `description` on `TranscriptEntry.ID` and `SessionId` in FMACP/FMACPClient, or an EK hook for the object id of an `Inspectable` (do not edit EK from AVK).
- [ ] Once the ids are readable, add a hosted test in AVK that the shown row id of an entry inspector equals its documented format.