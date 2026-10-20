---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dfe2tc1fbyjgnmxyrp0jhx
  text: |-
    ### decision (testudoapp-4c, AVK-8 "Decisions for the plan")
    - §5 must name a manual check: a person checks the real system Tinted setting one time for each release.
    - §5 must name these rules: Stop is `.glassProminent` while the agent runs, and Send is `.glassProminent` when the agent is idle. Status banners, errors, compaction entries and the sign-in view are content, so they use materials and not glass. The composer slot is on `AgentThreadView`. Corners use `ConcentricRectangle` and `.concentric`.
  timestamp: 2026-10-20T20:18:22.156567+00:00
depends_on:
- 01M5DFADQHSHCRAQW0709TVAPV
- 01M5DF7Y8PDWS7XF25WDBBYG9W
position_column: todo
position_ordinal: '9880'
title: AVK-8q Change plan.md §5 to name the Liquid Glass rules of D110
---
## Why

AVK-8 tells us to change plan.md §5 to name the rules. Today §5 says that the picker, the toolbars and the inspector use `GlassEffectContainer` and `.glassEffect`, and that `.glassEffectID` morphs the composer into a tool tray. D110 says that bars, the sidebar and the inspector are system glass with no custom code, and the kit has no morph.

## Files

- `/Users/wballard/github/swissarmyhammer/AgentViewKit/plan.md` §5, lines 234-244. The glass paragraph is line 238. The token paragraph is line 244.
- `/Users/wballard/github/swissarmyhammer/AgentViewKit/Docs/decisions/visual-audit.md` line 30 (`materialLevel` row): check that it agrees.
- Do not change §6 line 252 (Reduce Motion), except to add a reference to the tests of AVK-8p.

## What to do

Rewrite the glass paragraph of §5 in STE. Name these rules and cite D110 and `TestudoApp/features/research-liquid-glass.md`:

- [ ] **No glass in content.** The transcript, the messages, the tool call cards, the thoughts, the plan, the terminal, the diff, the code blocks, the request cards, the notices and the state banners use `agentContentSurface()`: a standard background in a concentric shape.
- [ ] **Glass only on floating controls.** The composer field, its accessory cluster, the suggestions, the completion list and the scroll-to-bottom pill use `agentFloatingGlass()` in one `GlassEffectContainer` (the method of AVK-8l). Never glass on glass.
- [ ] **Button styles first.** `.glass` and `.glassProminent` before custom glass. Send is the one `.glassProminent` action of the composer. The action buttons of a request card can use the glass button styles.
- [ ] **System chrome.** Toolbars, the sidebar, the inspector, sheets, popovers and menus are system glass. The kit adds no background to them.
- [ ] **Shapes and color.** Concentric corners, vibrant foreground styles, and each color from `\.editorTheme`.
- [ ] **Accessibility.** Each glass view has a test with Reduce Transparency, Increase Contrast and the Tinted look (AVK-8p).
- [ ] **Guards.** Name `GlassPlacementTests` and `ThemeColorTests` (AVK-8n, AVK-8o).
- [ ] Remove the `.glassEffectID` tool tray sentence, or mark it as not built.
- [ ] In the token paragraph, say that `materialLevel` sets only the glass of the floating controls.

## Acceptance

- §5 names each rule above, and each name agrees with the code after AVK-8b to AVK-8p.
- The text is ASD-STE100 Simplified Technical English.
- No source or test file changes in this card. #avk-8