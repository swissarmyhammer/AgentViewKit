---
assignees:
- claude-code
position_column: todo
position_ordinal: '8e80'
title: Read context menus headlessly with EditorKit's contextMenuItems(of:)
---
EK ^arcymge (on EK origin at de292643): `harness.contextMenuItems(of: "id") -> [ContextMenuItemSnapshot]` returns title, isEnabled, commandID? and isSeparator for a `.commandContextMenu`. It needs no NSMenu, mouse event or activation, and the window can stay off-screen and not key. It finds exactly one element and throws `noElement` or `noCommandContextMenu` otherwise. For a plain SwiftUI `.contextMenu`, `contextMenu(identifier:)` still reads headlessly, but with no command ids.

## What
- Move ThreadHeaderContextMenuHostedTests (4 tests) and AgentRowListRowMenuHostedTests (6 runs) off opening the menu at a point. Use `contextMenuItems(of:)`, or `contextMenu(identifier:)` for plain `.contextMenu`. Where a test needs command ids, move the view to `.commandContextMenu`.
- Do it together with the `perform(_:on:)` migration card, since they touch the same test style.

## Tests
- [ ] No hosted test opens a context menu at a point or needs a focused window for it.
- [ ] The full AVK suite is green.