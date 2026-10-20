---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5d0a0j6203msfd406r387md
  text: |-
    Shape from D105 (f) (TestudoApp 4d75aa8):
    - A public type `AgentCommandGroup`. Each verb is in exactly one group.
    - A group id has the kit prefix, for example `agent.navigate`.
    - The host gives the groups to turn off when the kit registers its commands.
    - A group with the same job in two kits has the same last word, for example `navigate` for the content verbs and `clipboard` for Copy.

    Planned split of the 13 verbs:
    - `agent.compose`: Send Message, Focus Composer.
    - `agent.control`: Stop, Approve Request, Reject Request.
    - `agent.navigate`: Next and Previous Prompt, Next and Previous Request, Scroll to Bottom, Expand or Collapse All.
    - `agent.clipboard`: Copy Message, Copy Thread.
    Check this split again when the card starts.
  timestamp: 2026-10-20T15:54:00.134359+00:00
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