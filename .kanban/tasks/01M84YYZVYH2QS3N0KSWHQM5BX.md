---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8503tncnzybvq2c51cv3ngg
  text: |-
    Research and implementation notes.
    - The surface of a floating `StatusBar` was a private modifier in `StatusBar.swift`. It is now the public `.statusBarPlacementSurface(radius:)` in `StatusBarPlacement.swift` (AgentViewKitStyle). It reads `\.statusBarPlacement`: in content `.inlineEdge(radius:)`, when floating `.editorButtonSurface(.glass)` + `.floatingGlass()`. `StatusBar` and `AgentAuthView` both use it. No new material.
    - `AgentThreadView` puts `.statusBarPlacement(.floating)` on a `Group` of the `StateBanner` and the `AgentLoginPrompt`, in the one `FloatingGlassContainer` of the bottom bar. The composer slot is out of the group, so a bar on the glass of a request deck stays content (no glass on glass).
    - `AgentLoginPrompt` keeps `.editorButtonSurface(.content)` outside, as `StateBanner` does; the inner glass surface wins when the card floats.
    - The sign-in card has no text field. Its only controls are `EditorButton`s in the action look, so on glass they take `.bordered`. The gallery images confirm this.
    - `AgentAuthView` has no seam to put a probe in place of its buttons, so the unit test reads the shared surface modifier with the probe of `StatusBarPlacementTests`.
    - The type doc of `AgentThreadView` still said that the banners of the top bar and the bottom bar have no glass (stale since ^0tqxfvx). I corrected it. README and ARCHITECTURE.md now name `.statusBarPlacementSurface(radius:)`.
  timestamp: 2026-11-23T20:03:47.500969+00:00
- actor: claude-code
  id: 01m85042engf1gc51y949bb0q2
  text: |-
    ### implement — changed
    - evidence: RED `swift test --filter StatusBarPlacementTests` failed to compile (no `statusBarPlacementSurface`); GREEN 5/5. Headless `swift test` in the root: 1657 tests in 187 suites + 59 tests in 12 suites passed, no code warnings. Hosted (one at a time, temp HOME): AgentAuthViewHostedTests 21 passed, ThreadBottomBarHostedTests 6 passed, ThreadBarBannerOverlapHostedTests 3 passed, ConnectionModelViewsHostedTests 10 passed, ThreadBarControlJumpHostedTests 6 passed. Gallery `swift test --package-path ScreenshotTests`: 45 tests in 4 suites passed. New images: ~/Library/Caches/AgentViewKit/screenshot-check/generated/GlassSnapshotTests/floating-sign-in-{light,dark}.png and floating-sign-in-reduce-transparency-{light,dark}.png. The card is on glass, the transcript does not show through, the buttons are bordered, and the glass is opaque under Reduce Transparency.
    - files: Sources/AgentViewKitStyle/Status/StatusBarPlacement.swift, Sources/AgentViewKitStyle/Status/StatusBar.swift, Sources/AgentViewKitStyle/AgentViewKitStyle.docc/AgentViewKitStyle.md, Sources/AgentViewKit/Connections/AgentAuthView.swift, Sources/AgentViewKit/Connections/AgentLoginPrompt.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Tests/AgentViewKitStyleTests/StatusBarPlacementTests.swift, ScreenshotTests/Tests/ScreenshotTests/FloatingNoteGalleryFixtures.swift, ScreenshotTests/Tests/ScreenshotTests/GlassSnapshotTests.swift, Docs/decisions/visual-audit.md, README.md, ARCHITECTURE.md
    - next: /review
  timestamp: 2026-11-23T20:03:55.477446+00:00
position_column: doing
position_ordinal: '80'
title: Decide if the sign-in card in the bottom bar of a thread gets the glass of the floating notes (D213 follow-up)
---
## What
After ^d213 work (card 01M84XDXE210R4P62QE0TQXFVX), the status notes of the top bar and the bottom bar of `AgentThreadView` are on the floating glass of the kit (`.statusBarPlacement(.floating)`). The sign-in card (`AgentLoginPrompt`, an `AgentAuthView`) also floats over the transcript in the bottom bar (`Sources/AgentViewKit/Connections/AgentLoginPrompt.swift`), but it is not a `StatusBar`, and D213 names only status notes. It still has no fill and no glass, so the transcript text can show through it, as it did through the notes.

## Decision
2026-11-23, from the TestudoApp session (this counts as the decision of the user): yes, `AgentLoginPrompt` gets the same glass as the floating status notes. The rule of D213 applies to each note that floats over content that scrolls under it. The names in D213 are examples only.

- [x] Ask the user if D213 also applies to the sign-in card.
- [x] Put the card on `.floatingGlass()` in the container of the bottom bar, and give its buttons the glass surface (bordered style), with a unit test first and a gallery screen.

## Acceptance Criteria
- In the bottom bar of a thread, the sign-in card is on the floating glass of the kit (EditorKit `.floatingGlass()`), the same glass as the floating status notes, in the one `FloatingGlassContainer` of the bottom bar. The card uses the mechanism of ^0tqxfvx (`StatusBarPlacement`, `.statusBarPlacement(.floating)`). The card does not make a material of its own.
- On that glass, the buttons of the card stand on the glass surface (`.editorButtonSurface(.glass)`), so they take the bordered style. No glass stands on glass.
- Out of the bottom bar (for example in the settings of a host), `AgentAuthView` stays content: no glass, and the separator edge (`.inlineEdge(radius:)`).
- The text of the transcript does not show through the sign-in card. Under Reduce Transparency, the glass is opaque.
- The docs of `AgentAuthView`, `AgentLoginPrompt`, `AgentThreadView` and `Docs/decisions/visual-audit.md` tell the new look.

## Tests
- Unit test first (headless `swift test`): a floating card on the shared surface `.statusBarPlacementSurface(radius:)` (the surface that `AgentAuthView` and `StatusBar` both use) stands its buttons on the glass surface, and a card in content stands its buttons on the content surface. `AgentAuthView` has no seam for a probe in place of its buttons, so the test reads the shared surface with the probe of `StatusBarPlacementTests`.
- Hosted tests with `--filter`: `AgentAuthViewHostedTests`, `ThreadBottomBarHostedTests`.
- Gallery screen: a thread scrolled away from the bottom, with transcript text under the sign-in card, in the light look, the dark look and with Reduce Transparency.

#d213