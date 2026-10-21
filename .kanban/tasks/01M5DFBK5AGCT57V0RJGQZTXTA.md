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
depends_on:
- 01M5DF7Y8PDWS7XF25WDBBYG9W
- 01M5DF9SKZ4BRGBD6BFG5XY664
- 01M5DFA593MWNN971T9F2GCJ20
- 01M5DFADQHSHCRAQW0709TVAPV
- 01M5E8VGGTR59NGWNVHSDKM4QT
- 01M5E8W08CXBJD9CHP8EKR44GZ
- 01M5E8WCXKPRJWZ9XMPSPYDP18
- 01M5E8WMM146Y611ZQDZM1HM5Q
position_column: todo
position_ordinal: '9780'
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

- [ ] Add `Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift`. Use one parameterized `@Test` with the arguments (view, setting). The settings are Reduce Transparency and Increase Contrast.
- [ ] Apply each setting with the method of ^dbbyg9w: `.environment(\._accessibilityReduceTransparency, true)` and `.environment(\._colorSchemeContrast, .increased)`, with the other setting held at its default, in light mode (as `GlassRenderProbeTests.pixels(of:with:on:)` and `ContentSurfaceHostedProbe`).
- [ ] For each pair, check the assertion that ^dbbyg9w records. Examples: the setting reaches the view; the primary label keeps a vibrant style; with Reduce Transparency on, no pixel of the unique backdrop color shows inside the glass shape.
- [ ] Do not test the Tinted look or the Clear look. Do not add `Glass.tint(_:)` or a kit look value to make them testable (D113 answer 6). Write in the doc comment of the suite that AVK-8u checks them by hand.
- [ ] Add a test helper in `Sources/AgentViewKitTestSupport/` if two or more tests need the same setup.

## Acceptance

- Each glass view above has one test for each of the two settings: 5 views x 2 settings = 10 cases, or the count that ^dbbyg9w records with a reason.
- All cases pass. A run of the suite two times gives the same result.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8