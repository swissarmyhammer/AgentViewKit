---
assignees:
- claude-code
position_column: todo
position_ordinal: '8e80'
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