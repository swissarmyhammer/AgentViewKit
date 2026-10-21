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
- actor: claude-code
  id: 01m5g4kx6a8ztmp8zf1hmqtxmk
  text: |-
    ### research
    - plan.md and Docs/decisions/visual-audit.md are both in the AgentViewKit repo. No TestudoApp edit is necessary.
    - The token paragraph of §5 already has no `materialLevel` (AVK-8ae). visual-audit.md already has "The removed material level".
    - visual-audit.md "Colors and the code font" table has two rows that the code no longer does: "frame of a code block | `editorBackground`" and "header bar ... | `statusBarBackground`". `EditorThemeViewsTests` (`theCodeBlockFrameHasNoEditorBackground`, `theCodeBlockHeaderHasNoStatusBarBackground`) and `ContentFillTests` (forms `statusBarBackground`, `themeColorBackground`) forbid them.
    - The §5 glass paragraph names facts that the code does not do: "the picker" is not glass (`PermissionModePicker` is a plain control in the accessory row), the "tool tray" morph does not exist, and no source uses `appearsActive`.
    - Request card buttons: `RequestDeckPlace.style(of:)` gives `.glassProminent`/`.glass` in content, and `.borderedProminent`/`.bordered` on the deck glass in a bar ("Buttons on glass" in style.md). The card text says only "can use the glass button styles"; §5 names both places.
    - Docs tests that read plan.md or visual-audit.md: `DecisionRecordTests` (plan.md names no removed part) and `AgentThemeGoldenTests` (token table of visual-audit.md).
  timestamp: 2026-10-21T21:07:01.962162+00:00
- actor: claude-code
  id: 01m5g4th0n1xmy068t6hay73hz
  text: |-
    ### implementation notes
    - plan.md §5: the glass paragraph is now a link to `../TestudoApp/features/style.md` and `research-liquid-glass.md`, a list of 16 rules (each with its AVK card and its guard test), and an "Open items" list (^m231ph5, ^8q34yt8). The token paragraph says "No token selects the glass" and keeps the R12 sentence. "Match Xcode's restraint" now says tint is only for the primary action. §6 Reduce Motion got one sentence for the method of AVK-8ag and one for `GlassAccessibilityTests` (AVK-8p).
    - Removed from §5 because the code does not do them: "the picker" as glass, the tool tray morph, `appearsActive`, and "macOS 27 adds no new glass API" (not a code fact).
    - Card mapping corrected from the done cards: `GlassPlacementTests` is AVK-8n (not AVK-8o). AVK-8o extended `FixedColorTests`. `ComposerGlassStructureTests` is AVK-8i. The card item "request card buttons can use the glass button styles" is only true in content: in a bar they are `.bordered` / `.borderedProminent` (AVK-8y, style.md "Buttons on glass"). §5 says both.
    - visual-audit.md: removed the rows "frame of a code block | `editorBackground`" and "header bar ... | `statusBarBackground`", and added a paragraph that says D113 replaces them, names the guards, and names ^m231ph5. The `materialLevel` section already agreed (AVK-8ae).
    - TestudoApp: no file changed.
  timestamp: 2026-10-21T21:10:38.869407+00:00
- actor: claude-code
  id: 01m5g4tktcghfjgf4nfkyxsann
  text: |-
    ### implement — changed
    - evidence: 2 files in the AgentViewKit repo — plan.md (§5, §6 Reduce Motion sentence), Docs/decisions/visual-audit.md (two stale color rows replaced by a D113 note). No source or test file changed. TestudoApp not changed (git status clean). Docs tests: `swift test --filter 'DecisionRecordTests|AgentThemeGoldenTests|ReadmeCoverageTests'` — 23 tests in 2 suites passed, and 3 tests in 1 suite passed.
    - next: /review. Not committed.
  timestamp: 2026-10-21T21:10:41.740467+00:00
- actor: claude-code
  id: 01m5g55fjmj1m8yza7ggy7g4sh
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (f7dac58): engine 0 findings (no validator matches Markdown). Factual check: 9 findings — plan.md:242, plan.md:246 (2), plan.md:248, plan.md:249, plan.md:251, plan.md:253, plan.md:255, plan.md:256. visual-audit.md: the D113 paragraph agrees with the code.
    - next: correct each item in the "Review Findings (2026-10-21 16:11)" section of plan.md, then review again.
  timestamp: 2026-10-21T21:16:37.844849+00:00
- actor: claude-code
  id: 01m5g564ndghmf80f17b4nz64q
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — plan.md §5 and §6, Docs/decisions/visual-audit.md
    - test: green — DecisionRecordTests, AgentThemeGoldenTests, ReadmeCoverageTests: 26 passed (docs only, no code change)
    - commit: f7dac58
    - review: findings — plan.md:242, :246 (2), :248, :249, :251, :253, :255, :256 (factual check)
  timestamp: 2026-10-21T21:16:59.437374+00:00
