---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6p4tj7gs3j8gypft0c8t32a
  text: |-
    Research:
    - EK `Inspection.init(id:title:name:_:)` defaults `id` to `InspectorKey.key(of: String(describing: Object.self))` — lowercase letters/digits with hyphens only between non-alphanumeric runs, so `InspectedAttachment` -> `inspectedattachment` (no hyphen; the doc comment was wrong).
    - EK `InspectorScheme.objectID(of:key:)` takes `String(describing: object.id)` and escapes `%`, `/`, `.`, `+` as `%XX`. `Identifier<Tag>.description` is `Tag(raw)`, hence `Attachment(file:%2F%2F...)`. With a `String` id the object part is the escaped raw id, e.g. `draft/notes.md` -> `draft%2Fnotes%2Emd`.
    - AVK's `Inspection.named(...)` helper (InspectionLabel.swift) builds `Inspection(title:name:)` with no id, so every conformance through it has a type-name id. Type-name ids found: ToolCallEntry, TerminalEntry, UserMessageEntry, AgentMessageEntry, ThoughtEntry, SessionMessageEntry (via MessageInspection), PlanTranscriptEntry, CompactionEntry, ErrorEntry, UnknownEntry, SessionModel, ConnectionModel, MCPServerItem, and ConfigOptionFields.inspection (SessionModel, view id already explicit `config-options`). ToolToggles already explicit (`tool-toggles`).
    - Debug-description object ids AVK cannot change: the transcript entries' `id` is FMACPClient `TranscriptEntry.ID` (an enum with no CustomStringConvertible) and SessionModel's is FMACP `SessionId` (a RawRepresentable struct with no description) — both describe as debug text. Their Identifiable conformance lives in FMACPClient/FMACP, so the fix is outside AVK (filed as a separate card).
  timestamp: 2026-11-05T15:21:48.528771+00:00
position_column: doing
position_ordinal: '9580'
title: AttachmentInspector scheme ids are explicit and readable
---
Reported by Testudo: its XCUITest runs out of process and matches accessibility id text.

## Problem
- `Sources/AgentViewKit/Attachments/AttachmentInspector.swift` documents `inspection:inspected-attachment/object:<id>/...`, but the running app shows `inspection:inspectedattachment/object:Attachment(file:%2F%2F...)/name`.
- `viewIdentifier` is `inspection.id`, which EK derives from the type name.
- The object part is `String(describing:)` of `Identifier<Attachment>`, a debug description.

## Fix
- [ ] Give the inspection an explicit, stable id with EK's `Inspection(id:)` ("attachment" or "inspected-attachment"; state which).
- [ ] Give `InspectedAttachment` a `String` id from `attachment.id`'s raw value, so the object part is the raw id string.
- [ ] Check EK's `InspectorScheme.objectID` escapes it as expected.
- [ ] Correct the doc comments on the type, `nameIdentifier(of:)` and `previewIdentifier(of:)` to the exact real format, with one concrete example.
- [ ] Hosted test: the row id the app shows equals `nameIdentifier(of:)` and `previewIdentifier(of:)` for a known attachment, read through accessibility (no mouse, no focus stealing).
- [ ] Check other AVK Inspectable conformances for ids derived from a type name or debug description; give any explicit ids and note them on the card.
- [ ] Root `swift test` and full IntegrationTests green.