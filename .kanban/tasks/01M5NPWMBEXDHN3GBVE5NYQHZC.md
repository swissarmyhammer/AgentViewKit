---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: 'Copy Message: a main-menu placement in the Edit menu, next to Copy (D41)'
---
The user's decision, relayed by testudoapp-2c on 2026-10-23: "Copy Message goes in the Edit menu." D41 stands: the same commands on all three surfaces (context menu, palette or keymap, and main menu).

Today `.copyMessage` has no main-menu placement, so `AgentCommandVerb.menu` is nil for it. Testudo's new CommandSurfacesTests (^jqpbx0h) fails on exactly this.

## What to do
- [ ] Give `.copyMessage` a main-menu placement in the Edit menu, placed next to Copy, so `AgentCommandVerb.menu` is non-nil.
- [ ] Key equivalent: your call, but NOT plain ⌘C. Check it doesn't collide with existing kit or EditorKit chords (e.g. ⌘⇧C, ⌥⌘C). Write down the choice.
- [ ] Availability: the menu item is enabled only when a message is the focused or selected target, the same rule as the context-menu item. It runs the same command.
- [ ] Hosted tests (red first): `AgentCommandVerb.copyMessage.menu` is non-nil and placed in Edit next to Copy; the menu item runs Copy Message at the focused message; it's disabled with no message focused; the key equivalent fires it and doesn't shadow ⌘C.
- [ ] Check every other AgentCommandVerb for the same gap (D41: all three surfaces). List any other verb without a menu placement, and fix it the same way or file it.

When it's done, send testudoapp-2c the SHA (their ^jqpbx0h depends on it). Full `swift test` green. #avk-8 #testudo-request