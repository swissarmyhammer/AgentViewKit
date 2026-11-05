---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6p9046btdfkk0ekb3bwex51
  text: |-
    Research (implement):
    - Setup: HEAD contains 79c0c2d7; root/IntegrationTests/ScreenshotTests .build seeded from the main checkout; `swift package update` in all three (no Package.resolved anywhere). EditorKit resolved at main 73033d2.
    - EK `InspectorScheme.objectID(of:key:)` (unchanged at 73033d2) still makes the object part from `escaped(String(describing: object.id))`. EK has NO hook for an object id (no protocol, no closure on Inspection/InspectorView), so the fix is the AVK wrapper the card names.
    - Public raw values exist for every id, so nothing is needed upstream: `TranscriptEntry.ID` is `.wire(SessionEntry.ID)` / `.local(UUID)` (UUID.uuidString); `SessionEntry.ID` cases carry `MessageId`/`ToolCallId`/`TerminalId`/`PlanId`/`CompactionId` (each `public let rawValue: String`) or `.unidentified(position: Int)`; `SessionId.rawValue: String`.
    - `ConnectionModel` is not Identifiable (positional `connection-1`, fine); `MCPServerItem.id` is already a String (fine).
    - The kind must stay in the entry id: a thought and an agent message may share one `messageId`, and in a mixed `InspectorView([any Inspectable])` (view id `inspector`) both blocks have the group/field `message.text`, so a bare raw id would give two rows the same scheme id.
    - No production AVK code does `InspectorView(entry)`; ConfigOptionsView does `InspectorView(session, ConfigOptionFields.inspection(...), id: "config-options")`. Tests: ClientModelInspectionHostedTests, InspectorPanelHostedTests, ConfigOptionsSessionModelHostedTests, InspectionIdentifierTests, InspectionPathTests, ScreenshotTests InspectorGallery(Fixtures).
    - Siblings (origin main): KVK c… and SVK use only their own inspections; Testudo 6f97e57 uses its own Selected* classes and matches `inspection:inspectedattachment/object:` (attachment row only, already stale since ^j5c8yfv); its comment plans `Kit.inspection.adding {}` on the AVK models.

    Plan: an AVK generic wrapper `InspectedClientModel<Model>` (Identifiable by a String, Inspectable through `Model.inspection`) and a protocol `InspectableClientModel` (`inspectorObjectID`, `static inspection: Inspection<InspectedClientModel<Self>>`) in place of the `@retroactive Inspectable` of SessionModel and the 10 entries; `InspectorView(model)` / `InspectorView(models)` convenience inits so a host still writes `InspectorView(entry)`. Formats: entry from the wire `<kind>-<raw wire id>` (kind = the inspection id: user-message, agent-message, thought, tool-call, terminal, plan, compaction, session-message), unidentified `position-<n>`, local `local-<UUID>`; session `<raw session id>`.
  timestamp: 2026-11-05T16:34:45.067899+00:00
- actor: claude-code
  id: 01m6pb6p80704cfty5exkqda34
  text: |-
    ### implement — changed
    - evidence: commit e848ce7e (not pushed). 14 files: new Sources/AgentViewKit/Inspection/InspectedClientModel.swift, Sources/AgentViewKit/Inspection/ClientInspectionID.swift, Tests/AgentViewKitTests/Inspection/InspectorObjectIDTests.swift, IntegrationTests/.../Inspection/ClientModelSchemeHostedTests.swift; changed ClientModels+Inspectable.swift, TranscriptEntries+Inspectable.swift, ConfigOptionFields.swift, ConfigOptionsView.swift, ClientModelInspectionHostedTests.swift, ConfigOptionsSessionModelHostedTests.swift, InspectorGallery.swift, InspectorGalleryFixtures.swift, ARCHITECTURE.md, Package.swift.
    - Formats (object part before EK escapes % / . +): session = raw session id (`inspection:session/object:sess_1/field:session.id`); entry from the wire = `<inspection id>-<raw wire id>` (`inspection:tool-call/object:tool-call-call_1/name`); entry with no wire id = `position-<n>`; local entry = `local-<UUID>`; config options = `inspection:config-options/object:sess_1/field:model.model`.
    - Tests: root `swift test` 1000+48 passed; full IntegrationTests 965 passed (5 known issues are the deliberate FontRoleExpectationsTests checks); only the allowed mlx warning.
    - Sibling origin mains (fetched): KVK 29fdc3f and SVK c9da66c match none of the prefixes; Testudo 6f97e57 matches only `inspection:inspectedattachment/object:` (TestudoUITestSupport/InspectorScreen.swift), stale since ^j5c8yfv, not from this change.
    - Upstream: nothing needed (every id has a public rawValue / UUID). EK b707d51a was not in this run (EK resolved at 73033d2).
    - next: /review
  timestamp: 2026-11-05T17:13:17.312019+00:00
position_column: done
position_ordinal: ffffffaf80
title: Inspector object ids of transcript entries and sessions are debug descriptions
---
Found while working ^j5c8yfv (AttachmentInspector scheme ids).

EK's `InspectorScheme.objectID(of:key:)` makes the object part of a row's scheme id from `String(describing: object.id)`. For the AVK `Inspectable` conformances of FoundationModelsACPClient models, that id is a type AVK does not own and that has no readable description:

- Each transcript entry (`ToolCallEntry`, `TerminalEntry`, `UserMessageEntry`, `AgentMessageEntry`, `ThoughtEntry`, `SessionMessageEntry`, `PlanTranscriptEntry`, `CompactionEntry`, `ErrorEntry`, `UnknownEntry`) has `id: TranscriptEntry.ID`, an enum (`.wire(SessionEntry.ID)` / `.local(UUID)`) with no `CustomStringConvertible`, so the object part is a debug description such as `wire(FoundationModelsACP.SessionEntry.ID.toolCall(...))`, escaped.
- `SessionModel.id` is FMACP `SessionId`, a `RawRepresentable` struct with no description, so it reads `SessionId(rawValue: "...")`, escaped. This also reaches `ConfigOptionsView`'s `inspection:config-options/object:<session>` ids.

AVK cannot change these: the `Identifiable` conformances live in FMACP/FMACPClient, and AttachmentInspector's fix (an AVK-owned wrapper object with a `String` id) does not apply to `InspectorView(entry)` of the model itself.

- [x] Decide where the fix goes: a readable `description` on `TranscriptEntry.ID` and `SessionId` in FMACP/FMACPClient, or an EK hook for the object id of an `Inspectable` (do not edit EK from AVK). Decided (user brief): inside AVK. EK has no object-id hook and every id has a public raw value, so `SessionModel` and each entry conform to AVK's `InspectableClientModel` and show through the AVK wrapper `InspectedClientModel`, whose id is a readable String. No upstream change is needed.
- [x] Once the ids are readable, add a hosted test in AVK that the shown row id of an entry inspector equals its documented format. (`ClientModelSchemeHostedTests`)