---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m49rqp3ygz3g3tb7t19f3kje
  text: |-
    Research (implement):
    - `ToolCallSource` maps the entry `rawInput`, `rawOutput`, content and unknown parts to kit values with `SessionUpdateMapping`. `ToolCallView.command(from:)` and `exitCode(from:)` read the kit `JSONValue`.
    - `UnknownItemView` already has a private pretty-print function for an ACP `JSONValue` (with `assertionFailure` and a log for a value that does not encode). Plan: move it to one shared internal extension on `FoundationModelsACP.JSONValue`, and use it in `ErrorView`, `UnknownItemView`, `TaskListView` and `ToolCallView`.
    - The record path already uses ACP bridges (`ToolKind.acpKind`, `ToolCallStatus.acpStatus`). Plan: the views read only ACP values; the record path (old `AgentThreadView(thread:actions:)`) bridges its kit `JSONValue` and kit `PlanEntry` to the ACP values with new internal `acpValue` and `acpEntry` properties. These bridges go away with the record types.
    - Tool call content blocks use `BlockSource<ContentBlock, FoundationModelsACP.ContentBlock>` and `ContentBlockView`.
    - `AgentTheme.StatusColors.color(for:)` for plan status and priority, and `TaskListView.statusLabel` / `priorityLabel` / `headerText(for entries:)` change to the ACP plan types.
    - Not in this task: `ToolCallSource.locations` makes a kit `ToolCallLocation` from the entry. A new task records it.
  timestamp: 2026-10-06T23:28:14.462700+00:00
- actor: claude-code
  id: 01m49scw2k0cf55f65nf6y3acx
  text: |-
    Implementation landed (not committed).
    - RED: the new source test `SessionEntryRowsHostedTests.theEntryValueViewsMakeNoKitCopyOfTheEntryValues` failed with 8 `SessionUpdateMapping` lines in `ToolCallSource`, `ErrorView`, `UnknownItemView` and `TaskListView`. The new behavior tests (raw input, text part, raw output, a later raw output update, a plan status change, the unknown raw JSON as indented text) passed before the change, because the old conversions kept the behavior. They are guards for the refactor.
    - GREEN: `ToolCallSource` gives `rawInput`, `rawOutput` and the unknown part as `FoundationModelsACP.JSONValue`, and a content block as `BlockSource<ContentBlock, FoundationModelsACP.ContentBlock>` (new internal `ContentBlockView(source:id:)`). `ToolCallView.command(from:)` and `exitCode(from:)` read the ACP value. The new internal `FoundationModelsACP.JSONValue.prettyPrinted` (`Sources/AgentViewKit/Items/ACPJSONText.swift`, moved from `UnknownItemView`, with `assertionFailure` and a log) gives the JSON text to `ErrorView`, `UnknownItemView`, `TaskListView` and `ToolCallView`. `TaskListView` shows the ACP `PlanEntry` values of the entry directly.
    - Record path (old `AgentThreadView(thread:actions:)`): it gives its values to the same ACP views through two new internal bridges, `JSONValue.acpValue` and `PlanEntry.acpEntry`, as `acpKind` and `acpStatus` already do. These bridges go away with the record types.
    - Public API change: `TaskListView.statusLabel`, `priorityLabel`, `headerText(for entries:)` and `AgentTheme.StatusColors.color(for:)` for a plan status and a priority now take the ACP plan types. A new public `TaskListView.entryLabel(_:)` takes an ACP `PlanEntry`, and the kit form calls it. Tests changed to follow: `StatusColorsTests`, `ToolKindSymbolTests`, `TaskListViewHostedTests`.
    - `SessionUpdateMapping.wireJSON` stays. It does the same work as `acpValue` with a Codable round trip. The adapter removal deletes it.
    - Follow-up task ^prmkd94: `ToolCallSource.locations` still makes a kit `ToolCallLocation` from the entry.
    - `swift test`: 1356 + 77 + 1 tests passed, 0 failures. One warning, the expected `missing creator for mutated node`. `SessionEntryRowsHostedTests.anAppendedErrorShowsItsData` passed in this run.
  timestamp: 2026-10-06T23:39:48.691619+00:00
