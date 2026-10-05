---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m46yw1tn0xxa8xx9pgnevt4e
  text: |-
    Research done. Findings:
    - ToolCallView takes only a ToolCallRecord now. The kit ToolKind and ToolCallStatus go into ToolKindSymbol, ToolStatusSymbol, AgentTheme.StatusColors.color(for:), ToolCallView.accessibilityLabel and ThreadAccessibility. ActivityTimeline and ItemRow use ToolCallView(record:).
    - The ACP ToolCallStatus has no lost case. The kit .lost is the wire value "_lost", so the ACP value is .unknown("_lost"). ToolStatusSymbol must keep the lost symbol and the "Result lost" label for that value.
    - Registries.swift has no tool registry yet. Only the content block and attachment registries are there. A new KeyedViewRegistry keyed by the tool name is necessary.
    - The ToolCallEntry init is internal. Tests must make entries through ScriptedSession (tool_call_update frames).
    - ACP Diff has changes: [DiffChange] (add, delete, modify, move, copy, unknown) and an optional patch with a format. Today SessionUpdateMapping.toolContent makes a diff with no git_patch an unknown part.
    - SessionUpdateMapping.elicitationRequest(_:server:) changes a pending ACP elicitation into a kit ElicitationRequest for ElicitationView. ScriptedWireAgent.send(_:) can send an elicitation/create request to the client.
    - ExpandedBlocksStore.defaultExpanded takes a ThreadItem. A tool call entry has no ThreadItem, so an entry with no decision uses the collapsed state.
    Plan: ToolCallView gets init(entry:). Inside, a source enum (record or entry) gives the fields in ACP types, so the view does not use the kit kind or status. The row reads title, kind and status. The body reads the content. A registered view for the tool name replaces the default body, and the row keeps title as its label. DiffView gets init(diff:) for the ACP Diff: it uses the git_patch text when there is one, and otherwise the file list of the changes. Linked elicitations show under the row through ElicitationView.
  timestamp: 2026-10-05T21:17:45.685213+00:00
- actor: claude-code
  id: 01m46zz2qtntxqyvjygqwhjxd7
  text: |-
    Implementation landed (TDD: the new and changed tests failed to compile first, then passed).
    Design decisions to know:
    - ToolCallView keeps init(record:) and adds init(entry:). A new internal ToolCallSource (Items/ToolCallSource.swift) gives the fields of a record or an entry in the ACP kind and status types. The kit record converts through the new internal bridges ToolKind.acpKind and ToolCallStatus.acpStatus (Model/ToolCallRecord.swift). These bridges go away with the kit model (^K836Q, ^RKGV6F).
    - ToolKindSymbol, ToolStatusSymbol, AgentTheme.StatusColors.color(for:) and ToolCallView.accessibilityLabel(title:status:) now take the ACP types. The ACP status has no lost case: "_lost" is ToolStatusSymbol.lostWireValue, and .unknown("_lost") keeps the lost symbol, the "Result lost" label and the failed color. ActivityTimeline, ThreadMinimapView and ThreadAccessibility convert their kit records with the bridges.
    - The registry: ToolCallRegistry = KeyedViewRegistry<String, ToolCallEntry>, environment value toolCallRegistry, modifier toolCallView(named:_:). A registered view replaces the expanded BODY of the call. The row stays, with the title as its label. This is how one call can use the registered view and also show the title as its label.
    - DiffView(diff:) takes the ACP Diff. git_patch text shows as before. With no git_patch text, DiffSummary.files(of:) (Diff/DiffSummary+Changes.swift) gives one file row per structured change, with no counts, the label "<operation> <language> file", and a note (DiffView.noPatchIdentifier). DiffSummary.Operation has two new cases: copied(from:) and unknown(_:).
    - Linked elicitations show under the row of an entry (also while it is collapsed), one ElicitationCard each. ElicitationCard (Elicitation/ElicitationCard.swift) is the form-or-URL switch that PendingRequestsHost had; the host now uses it too. The server name is "The agent", because SessionModel does not know the agent name. The reply wiring stays with ^q580.
    - An entry with no expand decision is collapsed: ExpandedBlocksStore.defaultExpanded reads a ThreadItem, and an entry has none.
    - The record path still makes a structured diff with no git_patch an unknown part (SessionUpdateMapping.toolContent). That path goes away with ^h1116ab.
    - The toolCallConnectionState chip applies only to records, because the provider takes a ToolCallRecord.
  timestamp: 2026-10-05T21:36:53.498638+00:00
