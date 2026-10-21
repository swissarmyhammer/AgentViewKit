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
- actor: claude-code
  id: 01m5e93vzn25sham44sf6eedak
  text: 'Changed for D113 (testudoapp-4c). The checklist now names each D113 answer: no fill in content (`agentContentEdge`), header rows, `.regular` glass and no `materialLevel`, capsule shapes, morphs with `glassEffectID`, tint and accent, the thread bars, the xterm formula, and the Tinted and Clear looks as manual checks of AVK-8u. depends_on: removed AVK-8a1 ^w9y5tq6 (closed as replaced); added AVK-8v to AVK-8am.'
  timestamp: 2026-10-21T03:47:10.453278+00:00
- actor: claude-code
  id: 01m5eksfmq0aqhk53reerzbcvd
  text: |-
    ### note from ^6dvspvv (AVK-8ac)
    - `Docs/decisions/visual-audit.md` has a row that gives `statusBarBackground` for the header row of a code block. That row is now out of date: the header row has no fill and a separator line is under it (D113 answer 4). Correct that row or add a note that D113 replaces it.
    - `statusBarBackground` now has no user in `Sources/AgentViewKit`.
  timestamp: 2026-10-21T06:53:44.471916+00:00
depends_on:
- 01M5DFADQHSHCRAQW0709TVAPV
- 01M5DF7Y8PDWS7XF25WDBBYG9W
- 01M5DFBC5CXFEGX6P4XB316BQV
- 01M5DFBK5AGCT57V0RJGQZTXTA
- 01M5E89EEX3YFT59487ZFZ0B4V
- 01M5E8A0DARXD97DX4BGTKSDZW
- 01M5E8ARAN32Y4WA38D78JX8YR
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
- 01M5E8SRKB36TVJNFAE2F1ARB7
- 01M5E8SYCWE9FM05FFS1T18BMX
- 01M5E8T69B91ATX31Q3BR70YR3
- 01M5E8TFNDT9Q9WE6C2D6YW9PP
- 01M5E8TQ4JA20GAATH7MZ0NFKA
- 01M5E8TYC4FB02MHJKMXA6V4JC
- 01M5E8V827CA2TZMZ136DVSPVV
- 01M5E8VGGTR59NGWNVHSDKM4QT
- 01M5E8VRDBMPYNDX62PS6C2TF0
- 01M5E8W08CXBJD9CHP8EKR44GZ
- 01M5E8WCXKPRJWZ9XMPSPYDP18
- 01M5E8WMM146Y611ZQDZM1HM5Q
- 01M5E8WVTY0ANTQVTGYXA3R4Z2
- 01M5E8X2DC7CT94TQJG2G7W4MZ
- 01M5E8XAAZ7ZAT3RKSG102C8KK
- 01M5E8XMJXF8XABYA7P3ZGM5SF
- 01M5E8XTQS654VRMEBB5A6B05B
position_column: todo
position_ordinal: '9880'
title: AVK-8q Change plan.md §5 to name the Liquid Glass rules of D110, the procedure of D111, the themes of D112 and the answers of D113
---
## Why

AVK-8 tells us to change plan.md §5 to name the rules. Today §5 says that the picker, the toolbars and the inspector use `GlassEffectContainer` and `.glassEffect`, and that `.glassEffectID` morphs the composer into a tool tray.

Since TestudoApp 1c6c202, `TestudoApp/features/style.md` is the one style guide of the app and of each view kit (D112 (a)). It has the two layers, the Liquid Glass rules (D110), the eight steps of the procedure (D111), the section "How the steps apply" (D113) and the themes (D112). §5 must point to it and agree with it.

D113 (testudoapp-4c) answers the open questions of the plan update comment on ^b316bqv. §5 must name these answers.

## Files

- `/Users/wballard/github/swissarmyhammer/AgentViewKit/plan.md` §5, lines 234-244. The glass paragraph is line 238. The token paragraph is line 244.
- `/Users/wballard/github/swissarmyhammer/AgentViewKit/Docs/decisions/visual-audit.md` line 30 (`materialLevel` row): AVK-8ae changes it. Check that it agrees.
- Do not change §6 line 252 (Reduce Motion), except to add a reference to the tests of AVK-8p and to the morph method of AVK-8ag.

## What to do

Rewrite the glass paragraph of §5 in STE. Name these rules and cite D110, D111, D112, D113, `TestudoApp/features/style.md` and `TestudoApp/features/research-liquid-glass.md`:

