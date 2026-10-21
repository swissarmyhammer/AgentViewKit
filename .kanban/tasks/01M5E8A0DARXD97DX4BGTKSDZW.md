---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5e8aak5qph41erwycadmtss
  text: |-
    ### note for the `.bar` form
    `Sources/AgentViewKit/Status/SessionStreamBanner.swift:111` has `map(\.bar)`, a key path to a property with the name `bar`. It is not a fill style. The pattern for `.bar` must find only the shape style, for example `.background(.bar` and `.fill(.bar` and `in: .bar`, and not `\.bar` or `.bar` after an identifier. Add one clean fixture line with `map(\.bar)` to prove it.
  timestamp: 2026-10-21T03:33:13.445874+00:00
- actor: claude-code
  id: 01m5e93pdhznpvsfmqjxwnjtwn
  text: 'Changed for D113 (testudoapp-4c), answer 7. Added two checks: `AgentThreadView.swift` has one top and one bottom `.safeAreaBar`, and the content of the two bars has no `.background` fill. depends_on: added AVK-8al ^3zgm5sf and AVK-8am ^5a6b05b.'
  timestamp: 2026-10-21T03:47:04.753325+00:00
- actor: claude-code
  id: 01m5fsh7zwsk3h1erjm88tzyhh
  text: |-
    ### research and implementation notes
    - The design notes are in `../TestudoApp/features/decisions.md` (D111, D113) and `../TestudoApp/features/style.md` ("Procedure", "How the steps apply"). They are not in this repo.
    - The `.bar` form: `RequestDeckPlace` has a case `.bar` (`RequestActionStyle.swift`, `RequestDeck.swift`: `case (.bar, .primary)`, `? .bar : .content`, `case .bar:`). Thus the pattern finds `.bar` only as the argument of a fill: `background(.bar`, `fill(.bar`, `backgroundStyle(.bar` and `in: .bar`. The look-alike samples and the clean fixture hold each of these enum lines and `map(\.bar)`.
    - Shared helpers in use: `GlassPlacementTests.uses(of:inSwiftFilesBelow:relativeTo:allowing:)` (on `SourceLineScanner.codeMatches`), `GlassForm.callPattern`/`memberCallPattern`, `WordPattern.wholeWord`/`memberPattern`, `ComposerGlassStructureTests.codeLineCount(of:in:)`, `ThreadBottomBarStructureTests.code(of:)` and `block(after:in:)`, `ThreadTopBarStructureTests.topBarStart`.
    - `ThreadBottomBarStructureTests` now has `floatingControlsStart`, so the literal `"var floatingControls"` is in one place. Its two `BarView` rows and the new suite use it.
    - The bar fill scan has its own fixture (`Fixtures/SystemStructure/Bars/FilledBars.swift`) with one `.background(` in each bar.
    - The product code has no violation. No view changed, so the snapshot images did not change.
    - Mutation check: I added `.backgroundExtensionEffect()` and `.toolbarBackground(.hidden, for: .windowToolbar)` to `GalleryColumns.swift`, `.background(.bar)` to `floatingControls`, and `.background(Color.clear)` to the top bar content. `SystemStructureTests` failed with 5 issues: backgroundExtensionEffect, toolbarBackground, barMaterial, and a fill count of 1 in each thread bar. Then I removed the mutations. `git diff -- Sources Examples` is empty.
  timestamp: 2026-10-21T17:53:20.380036+00:00