- actor: claude-code
  id: 01m46zz6wv236241kabnmr40jr
  text: |-
    ### implement — changed
    - evidence: swift test: 1308 tests in 115 suites passed, 77 tests in 12 suites passed, exit 0; no new warning (only the expected deprecation and mlx-swift "missing creator" warnings). Focused run: 143 tests in 13 suites passed. README, snippets and demo not changed, so check-readme and test-examples were not run.
    - files: Sources/AgentViewKit/Items/ToolCallView.swift, Items/ToolCallSource.swift (new), Items/ToolKindSymbol.swift, Model/ToolCallRecord.swift, Theme/AgentTheme.swift, Thread/Registries.swift, Thread/ItemRow.swift, Diff/DiffView.swift, Diff/DiffSummary.swift, Diff/DiffSummary+Changes.swift (new), Elicitation/ElicitationCard.swift (new), HumanInTheLoop/PendingRequestsHost.swift, Activity/ActivityTimeline.swift, Thread/ThreadMinimapView.swift, Accessibility/ThreadAccessibility.swift; Tests: Items/ToolCallEntryViewHostedTests.swift (new), Items/ToolKindSymbolTests.swift, Theme/StatusColorsTests.swift, Thread/RegistryResolutionTests.swift, Thread/SessionTranscriptViewHostedTests.swift, Diff/DiffSummaryTests.swift, Diff/DiffViewHostedTests.swift, Accessibility/ThreadAccessibilityTests.swift
    - next: /review
  timestamp: 2026-10-05T21:36:57.755116+00:00
- actor: claude-code
  id: 01m470jzf918ch6mcztqyew1a2
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (31e9d9b): 0 findings, 0 confirmed, 0 refuted; 21 validator passes attempted, 0 failed; 23 files reviewed, 4 .kanban files not reviewed because of .reviewignore.
    - next: none. The task is in done.
  timestamp: 2026-10-05T21:47:45.513838+00:00
- actor: claude-code
  id: 01m470k0pvzrzc0hs4xxdqbf58
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — ToolCallView(entry:), ToolCallSource, ACP kind and status symbols, toolCallView(named:), structured diffs, ElicitationCard for linked elicitations
    - test: green — swift test, 1308 passed
    - commit: 31e9d9b
    - review: clean — 0 findings
  timestamp: 2026-10-05T21:47:46.779232+00:00
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
position_column: done
position_ordinal: e880
title: 'Bind the tool call and diff views to ToolCallEntry: name for the registry, title as label, structured diffs, linked elicitation'
---
## What
Source: update.md §4.7 ("Tool call view"), §5 (`ToolCallUpdate.name`), §9.4 (structured diffs).

- [x] Bind `ToolCallView` (`Sources/AgentViewKit/Items/ToolCallView.swift`) to `ToolCallEntry`. Use the ACP tool kind and status types; remove the use of the kit `ToolKind` and `ToolCallStatus` in this view. `ToolKindSymbol.swift` maps the ACP kind.
- [x] Select the tool view in the registry (`Thread/Registries.swift`) by `name` (the program name of the tool). Show `title` as the label. With no `name`, use the default view.
- [x] Show `Diff.changes` (structured diff content) in `DiffView` (`Sources/AgentViewKit/Diff/DiffView.swift`) when there is no `git_patch`. Today these show as unknown.
- [x] Show the session elicitations linked to a tool call in its row. Read them with `ToolCallEntry.linkedElicitationIDs` and look each one up in `SessionModel.pendingElicitations`.

## Acceptance Criteria
- [x] A tool call with `name` "read_file" uses the view registered for "read_file", and shows `title` as its label.
- [x] A tool call with a structured diff shows the diff, not the unknown view.
- [x] A pending elicitation whose ID is in `linkedElicitationIDs` of a tool call shows in that row.

## Tests
- [x] `Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift`: registry selection by `name`; label from `title`; structured diff; linked elicitation. Feed the session with the test helper of the transcript task.
- [x] `RegistryResolutionTests` covers the `name` key.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.