---
assignees:
- claude-code
depends_on:
- 01M48MQS1Q5HBNDFMBD2CT0C6C
- 01M443NW9A12NWXYHJFYTTTA85
- 01M443P38JZMBRSCEPWCS25T9A
position_column: todo
position_ordinal: ab80
title: Show tool call, error, unknown and plan entries from the ACP values of the entry, with no SessionUpdateMapping conversion
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The kit keeps no copy of model data. At present the entry views of the session path convert the model values to kit copies with the adapter:

- `Sources/AgentViewKit/Items/ToolCallSource.swift`: `rawInput` and `rawOutput` go through `SessionUpdateMapping.json` (kit `JSONValue`); a content part goes through `SessionUpdateMapping.contentBlock` (kit `ContentBlock`); an unknown part goes through `SessionUpdateMapping.json`.
- `Sources/AgentViewKit/Items/ErrorView.swift`: `ErrorEntry.data` goes through `SessionUpdateMapping.json`.
- `Sources/AgentViewKit/Items/UnknownItemView.swift`: `UnknownEntry.raw` goes through `SessionUpdateMapping.json`.
- `Sources/AgentViewKit/Status/TaskListView.swift`: `PlanTranscriptEntry.entries` go through `SessionUpdateMapping.planEntry` (kit `PlanEntry`), and the unknown plan content goes through `SessionUpdateMapping.json`.

The removal of the ACP adapter deletes `SessionUpdateMapping`, so this task must be done first.

- [ ] `ToolCallSource` (entry case) reads `ToolCallEntry.rawInput`, `rawOutput` and `content` as ACP values (`FoundationModelsACP.JSONValue`, `ToolCallContent`). A content part shows with the ACP content block entry point of the content views.
- [ ] `ErrorView` and `UnknownItemView` show `ErrorEntry.data` and `UnknownEntry.raw` as ACP `JSONValue` (pretty-printed by a pure function on the ACP value).
- [ ] `TaskListView` shows `PlanTranscriptEntry.entries` as ACP `PlanEntry` values directly, and `unknownContent.payload` as ACP `JSONValue`.
- [ ] No file of this task calls a `SessionUpdateMapping` function or makes a kit `JSONValue`, `ContentBlock` or `PlanEntry` from an entry.

## Acceptance Criteria
- [ ] A `tool_call_update` that changes `rawOutput` shows the new output in the open tool call body with no other step.
- [ ] A plan update that changes the status of one plan entry shows the new status in its row.
- [ ] An error entry with `data` and an unknown entry show their JSON as the model holds it.
- [ ] `rg "SessionUpdateMapping" Sources/AgentViewKit/Items Sources/AgentViewKit/Status` finds nothing.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift`: raw input, raw output and a text content part from the scripted agent show; a later update changes the shown output.
- [ ] `Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift`: a plan update changes one row status; an error entry shows its `data`; an unknown entry shows its raw JSON.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.