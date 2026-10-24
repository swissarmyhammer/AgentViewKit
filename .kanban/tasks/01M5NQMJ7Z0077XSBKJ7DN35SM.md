---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5pk121sw4dczqg284k0x1jf
  text: 'From kanbanviewkit-84 (2026-10-24): EditorStyle is on EditorKit main. ^4js4t70 is at 369719f, and ^1kgh67a at 2a3db5e adds `.inlineEdge` and the opt-in `.inlineFill`. This card can start now. Use EditorKit 2a3db5e or later.'
  timestamp: 2026-10-24T09:14:19.577897+00:00
position_column: todo
position_ordinal: 9f80
title: Use the EditorStyle target of EditorKit for radius, tokens, concentric shape and floating glass (after EditorKit ^4js4t70)
---
From kanbanviewkit-84 (2026-10-23), a style rule of the user that AgentViewKit and KanbanViewKit share: "Radius is theme-driven. EditorKit card ^4js4t70 adds a shared `EditorStyle` target (radius scale, tokens, concentric surface shape, FloatingGlassContainer and floating-glass modifier, status/priority symbols). When it lands, AgentViewKit should take these from EditorKit instead of its own Theme/ copies, and use no literal corner radius."

Do not start this card before the EditorKit card ^4js4t70 is done and its commit is on EditorKit main. When you start, record the EditorKit commit in a comment.

To do:
- Update the EditorKit pin and add the `EditorStyle` product to the AgentViewKit target.
- Remove the kit copies that `EditorStyle` replaces: the radii of `AgentTheme`, `FloatingGlassContainer`, `FloatingGlassID`, `agentFloatingGlass(id:)`, the concentric card shape of `agentContentEdge(radius:)`, and the status symbols. Use the `EditorStyle` types at each call site. Do not keep an alias (ARCHITECTURE.md: no backward compatibility).
- Use no literal corner radius in Sources/. Each radius comes from the radius scale of the theme.
- Update the structure tests that name the removed files or forms (`GlassPlacementTests`, `ComposerGlassStructureTests`, `ContentFillTests`), and the plan.md text ("Tokens, not hard-coded values", "Glass only on floating controls", "Morphs").

Acceptance:
- A structure test finds no literal corner radius in Sources/AgentViewKit.
- `swift test` is green, and the demo builds.
- The snapshots are re-recorded only where the look changes, listed by name with their PNG paths. #avk-8