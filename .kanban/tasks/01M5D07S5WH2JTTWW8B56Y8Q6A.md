---
assignees:
- claude-code
depends_on:
- 01M5D07NRD75D8MPV6VDJVERBA
position_column: todo
position_ordinal: '8380'
title: AVK-7d EditorKit navigation and jump on messages, tool calls and request cards
---
Design: AVK-7, D105 (d). Step 5 work.

Each item scope (agentMessage, agentToolCall, agentRequest) becomes a target of the EditorKit navigation (FocusNavigator, the nav.* drill) and of the jump engine (`.jumpTarget`, EditorCommandsUI/JumpTargetModifier.swift:226). Follow the pattern of KanbanViewKit and SnapshotViewKit (their plan.md §6.3).

The content verbs of the kit stay: Next/Previous Prompt, Next/Previous Request, Scroll to Bottom.

Acceptance: hosted tests show that the nav chords move between two message items, and that the jump overlay lists the items of the thread. Tests follow the repo test rules: certain events, no clock, no sleep, no poll. #avk-7