- actor: claude-code
  id: 01m5g5jjh6vs4rhv7c2nkmey4w
  text: |-
    ### fact check of the review findings (2026-10-21 16:11)
    Fixed the 9 items in plan.md §5. Sources that I read for each item:
    - Sidebar (two places): D116 (a) and style.md rule 1. §5 now says that the system decides the look; on macOS 27 the sidebar has a system gray and the toolbar controls are glass groups. Note: the "Two layers" table of style.md still lists the sidebar under "Liquid Glass". Rule 1 and D116 are newer, so §5 follows them.
    - Card ids, from `git log --diff-filter=A`: AgentSurface came from ^c5mvvt4 (AVK-8b), `.concentric` from ^vyn7qq9 (AVK-8m, also FixedCornerRadiusTests). GlassButtonShapeTests is ^ekr44gz (AVK-8af). AVK-8ai moved to the tint sentence. The accent rule is enforced by ThemeInjectionTests (^78jx8yr, AVK-8t): `accentFiles` permits the accent in 4 files and holds each to its number of uses.
    - Cadence: the "one time for each release" text comes from TestudoApp `features/packages/agentviewkit.md` "Decisions for the plan (2026-10-20)" item 2. That item also says that the tests use a kit environment value to select the Tinted look. D113 answer 6 replaced that method with the manual check of AVK-8u. Thus §5 now gives the cadence of the AVK-8u card ("LAST") and of style.md (part of the acceptance of each Liquid Glass card).
    - Theme injection: the demo injects `.editorTheme(.system)` at the window root (AgentViewKitDemoApp.swift) and the Gallery tab injects the look theme in its subtree (`galleryLook(_:)`, GalleryLook.swift). ThemeInjectionTests scans only the kit for the theme forms.

    ### other false statements of the same kind (full check of the f7dac58 text)
    - "No fill in content" said that request cards have no glass. In a bar, the deck is on the floating glass. Now: "no glass of their own", with a pointer to the deck rule.
    - ContentFillTests "gives the reason of each permitted chip fill": the allow list also permits the selection fill of DiffView and ElicitationLayout, the current source of SourcesView and the terminal background. §5 now names these.
    - "Button styles first": in content, a `.standard` action (Cancel, Decline of an elicitation card) keeps the style of its environment (`RequestDeckPlace.style(of:)`). Added.
    - GlassPlacementTests "checks that each request card gets its button styles from the place of the deck": the test checks only that 6 files call `requestActionStyle(`. Now says that.
    - Tint: "gets the tint from the `.glassProminent` style" is false in a bar, where the primary action uses `.borderedProminent`. Fixed.
    - SystemStructureTests: added that it checks one `.inspector(` call in AttachmentInspector.swift.
    - HiddenTestWindowTests "holds this rule": now says what it forbids (calls that show a window or make the application active, in the test and test-support sources).
    - Snapshots "do not replace the screenshot check": now gives the source reason (hosted images show no glass; GlassSnapshotTests images can differ from the system glass).
    - visual-audit.md D113 paragraph: checked, it agrees (no `editorBackground` or `statusBarBackground` use in Sources or Examples).
    - Open, not changed (code vs style guide, not a plan.md error): style.md rule 4 says that a bar with no glass surface keeps `.glass` on its buttons, but the kit gives the state banner and the login prompt in the bottom bar the bordered styles (RequestActionStyle.swift cites "Bars of a view"). A person can decide if this needs a card.
  timestamp: 2026-10-21T21:23:46.854462+00:00
- actor: claude-code
  id: 01m5g5jnbgj4pye3cym42esxns
  text: |-
    ### implement — changed
    - evidence: plan.md §5 (10 changed lines: Two layers, No fill in content, Variant and shape, Button styles first, Morphs, Tint and accent, System chrome, Themes, Accessibility, Snapshots). visual-audit.md checked, no change needed. No source or test file changed. 9 of 9 review findings checked. Docs tests: `swift test --filter 'DecisionRecordTests|AgentThemeGoldenTests|ReadmeCoverageTests'` — 23 tests in 2 suites passed, 3 tests in 1 suite passed; only the known mlx bundle build warning.
    - next: /review. Not committed. Card stays in doing.
  timestamp: 2026-10-21T21:23:49.744371+00:00
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
position_column: doing
position_ordinal: '8180'
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

