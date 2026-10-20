---
assignees:
- claude-code
depends_on:
- 01M5D07HWW75H4K9ZNPBGHPRS8
position_column: todo
position_ordinal: '8280'
title: AVK-7c agentToolCall scope on each tool call card
---
Design: AVK-7, D105 (a), (c). Step 5 work.

Do:
- Add `AgentScopeKind.toolCall = "agentToolCall"` (Commands/AgentCommandPlacement.swift).
- Each tool call card (Items/ToolCallView.swift:101) gets the item scope `agentToolCall:<toolCallId>` under `agentThread:<sessionId>`, with `agentItemScope` and the EditorKit context menu. The id is the ACP `toolCallId`, not the row key, because a SnapshotViewKit checkpoint names its tool call by that id.
- The scope gives the tool call entry as its live subject (see the AVK-7b card).
- No agent verb shows in the tool call context menu yet. The menu shows the commands that a host or another kit registers there, for example "Roll Back to Before This" of SnapshotViewKit (SVK-3). The kind text is the contract; no kit links another kit.

Acceptance: a test registers a command with `requires: .enclosing(AgentScopeKind.toolCall)` and sees it in `contextMenuMirror` at the tool call path, and not at a message path. A hosted test finds the scope node of a mounted tool call card. #avk-7