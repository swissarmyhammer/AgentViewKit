---
assignees:
- claude-code
position_column: todo
position_ordinal: a380
title: Decide whether AgentItemFocusTarget is still needed after EditorKit c64ca1b
---
Found while working ^brhhdf4. EditorKit c64ca1b ("a landed jump focuses the targeted scope") makes the scope beacon take first responder when a scope has no focusable content of its own, and skips focusables owned by nested scopes. AgentViewKit's `AgentItemFocusTarget` (Sources/AgentViewKit/Commands/AgentItemFocusTarget.swift) exists because `GeometryRegistry.requestFocus(at:)` used to give first responder to the focusable view at the scope center, and a message row has none. 

- [ ] Check whether EditorKit's beacon now covers both `nav.*` moves (`requestFocus(at:)`) and jumps for message rows, tool call cards and request cards.
- [ ] If it does, remove `AgentItemFocusTarget`/`AgentItemFocusView` and the `.background(AgentItemFocusTarget())` in `AgentItemScope`, keeping `AgentNavigationHostedTests` green (the focus ring behavior must still be correct).
- [ ] If it does not, record why on this card and close it.

#avk-7