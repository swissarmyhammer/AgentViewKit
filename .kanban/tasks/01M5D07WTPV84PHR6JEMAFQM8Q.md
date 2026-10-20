---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: AVK-7e Command groups that the host can turn off
---
Design: AVK-7, D105 (f). KanbanViewKit plan §3.4 has the same rule. Step 5 work.

Today `AgentCommand.definitions(for:)` (Commands/AgentCommands.swift:250) registers all 13 verbs.

Do:
- Define the groups of the `agent.*` verbs (for example: prompt and stop, requests, thread view, copy). Agree the group names with KanbanViewKit and SnapshotViewKit so the three kits use one shape.
- A host gives the groups that are off, for example through an environment value or a parameter of `agentCommandScope(session:)`. A verb in a group that is off is not registered, so it does not show in the menus, the context menus or the palette, and its keys do not resolve.

Acceptance: headless tests for one group off: its verbs are not in `definitions(at:)`, not in `contextMenuMirror`, and its chords resolve to nothing. #avk-7