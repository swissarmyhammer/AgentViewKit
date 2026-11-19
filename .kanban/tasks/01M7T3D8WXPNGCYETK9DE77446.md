---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: Search hits use SessionModel.entry(forWireID:) of ACPClient (D207 f)
---
Follow-up of ^yxxnx1f. FoundationModelsACPClient D207 is on main: 12989da, 4be1081, e8b91e4 (kanban 6159db6), from foundationmodelsacpclient-1d.

Now: AVK finds the entry of a search hit with the wire identity of `TranscriptEntry` (`.wire(SessionEntry.ID)`) in `SessionModel.transcript` (Sources/AgentViewKit/Thread/TranscriptSearch*.swift).

New in ACPClient:
- `SessionModel.entry(forWireID: SessionEntry.ID) -> TranscriptEntry?`: nil for an unknown id, an id that a rollback removed, or an echo that the model holds until its prompt answer. Use `TranscriptEntry.ID.rowKey` of the result to reveal the row.
- `SessionModel.wireEntries: [SessionEntry]` (engine order).
- Behavior change: `markdown(options:)` now renders engine order (the order of the agent), not transcript order. A prompt echo that comes after an agent message is now after it in the export. Check the AVK Export as Markdown tests (ExportMarkdownCommandTests) after the pin update.

Do:
- Update the FoundationModelsACPClient pin to e8b91e4 or newer (root, IntegrationTests, ScreenshotTests).
- Find the entry of a hit with `entry(forWireID:)`, and reveal the row with `rowKey`. Remove the AVK lookup code it replaces.
- Fix any Export as Markdown test that expected transcript order, and say why.
- Unit tests: a hit for an id that a rollback removed, and for a held echo, is skipped.

Run `swift test`. Push, and send the sha to testudoapp-9a.