---
assignees:
- claude-code
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
- 01M5DF7Y8PDWS7XF25WDBBYG9W
position_column: todo
position_ordinal: 9a80
title: 'AVK-8a1 Add the kit environment value that selects the glass look: Clear or Tinted'
---
## Why

AVK-8a (^dbbyg9w) found that SwiftUI has no API for the Clear or Tinted look of the system setting. The decision of testudoapp-4c: a kit environment value that selects the look is the test seam for the Tinted look. A person checks the real system Tinted setting one time for each release (AVK-8q). No card adds this value. AVK-8p needs it to test the Tinted look.

## What to do

- [ ] Add a public enum `AgentGlassLook` with the cases `.clear` and `.tinted`, and the environment value `\.agentGlassLook`. The default is `.clear`.
- [ ] Add a view modifier `agentGlassLook(_:)` that sets the value, in the style of `agentTheme(_:)`.
- [ ] Make one internal static function that gives the `Glass` for a look, a `MaterialLevel` and an accent color. `.clear` gives `materialLevel.glass`. `.tinted` gives `materialLevel.glass.tint(accent)`. The accent comes from `\.editorTheme`.
- [ ] `agentFloatingGlass()` (AVK-8b) reads the value and uses the function.
- [ ] Add DocC comments in STE that name D110 (f) and AVK-8a.

## Acceptance

- Tests in `Tests/AgentViewKitTests/Theme/`: the function gives `materialLevel.glass` for `.clear` and `materialLevel.glass.tint(accent)` for `.tinted` (`Glass` is `Equatable`). A view with `agentFloatingGlass()` renders different pixels with `.tinted` and `.clear` (`RenderedPixels`, with light mode, `_accessibilityReduceTransparency = false` and `_colorSchemeContrast = .standard` set first, as in `GlassRenderProbeTests.pixels(of:with:on:)`).
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8