- [ ] **The style guide.** Say that `TestudoApp/features/style.md` is the one style guide, and that §5 gives only how the kit does each rule.
- [ ] **Two layers.** Navigation and control (glass) and content (no glass), with the list of each layer from `style.md`.
- [ ] **No fill in content (D113 answer 1).** The transcript, the messages, the tool call cards, the request cards, the notices, the state banners, the code blocks and the artifacts have no fill and no glass. `agentContentEdge(radius:)` draws a `.separator` stroke in a `ConcentricRectangle` (AVK-8v). `agentContentSurface` is removed (AVK-8ab). If a group needs more, the kit uses a system container (`GroupBox`, or a grouped `Form`), never a custom fill. Name the answer of AVK-8aa for the terminal background.
- [ ] **Header rows (D113 answer 4).** The header row of a code block, the terminal and command output is content, not a bar. It has no fill; a `.separator` line marks it (AVK-8ac).
- [ ] **Glass only on floating controls.** The composer field, its accessory cluster, the suggestions, the editor menu and the scroll-to-bottom pill use `agentFloatingGlass` or the glass button styles, in one `GlassEffectContainer` (`FloatingGlassContainer`, AVK-8l). Never glass on glass.
- [ ] **Variant and shape (D113 answer 3).** Floating glass is always `.regular`. The Clear and Tinted looks are system settings that the system applies; no theme value selects the variant, and `AgentTheme` has no `materialLevel` (AVK-8ad, AVK-8ae). Small floating controls (the pill, the chips) are `.capsule`; icon-only buttons are `.circle`; the composer field and the editor menu are a `ConcentricRectangle` (AVK-8af).
- [ ] **Button styles first.** `.glass` and `.glassProminent` before custom glass. One prominent action at a time: Send when the agent is idle, Stop while the agent runs. The action buttons of a request card can use the glass button styles.
- [ ] **Morphs (D113 answer 2).** Remove the old tool tray sentence. Say: when one glass element shows or hides next to another in the same container (the pill and the composer field, the editor menu and the field, the suggestion chips), each has a `glassEffectID` in the one `@Namespace` of `FloatingGlassContainer` (AVK-8ag, AVK-8ah). Name the Reduce Motion method of AVK-8ag.
- [ ] **Tint and accent (D113 answers 5 and 6).** `.tint` only on the primary action. No `.foregroundStyle(.tint)` on other controls. No `Glass.tint(_:)`. In content, the theme accent marks only a link, the selection or the current item (AVK-8ai, AVK-8aj, AVK-8ak, AVK-8t).
- [ ] **Scroll under the bars (D113 answer 7).** The thread list scrolls under the top bar (header and banners) and under the bottom bar (state banner, sign-in prompt, pill, composer), with the scroll edge effect (AVK-8al, AVK-8am).
- [ ] **System chrome.** Toolbars, the sidebar, the inspector, sheets, popovers and menus are system glass. The kit adds no background to them (AVK-8s).
- [ ] **Themes (D112).** One theme system: the `Theme` of EditorTheme. The default is `SystemTheme`. The host injects the theme once at the root of each window with `.editorTheme(_:)`. The kit sets no theme and has no color constants of its own. A theme colors only the content layer. No view draws an opaque theme fill behind a bar, and no view uses the status bar or tab bar color of a theme.
- [ ] **Computed palettes (D113 answer 8).** The terminal colors 0 to 15 come from `TerminalPalette`; 16 to 255 come from the xterm formula. A standard formula is not a color constant of the kit.
- [ ] **Images under the sidebar.** The kit has no image under the sidebar, so it uses no `.backgroundExtensionEffect()` (D111 step 6, AVK-8s).
- [ ] **Accessibility.** Each glass view has a test with Reduce Transparency and Increase Contrast (AVK-8p). The Tinted look and the Clear look are system settings that no test can turn on deterministically: a person checks them in the screenshots of AVK-8u, one time for each release.
- [ ] **The screenshot check.** Name the manual check of D111 step 8 (AVK-8u): a person compares screenshots of the demo app with Finder and System Settings in light mode, dark mode, Reduce Transparency, Increase Contrast, the Tinted look and the Clear look.
- [ ] **Guards.** Name `GlassPlacementTests`, `ComposerGlassStructureTests`, `FixedColorTests` and `ContentFillTests` (AVK-8o, AVK-8r), `SystemStructureTests` (AVK-8s) and `ThemeInjectionTests` (AVK-8t).
- [ ] In the token paragraph, remove `materialLevel` (AVK-8ae) and say that no token selects the glass.

## Acceptance

- §5 names each rule above, and each name agrees with the code after AVK-8b to AVK-8am.
- §5 has a link to `TestudoApp/features/style.md` and names D113.
- The text is ASD-STE100 Simplified Technical English.
- No source or test file changes in this card. #avk-8