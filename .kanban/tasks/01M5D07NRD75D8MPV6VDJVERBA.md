---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5da9m2xhty3e3s5sb0dx3rk
  text: |-
    Research:
    - `ToolCallEntry` is a `@MainActor` class, so it is `Sendable` and can be the subject of `agentItemScope(_:subject:)`.
    - The row key of a tool call is `tool-call-<toolCallId>`. The segment id must be `entry.toolCallId.rawValue`, not the row key.
    - `AgentCommandVerb.isVisible(at:)` uses `AgentScopeKind.item(in:)`, which reads only the kinds in `AgentScopeKind.items`. If `toolCall` is not in `items`, Next Prompt and Previous Prompt (item kind `message`) show in the tool call context menu. Thus `toolCall` must go into `items`, so that no agent verb shows there.
    - `ToolCallView` is used by `ItemRow` (through `OverridableItemView`) and by `ActivityTimeline`. The scope goes on `ToolCallView.body`, as the card says. Outside an agent command scope, `AgentItemScope` does not change the view.
    - Test helpers: `AlwaysAvailableCommand` (EditorCommandsTestSupport) for a host command; `ScriptedSession.sendToolCallUpdate(title:status:)` and `BackgroundRunsHostedTests.toolCall(id:in:)` for a hosted tool call.
  timestamp: 2026-10-20T18:48:33.117358+00:00
- actor: claude-code
  id: 01m5dakeh29zxxg3t0rw7f9j96
  text: |-
    Implementation landed:
    - `AgentScopeKind.toolCall = "agentToolCall"` (public) and the internal factory `AgentScopeKind.toolCall(_ id: ToolCallId) -> FocusSegment`. The segment id is `toolCallId.rawValue`, not the row key (`tool-call-<id>`). `AgentCommandPlacement.swift` now imports `FoundationModelsACP` for `ToolCallId`.
    - `toolCall` is in `AgentScopeKind.items`. Without it, `isVisible(at:)` found no item segment at a tool call path, so Next Prompt and Previous Prompt showed in the tool call context menu. The RED run showed this failure.
    - `ToolCallView.body` ends with `.agentItemScope(AgentScopeKind.toolCall(entry.toolCallId), subject: entry)`. The subject is the live `ToolCallEntry`. Outside an agent command scope the view does not change, so the existing ToolCallView tests still pass.
    - Docs: the `AgentScopeKind` subject table, `isVisible(at:)`, `item(in:)`, `ToolCallView` and `AgentItemScope` tell about the tool call scope.
    - Tests: `AgentCommandPlacementTests.aHostCommandOfTheToolCallScopeShowsOnlyInTheContextMenuOfAToolCall` (headless: a host command with `requires: .enclosing(AgentScopeKind.toolCall)` is the only item of `contextMenuMirror` at the tool call path, and is not at a message path). `AgentScopeSubjectHostedTests.aMountedToolCallCardAddsTheScopeNodeOfItsToolCallID` (hosted: the node `agentThread:<id>/agentToolCall:<toolCallId>` is in the registry tree). `AgentScopeSubjectHostedTests.aHostCommandReadsTheToolCallEntryOfAToolCallScopeThroughFromTarget` (hosted: `@FromTarget` gives the same `ToolCallEntry` object).
    - Note: `CommandSystemHarness.registry` has a private setter. The headless test copies the registry value and registers the host command on the copy.
  timestamp: 2026-10-20T18:53:55.106509+00:00
- actor: claude-code
  id: 01m5dakhg2yje6y6cnegcggfdz
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Commands/{AgentCommandPlacement,AgentItemScope}.swift, Sources/AgentViewKit/Items/ToolCallView.swift, Tests/AgentViewKitTests/Commands/{AgentCommandPlacementTests,AgentScopeSubjectHostedTests}.swift. RED: the 3 new tests failed (context menu had the jump verbs; no tool call node; probe not available). GREEN: `swift test` — 1351 tests in 158 suites passed, 2 known issues that were there before, 130 package structure tests passed. 1 build warning only: the mlx bundle warning that was there before.
    - next: /review
  timestamp: 2026-10-20T18:53:58.146803+00:00
- actor: claude-code
  id: 01m5daqcjpydsv40getfj8q41h
  text: |-
    ### test - green
    - evidence: swift test - 1351 tests in 158 suites passed, 0 failed, 0 skipped. 2 known issues (existed before). 1 warning: mlx bundle build warning (existed before). No new warnings.
    - next: review
  timestamp: 2026-10-20T18:56:04.182094+00:00
- actor: claude-code
  id: 01m5dasye1fpkdvz0r5pbm29tb
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 7c21716). 0 findings, 0 confirmed, 1 refuted. 5 files reviewed. 4 .kanban files not reviewed (ignore rule).
    - next: The task is in done. No more work is necessary.
  timestamp: 2026-10-20T18:57:28.001745+00:00
- actor: claude-code
  id: 01m5dat7wqd1fq4kmb0j977akg
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 5 files
    - test: green — swift test, 1351 passed, 2 known issues that were there before
    - commit: 7c21716
    - review: clean — 0 findings
  timestamp: 2026-10-20T18:57:37.687043+00:00
depends_on:
- 01M5D07HWW75H4K9ZNPBGHPRS8
position_column: done
position_ordinal: fff380
title: AVK-7c agentToolCall scope on each tool call card
---
Design: AVK-7, D105 (a), (c). Step 5 work.

Do:
- Add `AgentScopeKind.toolCall = "agentToolCall"` (Commands/AgentCommandPlacement.swift).
- Each tool call card (Items/ToolCallView.swift:101) gets the item scope `agentToolCall:<toolCallId>` under `agentThread:<sessionId>`, with `agentItemScope` and the EditorKit context menu. The id is the ACP `toolCallId`, not the row key, because a SnapshotViewKit checkpoint names its tool call by that id.
- The scope gives the tool call entry as its live subject (see the AVK-7b card).
- No agent verb shows in the tool call context menu yet. The menu shows the commands that a host or another kit registers there, for example "Roll Back to Before This" of SnapshotViewKit (SVK-3). The kind text is the contract; no kit links another kit.

Acceptance: a test registers a command with `requires: .enclosing(AgentScopeKind.toolCall)` and sees it in `contextMenuMirror` at the tool call path, and not at a message path. A hosted test finds the scope node of a mounted tool call card. #avk-7