- actor: claude-code
  id: 01m5fshbewtng83nvnt6ynpbnz
  text: |-
    ### implement — changed
    - evidence: new `Tests/PackageStructureTests/SystemStructureTests.swift`; new fixtures `Tests/PackageStructureTests/Fixtures/SystemStructure/Violating/CustomBackgrounds.swift`, `Clean/SystemStructureInText.swift`, `Bars/FilledBars.swift`; changed `Tests/PackageStructureTests/ThreadBottomBarStructureTests.swift` (`floatingControlsStart`). Full suite with the window monitor (`run-watched.sh gtksdzw`): test-exit=0, 1544 Swift Testing tests in 194 suites passed (3 known issues, which are tests that expect a failure on purpose), 190 PackageStructureTests tests in 27 suites passed, on-screen test-process windows: 0. Build: build-exit=0; one SwiftPM build-system line `warning: missing creator for mutated node` for the mlx-swift_Cmlx bundle, from the dependency build, not from a source file. Mutation check: 5 issues as expected, then removed.
    - next: /review
  timestamp: 2026-10-21T17:53:23.932563+00:00
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
- 01M5E8XMJXF8XABYA7P3ZGM5SF
- 01M5E8XTQS654VRMEBB5A6B05B
position_column: doing
position_ordinal: '80'
title: 'AVK-8s Structure test: system structure with no custom background on bars, sidebar and inspector, the thread list under its top and bottom bars, and no backgroundExtensionEffect (D111 steps 2 and 6, D113 answer 7)'
---
## Why

D111 step 2 (`style.md` "Procedure"): "Use the system structure. `NavigationSplitView` for the sidebar and the detail, `.toolbar` for controls, `.inspector` for side panels. The system gives them glass." `style.md` rule 1: "Put no custom background and no visual-effect view on a bar, the sidebar or the inspector."

D111 step 6: "Use `.backgroundExtensionEffect()` on an image that must extend under the sidebar. Do not use it on text."

D113 answer 7 (testudoapp-4c) and `style.md` "Scroll under the bars": the list of a view scrolls under its bars. `StateBanner` and `AgentLoginPrompt` are in the bottom `.safeAreaBar` with the composer (AVK-8al). The header and the top banners are in a top bar (AVK-8am).

Facts from a search on 2026-10-20:
- The kit has no `NavigationSplitView` of its own. The host gives it. The side panel of the kit is `.inspector` (`Sources/AgentViewKit/Attachments/AttachmentInspector.swift:65`).
- The demo uses the system structure: `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift:64-75`, `ACPSettingsSheet.swift:57`, `Sources/DemoSupport/GalleryColumns.swift:107-123`.
- No file in the three roots uses `.toolbarBackground`, `.containerBackground`, `.presentationBackground`, `NSVisualEffectView`, a `Material` fill or `.backgroundExtensionEffect()`.
- The kit has no image that extends under the sidebar. Thus step 6 has no work today.

## Files

- New: `Tests/PackageStructureTests/SystemStructureTests.swift`, with fixtures in `Tests/PackageStructureTests/Fixtures/SystemStructure/`.
- Use `SourceLineScanner.codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)` (from ^b316bqv) and `WordPattern.wholeWord`.

## What to do

- [x] Scan `Sources/AgentViewKit`, `Sources/DemoSupport` and `Examples/AgentViewKitDemo`, code lines only. Report each use of: `.toolbarBackground(`, `.toolbarBackgroundVisibility(`, `.containerBackground(`, `.presentationBackground(`, `NSVisualEffectView`, `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`, `.thickMaterial`, `.ultraThickMaterial`, `.bar` as a fill style, and `.backgroundExtensionEffect(`.
- [x] The allow list is empty. A later card that adds an image under the sidebar adds its file to the allow list of `.backgroundExtensionEffect(` only, with a reason in a comment.
- [x] Add a check that the side panel of the kit is `.inspector`: `Sources/AgentViewKit/Attachments/AttachmentInspector.swift` has one `.inspector(` call on a code line.
- [x] Add a check of the thread bars (D113 answer 7): `Sources/AgentViewKit/Thread/AgentThreadView.swift` has one `.safeAreaBar(edge: .top)` and one `.safeAreaBar(edge: .bottom)` on code lines. If AVK-8al and AVK-8am already hold the placement of each banner, do not repeat those checks here: name them in the doc comment.
- [x] Add a check that the content of the two bars of `AgentThreadView` has no `.background(` fill (D112 (e)): no `.background(` with a style or color on the code lines of `floatingControls` and of the top bar content.
- [x] Add a fixture file with one line for each forbidden form and a clean fixture with each form only in comments and strings.

## Acceptance

- `SystemStructureTests` passes on the current sources.
- The fixture test reports each forbidden form with its file and line, and nothing for the clean fixture.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8