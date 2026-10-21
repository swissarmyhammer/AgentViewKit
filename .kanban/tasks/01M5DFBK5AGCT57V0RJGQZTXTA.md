---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5e8dyc2pxkmsb04bcgmkd10
  text: |-
    ### plan update for style.md and D111 (TestudoApp 1c6c202)
    - style.md: "The screenshot step is part of the acceptance of each Liquid Glass card. Take the screenshots in light mode, dark mode, Reduce Transparency, Increase Contrast and the Tinted look". This card stays deterministic: it adds no screenshot compare. The manual screenshot check by a person with the demo app is AVK-8u (^8q34yt8), the last AVK-8 card.
    - style.md rule 9 also names Reduce Motion and the Clear look. The current views have no glass morph (see the open question 2 on ^b316bqv), so Reduce Motion has no glass case to test today. If a later card adds a morph, that card adds the Reduce Motion case. The Clear case is the default `.clear` of `\.agentGlassLook` (^w9y5tq6), which is the base render of each case here.
  timestamp: 2026-10-21T03:35:12.002498+00:00
- actor: claude-code
  id: 01m5e8ztkwmmbdz2nn8v777d54
  text: 'Changed for D113 (testudoapp-4c), answers 3 and 6. The card now tests only Reduce Transparency and Increase Contrast, with the ^dbbyg9w method (5 views x 2 settings). The Tinted look and the Clear look are system settings that a test cannot turn on deterministically: AVK-8u (^8q34yt8) checks them by hand. depends_on: removed AVK-8a1 (^w9y5tq6, closed as replaced); added AVK-8ad (^sdkm4qt, glass always `.regular`), AVK-8af (^ekr44gz, capsule chips), AVK-8ag (^spydp18) and AVK-8ah (^zm1hm5q, glass morph ids), so that the tests see the final glass views.'
  timestamp: 2026-10-21T03:44:57.980169+00:00
- actor: claude-code
  id: 01m5g0jjem00ryhzxyjbxemjyc
  text: |-
    ### research — the glass views and what ImageRenderer draws (SDK MacOSX27.0)
    - Glass views in Sources: `agentFloatingGlass` on the composer field (`PromptFieldSurface`), the editor menu (`PromptEditorMenuLayer`) and the request deck in the bar (`DeckSurface`). The `.glass` and `.glassProminent` button styles on Send, Stop, dictation, the suggestion chips, the scroll-to-bottom pill, and the request actions in content (`requestActionStyle`, used by the request cards, `StatusBar`, `SessionNoticeBanner`, `AgentAuthView`). `AgentSurfaces.swift` has the only `glassEffect`. Thus there are 2 more glass views than the card lists: the deck in the bar and the request actions in content.
    - `ImageRenderer` draws the `.glass` and `.glassProminent` buttons with no AppKit placeholder. With `_accessibilityReduceTransparency` or `_colorSchemeContrast = .increased`, about 3,000 to 7,000 pixels of each button render change.
    - `ImageRenderer` draws nothing for `SuggestionsView`: its chips are in a horizontal `ScrollView`. To test the chip glass, the chip must be a view of its own that a test renders out of the scroll view.
    - The circle buttons of the accessory row are about 22 points wide. The center of a `.glassProminent` button with a text label did not change with Reduce Transparency (the label is there). A point 4 points in from the leading or trailing edge of each glass, on its middle row, is in the glass and far from the rim (the rim changes only within 2 points of the edge).
    - The `PermissionModePicker` (an AppKit menu button) draws nothing in the render.
  timestamp: 2026-10-21T19:56:23.892320+00:00
- actor: claude-code
  id: 01m5g1x4d5xsqnh94g1aaq95ya
  text: |-
    ### implementation notes
    - New suite `Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift`: one `@Test(arguments: GlassView.allCases, GlassProbeSetting.allCases)`, 8 views x 2 settings = 16 cases. The test finds each glass on the middle row of the render (a span of pixels that do not show the backdrop), expects the number of glasses (for example 3 buttons while the agent runs), and calls `GlassRenderProbeTests.expectDifferentPixels` for each glass at 2 points, 4 points in from its leading and trailing edge (off the rim, off the label).
    - `SuggestionChip` is now a view of its own in `Sources/AgentViewKit/Input/SuggestionsView.swift`, because `ImageRenderer` draws nothing in the horizontal `ScrollView` of `SuggestionsView`. The look does not change, so no PNG changed.
    - `PromptInputGlassTests.swift` is deleted: the `composerField` case of the new suite replaces its one Reduce Transparency check, with the same full composer.
    - The editor menu case uses the real `PromptEditorMenuLayer` with a clear stand-in of the field that gives the anchor (`EditorMenuProbe`).

    ### mutation check
    - Reduce Transparency: `.environment(\._accessibilityReduceTransparency, false)` on each glass button (pill, chip, accessory styles, dictation, request action styles) and on the `GlassEffectContainer` of `FloatingGlassContainer`. Result: all 8 Reduce Transparency cases failed (12 glasses), all 8 Increase Contrast cases passed.
    - Increase Contrast: the same places with `.environment(\._colorSchemeContrast, .standard)`. Result: all 8 Increase Contrast cases failed (12 glasses), all 8 Reduce Transparency cases passed. The mutations are removed.
    - Discovery: an environment value after `.glassEffect` inside a `GlassEffectContainer` does not change the glass. The container reads the setting. Thus the first mutation on `AgentFloatingGlass` did not make the floating glass cases fail; the mutation on the container did.

    ### what did not work
    - The first watched full run (gqztxta-1) is not valid. `swift build --build-tests` failed on a name clash in the test file, and `run-watched.sh` then ran `swift test --skip-build` on the old binaries of the Increase Contrast mutation, so each Increase Contrast case and snapshot failed. Always read `build-exit` in the `.build` file of the monitor before you read the test result.
  timestamp: 2026-10-21T20:19:38.533661+00:00
