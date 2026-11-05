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
- actor: claude-code
  id: 01m6p7mkgkh7mdv1a9xsfxryjc
  text: |-
    Implementation landed (uncommitted, worktree):
    - Chose `attachment` (not `inspected-attachment`): it names the public `Attachment` a host knows, matches the group key so rows read `field:attachment.preview`, and `InspectedAttachment` is a private wrapper that should not leak into ids. `AttachmentInspector.viewIdentifier` is now `public static let viewIdentifier = "attachment"` and the inspection takes it as its explicit id.
    - `InspectedAttachment.id` is now `String` (`attachment.id.rawValue`). EK `InspectorScheme.objectID` escapes it as expected: `draft/notes.md` -> `draft%2Fnotes%2Emd`; a file URL id `file:///tmp/a.txt` -> `file:%2F%2F%2Ftmp%2Fa%2Etxt`.
    - Exact format: `inspection:attachment/object:<escaped raw id>/name` and `inspection:attachment/object:<escaped raw id>/field:attachment.preview`; several files join object ids with `+`. Example: `inspection:attachment/object:draft%2Fnotes%2Emd/name`.
    - Other conformances given explicit ids (were type-name keys like `toolcallentry`): ToolCallEntry `tool-call`, TerminalEntry `terminal`, UserMessageEntry `user-message`, AgentMessageEntry `agent-message`, ThoughtEntry `thought`, SessionMessageEntry `session-message`, PlanTranscriptEntry `plan`, CompactionEntry `compaction`, ErrorEntry `error`, UnknownEntry `unknown-update`, SessionModel `session`, ConnectionModel `connection` (its positional object id becomes `connection-1`), MCPServerItem `mcp-server`, ConfigOptionFields' inspection `config-options` (= ConfigOptionsView.viewIdentifier). `Inspection.named(_:id:...)` and `MessageInspection.inspection(id:...)` now require the id.
    - Debug-description object ids of FMACP types (TranscriptEntry.ID, SessionId) are outside AVK: filed ^t1q70r0.
    - Tests: unit AttachmentInspectionTests (+4) and new InspectionIdentifierTests, both watched RED then GREEN. Hosted AttachmentInspectorSchemeHostedTests watched RED (shown ids were `inspection:inspectedattachment/object:Attachment(...)`); reads rows by accessibility id via the harness's InspectorDriver (`showsRow`), no mouse, no focus.
    - Note: hosted runs queue behind other repos' hosted suites (shared serial lock); a single hosted test took 683 s wall time waiting, not working. A first draft that snapshotted the whole accessibility tree was replaced with `showsRow`.
  timestamp: 2026-11-05T16:10:58.963805+00:00
- actor: claude-code
  id: 01m6p7t2jvb0vym0c357m6hv3p
  text: |-
    ### implement — changed
    - evidence: commit aa4b8da1 (not pushed, not merged). 8 files — Sources/AgentViewKit/Attachments/AttachmentInspector.swift, Sources/AgentViewKit/Config/ConfigOptionFields.swift, Sources/AgentViewKit/Inspection/ClientModels+Inspectable.swift, Sources/AgentViewKit/Inspection/InspectionLabel.swift, Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift, Tests/AgentViewKitTests/Attachments/AttachmentInspectionTests.swift, Tests/AgentViewKitTests/Inspection/InspectionIdentifierTests.swift (new), IntegrationTests/Tests/IntegrationTests/Attachments/AttachmentInspectorSchemeHostedTests.swift (new). Root `swift test`: 988 tests / 111 suites + 48 / 9 passed, no own-target warnings. Full IntegrationTests: 956 tests / 130 suites passed (5 known issues are FontRoleExpectationsTests' intentional negative checks). HEAD contains 6fd107e7; EK resolved at main 73033d2; no Package.resolved pins.
    - next: /review
  timestamp: 2026-11-05T16:13:58.235370+00:00
position_column: done
position_ordinal: ffffffad80
title: AttachmentInspector scheme ids are explicit and readable
---
Reported by Testudo: its XCUITest runs out of process and matches accessibility id text.

## Problem
- `Sources/AgentViewKit/Attachments/AttachmentInspector.swift` documents `inspection:inspected-attachment/object:<id>/...`, but the running app shows `inspection:inspectedattachment/object:Attachment(file:%2F%2F...)/name`.
- `viewIdentifier` is `inspection.id`, which EK derives from the type name.
- The object part is `String(describing:)` of `Identifier<Attachment>`, a debug description.

## Fix
- [x] Give the inspection an explicit, stable id with EK's `Inspection(id:)` ("attachment" or "inspected-attachment"; state which). -> `attachment`.
- [x] Give `InspectedAttachment` a `String` id from `attachment.id`'s raw value, so the object part is the raw id string.
- [x] Check EK's `InspectorScheme.objectID` escapes it as expected. (`draft/notes.md` -> `draft%2Fnotes%2Emd`)
- [x] Correct the doc comments on the type, `nameIdentifier(of:)` and `previewIdentifier(of:)` to the exact real format, with one concrete example.
- [x] Hosted test: the row id the app shows equals `nameIdentifier(of:)` and `previewIdentifier(of:)` for a known attachment, read through accessibility (no mouse, no focus stealing).
- [x] Check other AVK Inspectable conformances for ids derived from a type name or debug description; give any explicit ids and note them on the card. (13 conformances + the config options inspection; FMACP-owned object ids filed as ^t1q70r0)
- [x] Root `swift test` and full IntegrationTests green.

## New id format
- `inspection:attachment/object:<escaped raw id>/name`
- `inspection:attachment/object:<escaped raw id>/field:attachment.preview`
- Several files join escaped raw ids with `+`.
- Example: attachment id `draft/notes.md` -> `inspection:attachment/object:draft%2Fnotes%2Emd/name`