- actor: claude-code
  id: 01m49sczke511gqfp7mfspds84
  text: |-
    ### implement — changed
    - evidence: 16 files. New: Sources/AgentViewKit/Items/ACPJSONText.swift, Tests/AgentViewKitTests/Model/ACPValueBridgeTests.swift. Changed: Sources/AgentViewKit/Items/{ToolCallSource,ToolCallView,ErrorView,UnknownItemView}.swift, Sources/AgentViewKit/Status/TaskListView.swift, Sources/AgentViewKit/Content/ContentBlockView.swift, Sources/AgentViewKit/Model/{JSONValue,Plan}.swift, Sources/AgentViewKit/Theme/AgentTheme.swift, Tests/AgentViewKitTests/Helpers/SourceLines.swift, Tests/AgentViewKitTests/Items/{SessionEntryRowsHostedTests,ToolCallEntryViewHostedTests,ToolKindSymbolTests}.swift, Tests/AgentViewKitTests/Status/TaskListViewHostedTests.swift, Tests/AgentViewKitTests/Theme/StatusColorsTests.swift. `swift test` green (1356 + 77 + 1, 0 failures); `swift test --filter ACPValueBridgeTests` green (4); `rg SessionUpdateMapping Sources/AgentViewKit/Items Sources/AgentViewKit/Status` finds nothing.
    - next: /review
  timestamp: 2026-10-06T23:39:52.302728+00:00
depends_on:
- 01M48MQS1Q5HBNDFMBD2CT0C6C
- 01M443NW9A12NWXYHJFYTTTA85
- 01M443P38JZMBRSCEPWCS25T9A
position_column: doing
position_ordinal: '80'
title: Show tool call, error, unknown and plan entries from the ACP values of the entry, with no SessionUpdateMapping conversion
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The kit keeps no copy of model data. At present the entry views of the session path convert the model values to kit copies with the adapter:

- `Sources/AgentViewKit/Items/ToolCallSource.swift`: `rawInput` and `rawOutput` go through `SessionUpdateMapping.json` (kit `JSONValue`); a content part goes through `SessionUpdateMapping.contentBlock` (kit `ContentBlock`); an unknown part goes through `SessionUpdateMapping.json`.
- `Sources/AgentViewKit/Items/ErrorView.swift`: `ErrorEntry.data` goes through `SessionUpdateMapping.json`.
- `Sources/AgentViewKit/Items/UnknownItemView.swift`: `UnknownEntry.raw` goes through `SessionUpdateMapping.json`.
- `Sources/AgentViewKit/Status/TaskListView.swift`: `PlanTranscriptEntry.entries` go through `SessionUpdateMapping.planEntry` (kit `PlanEntry`), and the unknown plan content goes through `SessionUpdateMapping.json`.

The removal of the ACP adapter deletes `SessionUpdateMapping`, so this task must be done first.

- [x] `ToolCallSource` (entry case) reads `ToolCallEntry.rawInput`, `rawOutput` and `content` as ACP values (`FoundationModelsACP.JSONValue`, `ToolCallContent`). A content part shows with the ACP content block entry point of the content views.
- [x] `ErrorView` and `UnknownItemView` show `ErrorEntry.data` and `UnknownEntry.raw` as ACP `JSONValue` (pretty-printed by a pure function on the ACP value).
- [x] `TaskListView` shows `PlanTranscriptEntry.entries` as ACP `PlanEntry` values directly, and `unknownContent.payload` as ACP `JSONValue`.
- [x] No file of this task calls a `SessionUpdateMapping` function or makes a kit `JSONValue`, `ContentBlock` or `PlanEntry` from an entry.

## Acceptance Criteria
- [x] A `tool_call_update` that changes `rawOutput` shows the new output in the open tool call body with no other step.
- [x] A plan update that changes the status of one plan entry shows the new status in its row.
- [x] An error entry with `data` and an unknown entry show their JSON as the model holds it.
- [x] `rg "SessionUpdateMapping" Sources/AgentViewKit/Items Sources/AgentViewKit/Status` finds nothing.

## Tests
- [x] `Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift`: raw input, raw output and a text content part from the scripted agent show; a later update changes the shown output.
- [x] `Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift`: a plan update changes one row status; an error entry shows its `data`; an unknown entry shows its raw JSON.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.