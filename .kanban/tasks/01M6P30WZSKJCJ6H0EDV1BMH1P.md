---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6pef6zzp1828tt2vr7577ba
  text: 'Unblocked: EK b4f6d9e5 (^ndc5zww) is on origin, carrying EditorButton / EditorToolbarButton / command-id forms / .labelStyle(.editorAdaptive) / \.editorStyle.buttons. Picked up; worktree merged AVK main c905c28e.'
  timestamp: 2026-11-05T18:10:22.335313+00:00
- actor: claude-code
  id: 01m6pf4xrs2kaqt0n97bpp3hmt
  text: 'Research: all three packages resolve EK at 81415956 (contains b4f6d9e5). ~45 raw Button sites. Per EK style.md "What stays a raw Button": rows/chips whose content is the button (ActivityTimeline row, ToolCallView row, ElicitationTabChip, InlineCitation pill, LinkView card, SessionJumpList rows, elicitation radio rows), menu items (AgentRowList/HostPathContextMenu context menus, SessionBreadcrumb dropdown choices) stay raw. Origin mains: KVK uses StatusBarActionStyle/StatusBarActionConfiguration/statusBarActionStyle (BoardCommandBarActionStyle); SVK uses GlassStatusBarActionStyle (TimelineStatusBarActionStyle); Testudo uses none. So those public types stay; RequestAction/RequestActionStyle/requestActionStyle/requestActionPlace are internal and go. Command-id form fits AttachmentActions (always dispatches through the attachment scope); MessageActions copyThread runs the command when a command target exists. TerminalView''s .controlSize(.mini) is on a ProgressView, not a button, so no density gap is needed.'
  timestamp: 2026-11-05T18:22:13.785275+00:00
position_column: doing
position_ordinal: 9a80
title: Move AVK's buttons onto EditorKit's EditorButton / EditorToolbarButton (no clipped captions)
---
**Blocked** on EK's themed button components (editorkit-b5, 2026-11-05); EK sends the SHA. New rule from the user for every kit:
- A button with too little room hides its caption and keeps its icon.
- A caption cut off, with or without "…", is never acceptable.
- Every kit uses EK's themed button components.

**EK is building:**
- `EditorButton`;
- `EditorToolbarButton`;
- a command-id form that draws its title, symbol, enabled state and shortcut from the registry;
- an adaptive label style: the caption collapses to the icon when squeezed, and the name stays as the accessibility label and tooltip.
Theme comes only through `\.editorStyle`. Call sites add no `.tint`, `.font` or `.buttonStyle`.

## What
- `swift package update` with all dependencies together.
- Move every raw `Button` and toolbar button in AVK (about 27 files) onto these components. Use the command-id form wherever a button runs a registered command.
- Delete AVK's own button styling: `.requestActionStyle`, `.buttonStyle(.borderless)`, `.tint` and `.font` on buttons, and any AVK button-style types, once nothing uses them. Before removing anything public, grep the KVK, SVK and Testudo origin mains, and leave in place whatever they still use (no shims).
- Don't build an AVK version of any of this.

## Tests
- [ ] A hosted test per button family that at a squeezed width the caption is hidden (icon only), never cut off, while the accessibility label and tooltip keep the name. Drive it through accessibility, never the mouse, and don't steal focus.
- [ ] Gallery captures at narrow (about 240 pt) and wide widths, light and dark, showing icon-only collapse.
- [ ] Full AVK suite green.