- [x] **The style guide.** Say that `TestudoApp/features/style.md` is the one style guide, and that §5 gives only how the kit does each rule.
- [x] **Two layers.** Navigation and control (glass) and content (no glass), with the list of each layer from `style.md`.
- [x] **No fill in content (D113 answer 1).** The transcript, the messages, the tool call cards, the request cards, the notices, the state banners, the code blocks and the artifacts have no fill and no glass. `agentContentEdge(radius:)` draws a `.separator` stroke in a `ConcentricRectangle` (AVK-8v). `agentContentSurface` is removed (AVK-8ab). If a group needs more, the kit uses a system container (`GroupBox`, or a grouped `Form`), never a custom fill. Name the answer of AVK-8aa for the terminal background.
- [x] **Header rows (D113 answer 4).** The header row of a code block, the terminal and command output is content, not a bar. It has no fill; a `.separator` line marks it (AVK-8ac).
- [x] **Glass only on floating controls.** The composer field, its accessory cluster, the suggestions, the editor menu and the scroll-to-bottom pill use `agentFloatingGlass` or the glass button styles, in one `GlassEffectContainer` (`FloatingGlassContainer`, AVK-8l). Never glass on glass.
- [x] **Variant and shape (D113 answer 3).** Floating glass is always `.regular`. The Clear and Tinted looks are system settings that the system applies; no theme value selects the variant, and `AgentTheme` has no `materialLevel` (AVK-8ad, AVK-8ae). Small floating controls (the pill, the chips) are `.capsule`; icon-only buttons are `.circle`; the composer field and the editor menu are a `ConcentricRectangle` (AVK-8af).
- [x] **Button styles first.** `.glass` and `.glassProminent` before custom glass. One prominent action at a time: Send when the agent is idle, Stop while the agent runs. The action buttons of a request card can use the glass button styles.
- [x] **Morphs (D113 answer 2).** Remove the old tool tray sentence. Say: when one glass element shows or hides next to another in the same container (the pill and the composer field, the editor menu and the field, the suggestion chips), each has a `glassEffectID` in the one `@Namespace` of `FloatingGlassContainer` (AVK-8ag, AVK-8ah). Name the Reduce Motion method of AVK-8ag.
- [x] **Tint and accent (D113 answers 5 and 6).** `.tint` only on the primary action. No `.foregroundStyle(.tint)` on other controls. No `Glass.tint(_:)`. In content, the theme accent marks only a link, the selection or the current item (AVK-8ai, AVK-8aj, AVK-8ak, AVK-8t).
- [x] **Scroll under the bars (D113 answer 7).** The thread list scrolls under the top bar (header and banners) and under the bottom bar (state banner, sign-in prompt, pill, composer), with the scroll edge effect (AVK-8al, AVK-8am).
- [x] **System chrome.** Toolbars, the sidebar, the inspector, sheets, popovers and menus are system glass. The kit adds no background to them (AVK-8s).
- [x] **Themes (D112).** One theme system: the `Theme` of EditorTheme. The default is `SystemTheme`. The host injects the theme once at the root of each window with `.editorTheme(_:)`. The kit sets no theme and has no color constants of its own. A theme colors only the content layer. No view draws an opaque theme fill behind a bar, and no view uses the status bar or tab bar color of a theme.
- [x] **Computed palettes (D113 answer 8).** The terminal colors 0 to 15 come from `TerminalPalette`; 16 to 255 come from the xterm formula. A standard formula is not a color constant of the kit.
- [x] **Images under the sidebar.** The kit has no image under the sidebar, so it uses no `.backgroundExtensionEffect()` (D111 step 6, AVK-8s).
- [x] **Accessibility.** Each glass view has a test with Reduce Transparency and Increase Contrast (AVK-8p). The Tinted look and the Clear look are system settings that no test can turn on deterministically: a person checks them in the screenshots of AVK-8u, one time for each release.
- [x] **The screenshot check.** Name the manual check of D111 step 8 (AVK-8u): a person compares screenshots of the demo app with Finder and System Settings in light mode, dark mode, Reduce Transparency, Increase Contrast, the Tinted look and the Clear look.
- [x] **Guards.** Name `GlassPlacementTests`, `ComposerGlassStructureTests`, `FixedColorTests` and `ContentFillTests` (AVK-8o, AVK-8r), `SystemStructureTests` (AVK-8s) and `ThemeInjectionTests` (AVK-8t).
- [x] In the token paragraph, remove `materialLevel` (AVK-8ae) and say that no token selects the glass.

## Acceptance

- §5 names each rule above, and each name agrees with the code after AVK-8b to AVK-8am.
- §5 has a link to `TestudoApp/features/style.md` and names D113.
- The text is ASD-STE100 Simplified Technical English.
- No source or test file changes in this card. #avk-8

## Review Findings (2026-10-21 16:11)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 0 file(s) reviewed, 6 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `Docs/decisions/visual-audit.md` — no validator matches this file
> - `plan.md` — no validator matches this file

> No validator matches Markdown. Thus a factual check of the added lines of `plan.md` against `Sources/`, `Tests/` and the cards adds these items. Each statement must agree with the code and with the card that it names.

