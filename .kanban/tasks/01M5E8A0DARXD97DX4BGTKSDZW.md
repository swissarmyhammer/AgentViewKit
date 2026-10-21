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
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
- 01M5E8XMJXF8XABYA7P3ZGM5SF
- 01M5E8XTQS654VRMEBB5A6B05B
position_column: todo
position_ordinal: 9c80
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

- [ ] Scan `Sources/AgentViewKit`, `Sources/DemoSupport` and `Examples/AgentViewKitDemo`, code lines only. Report each use of: `.toolbarBackground(`, `.toolbarBackgroundVisibility(`, `.containerBackground(`, `.presentationBackground(`, `NSVisualEffectView`, `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`, `.thickMaterial`, `.ultraThickMaterial`, `.bar` as a fill style, and `.backgroundExtensionEffect(`.
- [ ] The allow list is empty. A later card that adds an image under the sidebar adds its file to the allow list of `.backgroundExtensionEffect(` only, with a reason in a comment.
- [ ] Add a check that the side panel of the kit is `.inspector`: `Sources/AgentViewKit/Attachments/AttachmentInspector.swift` has one `.inspector(` call on a code line.
- [ ] Add a check of the thread bars (D113 answer 7): `Sources/AgentViewKit/Thread/AgentThreadView.swift` has one `.safeAreaBar(edge: .top)` and one `.safeAreaBar(edge: .bottom)` on code lines. If AVK-8al and AVK-8am already hold the placement of each banner, do not repeat those checks here: name them in the doc comment.
- [ ] Add a check that the content of the two bars of `AgentThreadView` has no `.background(` fill (D112 (e)): no `.background(` with a style or color on the code lines of `floatingControls` and of the top bar content.
- [ ] Add a fixture file with one line for each forbidden form and a clean fixture with each form only in comments and strings.

## Acceptance

- `SystemStructureTests` passes on the current sources.
- The fixture test reports each forbidden form with its file and line, and nothing for the clean fixture.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8