- actor: claude-code
  id: 01m5g1x908t1nm1kqqaezn8vvj
  text: |-
    ### implement — changed
    - evidence: 3 files — Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift (new, 16 cases + 1 helper test), Sources/AgentViewKit/Input/SuggestionsView.swift (`SuggestionChip` view), Tests/AgentViewKitTests/Input/PromptInputGlassTests.swift (deleted, replaced). Mutation check: Reduce Transparency mutation made 8 of 8 Reduce Transparency cases fail; Increase Contrast mutation made 8 of 8 Increase Contrast cases fail. Full suite with the window monitor, 2 valid runs (gqztxta-2, gqztxta-3): build-exit=0, 1572 tests in 197 suites passed, 3 known issues from before, 0 on-screen test windows. Only warning: the mlx bundle build warning from before. No PNG changed.
    - next: /review
  timestamp: 2026-10-21T20:19:43.240817+00:00
depends_on:
- 01M5DF7Y8PDWS7XF25WDBBYG9W
- 01M5DF9SKZ4BRGBD6BFG5XY664
- 01M5DFA593MWNN971T9F2GCJ20
- 01M5DFADQHSHCRAQW0709TVAPV
- 01M5E8VGGTR59NGWNVHSDKM4QT
- 01M5E8W08CXBJD9CHP8EKR44GZ
- 01M5E8WCXKPRJWZ9XMPSPYDP18
- 01M5E8WMM146Y611ZQDZM1HM5Q
position_column: doing
position_ordinal: '8180'
title: AVK-8p Test each glass view with Reduce Transparency and Increase Contrast (the Tinted and Clear looks are manual checks of AVK-8u, D113 answer 6)
---
## Why

D110 (f) and `style.md` rule 9: each custom glass view is tested with the accessibility settings. AVK-8a (^dbbyg9w) found the deterministic method for Reduce Transparency and Increase Contrast. D113 answer 6 (testudoapp-4c): "A test cannot turn the system setting on deterministically, so the Tinted check is the manual screenshot check (AVK-8u)." The Clear look is a system setting too (D113 answer 3). Thus this card tests only Reduce Transparency and Increase Contrast. AVK-8a1 is closed as replaced; this card does not depend on it.

## Glass views to test

- The composer field with `agentFloatingGlass` (`Input/PromptInputView.swift:374`). After AVK-8ad its glass is always `.regular`.
- The editor menu with `agentFloatingGlass` (`Input/PromptInputView.swift:422`): the completion list and the no-commands note (`Input/EditorKitPromptEditor.swift`).
- The accessory cluster: Send, Stop, dictation (`Input/DefaultPromptAccessory.swift`, `Input/SpeechInputButton.swift`).
- The suggestion chips (`Input/SuggestionsView.swift`, capsule after AVK-8af).
- The scroll-to-bottom pill (`Thread/ScrollToBottomPill.swift`, in the container of AVK-8l).

## What to do

- [x] Add `Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift`. Use one parameterized `@Test` with the arguments (view, setting). The settings are Reduce Transparency and Increase Contrast.
- [x] Apply each setting with the method of ^dbbyg9w: `.environment(\._accessibilityReduceTransparency, true)` and `.environment(\._colorSchemeContrast, .increased)`, with the other setting held at its default, in light mode (as `GlassRenderProbeTests.pixels(of:with:on:)` and `ContentSurfaceHostedProbe`).
- [x] For each pair, check the assertion that ^dbbyg9w records. Examples: the setting reaches the view; the primary label keeps a vibrant style; with Reduce Transparency on, no pixel of the unique backdrop color shows inside the glass shape.
- [x] Do not test the Tinted look or the Clear look. Do not add `Glass.tint(_:)` or a kit look value to make them testable (D113 answer 6). Write in the doc comment of the suite that AVK-8u checks them by hand.
- [x] Add a test helper in `Sources/AgentViewKitTestSupport/` if two or more tests need the same setup. (Not necessary: only `GlassAccessibilityTests` uses the span helper.)

## Acceptance

- Each glass view above has one test for each of the two settings: 5 views x 2 settings = 10 cases, or the count that ^dbbyg9w records with a reason. (Result: 8 views x 2 settings = 16 cases. The search of the kit found 2 more glass views: the request deck in the bar and the request actions in content. The accessory row has 2 cases, idle and running, so that Send is checked with `.glassProminent` and with `.glass`.)
- All cases pass. A run of the suite two times gives the same result.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8