- [x] `plan.md:242` `factcheck/style-guide` — "The navigation and control layer is Liquid Glass: the sidebar, ..." does not agree with D116. `TestudoApp/features/style.md` rule 1 and D116 (a) say: "On macOS 27, the sidebar has a system gray, as in Notes, Safari and News." Do not call the sidebar glass. Say that the system decides the look of the sidebar (a system gray on macOS 27, D116).
- [x] `plan.md:246` `factcheck/card-id` — "(`AgentSurface`, AVK-8af)" names the wrong card. AVK-8af (`.kanban/tasks/01M5E8W08CXBJD9CHP8EKR44GZ.md`) only adds `.buttonBorderShape(.capsule)` to the suggestion chips and adds `GlassButtonShapeTests`. It records the `ConcentricRectangle` of the field and the menu as a correct fact that was there before. `AgentSurface` came from AVK-8b, and the `.concentric` corner style came from AVK-8m (`.kanban/tasks/01M5DFAW7AV9PV85QA3VYN7QQ9.md`, code at `Sources/AgentViewKit/Theme/AgentSurfaces.swift:41-43`). Name AVK-8b and AVK-8m for this sentence.
- [x] `plan.md:246` `factcheck/test-claim` — "`GlassButtonShapeTests` checks the border shape of each glass button of the small floating controls" says more than the test does. The test does not check each button. It checks a count in each file of `Input/` and `ScrollToBottomPill.swift`: the number of `.capsule` or `.circle` border shapes is at least the number of glass button styles, and a `self.buttonStyle(` helper counts as one style (`Tests/PackageStructureTests/GlassButtonShapeTests.swift:50-65`, `lacksShapes(_:)`). Say that the test checks the count in each file.
- [x] `plan.md:248` `factcheck/test-claim` — "`GlassPlacementTests` checks that only `AgentGlassID` applies `glassEffectID(_:in:)`" says more than the test does. The test permits `glassEffectID(` in one file, `Theme/AgentSurfaces.swift` (`Tests/PackageStructureTests/GlassPlacementTests.swift:70`, `allowedFiles` of `.glassEffectID`). It does not check one type. Say that the test permits `glassEffectID(_:in:)` only in `Theme/AgentSurfaces.swift`, the file of `AgentGlassID`.
- [x] `plan.md:249` `factcheck/card-id` — "the theme accent marks only a link, the selection or the current item (AVK-8ai, AVK-8aj, AVK-8ak)" names a wrong card. AVK-8ai (`.kanban/tasks/01M5E8WVTY0ANTQVTGYXA3R4Z2.md`) removes `.foregroundStyle(.tint)` from `SpeechInputButton` (D113 answer 5, the tint). It is not about the theme accent. Move AVK-8ai to the sentence "No view uses a `.tint(_:)` modifier or `.foregroundStyle(.tint)`", and keep AVK-8aj and AVK-8ak for the accent sentence.
- [x] `plan.md:251` `factcheck/style-guide` — "Toolbars, the sidebar, the inspector, sheets, popovers and menus are system glass" does not agree with D116 (`TestudoApp/features/style.md` rule 1): on macOS 27 the sidebar has a system gray. Remove the sidebar from the list of system glass, or say that the system decides the look of each of these views.
- [x] `plan.md:253` `factcheck/test-claim` — "The host injects the theme once, at the root of each window, with `.editorTheme(_:)`" does not agree with the demo host. The demo also injects a second theme in a subtree: `.editorTheme(look.theme.theme)` at `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryLook.swift:121`. `ThemeInjectionTests` scans only the kit for an injection (`Tests/PackageStructureTests/ThemeInjectionTests.swift:59`). Make the statement agree with the demo, or say that the rule is for the kit and name the gallery subtree as the permitted exception.
- [x] `plan.md:255` `factcheck/card-claim` — "A person checks them in the screenshots of AVK-8u, one time for each release" has no source. The AVK-8u card (`.kanban/tasks/01M5E8BE1VW9QK2YTDF8Q34YT8.md`) says "Do this card LAST, after all the other AVK-8 cards", and `TestudoApp/features/style.md` says "The screenshot step is part of the acceptance of each Liquid Glass card". Neither file says "release". Use the cadence that the sources give.
- [x] `plan.md:256` `factcheck/test-claim` — "`HostedSnapshotTests` (AVK-13) records an image of each real view" says more than the test does. The suite records 10 views only (`Tests/AgentViewKitTests/Snapshots/HostedSnapshotTests.swift:41-116`): the thread, the idle composer, the running composer, the permission card, the deck in a bar, the session notice, the status banner, the code block, the terminal output and the elicitation form. Name these views, or say "an image of 10 real views".
