---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m84xmr7cvv4hmny9ddj4hbdg
  text: |-
    Research done.
    - The status line gets its glass from EditorKit `.floatingGlass()` (EditorStyle FloatingGlass.swift) in a `FloatingGlassContainer` (ThreadStatusHeader). The composer field uses `.floatingGlass(id:)` in the container of the bottom bar. No other glass material is in the kit. The notes reuse `.floatingGlass()`.
    - `StatusBar` is `.contentTile()` + `.inlineEdge(radius: radii.l)` + `.onChrome()`: no fill. The floating shape of `.floatingGlass()` is the same radius (radii.l).
    - EditorKit `\.buttonSurface` is public: the declared surface, else glass in a container. The banners declare `.content` (StateBanner) or infer it out of the container (top bar). A floating bar must declare `.glass` inside, so its button is bordered (no glass on glass).
    - Do not set the placement on the whole bottom bar: the request deck in the composer slot shows `NoticeRow` (a `StatusBar`) on the glass of the deck. That bar must stay content (no glass on glass). Set it only on `StateBanner` and on the banners of the top bar.
    - `ConversationView` alone also floats its `StateBanner` in a `.safeAreaBar(edge: .bottom)` over the list.
    - EditorKit style.md rule 4 (uncommitted peer edit, D213) says a floating note uses `.floatingGlass()`, and the system gives the opaque background under Reduce Transparency. Rule 9: no test flips a system setting; an environment value is permitted. SwiftUI has the settable `\._accessibilityReduceTransparency` key.
    - `Docs/decisions/` has no D110, D122 or D123 text. The note goes into `Docs/decisions/visual-audit.md` (the glass section) and ARCHITECTURE.md (the status bar of AgentViewKitStyle).
    - `AgentLoginPrompt` is a sign-in card (`AgentAuthView`), not a status note `StatusBar`; D213 names only status notes.
  timestamp: 2026-11-23T19:20:36.332673+00:00
- actor: claude-code
  id: 01m84yzcfnfn4038pd9d20kv71
  text: |-
    Implementation landed.
    - Public API for the host: `StatusBarPlacement` (`.content`, `.floating`) and `.statusBarPlacement(_:)` (AgentViewKitStyle). Testudo `AppNoticeBanners` applies `.statusBarPlacement(.floating)` on its `StatusBar`s, in the glass container of the composer or of the header where they touch. The default is `.content` (no glass).
    - `StatusBar` in `.floating`: `.floatingGlass()` of EditorStyle (the glass of the status line), no separator stroke, and `.editorButtonSurface(.glass)` inside, so its button is bordered (no glass on glass). This inner surface wins over the `.content` surface that the banners declare.
    - `AgentThreadView`: the top bar has one `FloatingGlassContainer` around the status line, the host header and the banners; the banners get `.floating`. The bottom bar: only `StateBanner` gets `.floating`, so `NoticeRow` on the glass of the request deck stays content. `ConversationView` alone puts its floating `StateBanner` in a container of its own.
    - RED: `StatusBarPlacementTests.aFloatingBarStandsItsButtonOnGlass` failed (surface `.content`) before the `StatusBar` change; GREEN after.
    - Discovery: on glass, the accessibility frame of the title element of a bar is the frame of the glass (the whole bar). `ThreadTopBarHostedTests.twoBannersStandOneTileMarginApart` read the title line and failed (gap -35). The test now reads the edge of each banner from that frame (gap = tile margin, 8). The dead helpers `explanationHeight`, `disconnectedExplanation`, `explanationMeasureWidth` and the unused `EditorSwiftUI` import are removed.
    - Discovery: SwiftUI glass follows the environment value `\._accessibilityReduceTransparency`. The Reduce Transparency screen shows opaque notes with no added fill, so the kit adds no fill of its own (EditorKit style.md rule 4).
    - Not changed: the sign-in card (`AgentLoginPrompt`) is not a status note. New card 01M84YYZVYH2QS3N0KSWHQM5BX asks the user if D213 applies to it.
    - Gallery PNGs: ~/Library/Caches/AgentViewKit/screenshot-check/generated/GlassSnapshotTests/floating-notes-{light,dark}.png and floating-notes-reduce-transparency-{light,dark}.png.
  timestamp: 2026-11-23T19:43:53.333462+00:00
- actor: claude-code
  id: 01m84yzf5gj71g3sxq58hn3454
  text: |-
    ### implement — changed
    - evidence: root `swift test` 1657 + 57 tests pass, no code warning; ScreenshotTests 44 tests pass (one run); hosted single suites pass: SessionStateBannersHostedTests 13, ThreadBarBannerOverlapHostedTests 3, ThreadTopBarHostedTests 5 (after the measure fix), ThreadBarAccessibilityFrameHostedTests 2, ThreadBottomBarHostedTests 6, ThreadFloatingControlsHostedTests 10, ConversationViewHostedTests 12, ThreadBarControlJumpHostedTests 6, StateBannerPendingRequestsHostedTests 7. 16 files changed.
    - next: /review
  timestamp: 2026-11-23T19:43:56.080660+00:00
- actor: claude-code
  id: 01m84z3gkex85sh0pvfn1pmd7m
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit aa609e3d): 0 findings, 0 confirmed, 0 refuted, 7 validator runs, 0 failed. 12 files reviewed. 4 Markdown files had no validator (ARCHITECTURE.md, Docs/decisions/visual-audit.md, README.md, AgentViewKitStyle.md). 6 .kanban files are ignored. The card has no prior review findings. Implement evidence: root `swift test` 1657 + 57 pass; 9 hosted suites pass one at a time; IntegrationTests build clean; ScreenshotTests gallery 44 pass; PNGs GlassSnapshotTests/floating-notes*.png.
    - next: none. The task moved to done.
  timestamp: 2026-11-23T19:46:08.622952+00:00
position_column: done
position_ordinal: ffffffff9780
title: The status notes that float over the transcript have the glass of the status line (TestudoApp D213)
---
## What
The Testudo user says: "the message where we show 'the agent is ready' in the chat is hovering above, and needs to be glass -- right now it is just transparent and blends together". TestudoApp decision D213 (`/Users/wballard/github/swissarmyhammer/TestudoApp/features/decisions.md`, row D213) records the rule. It changes D110 (b), D122 (c) and D123 for floating notes only. Testudo card 01M84XCWE0RH8SGJ0K8HB945V0.

Facts:
- Each note is a `StatusBar` (`Sources/AgentViewKitStyle/Status/StatusBar.swift`, near lines 251-256). It has only an edge line and no fill.
- In `Sources/AgentViewKit/Thread/AgentThreadView.swift` (near lines 458-530), only the status line and the composer have glass. The transcript scrolls under the notes (`SessionStreamBanner` in the top bar, `StateBanner` in the bottom bar), so its text shows through.

Work:
- [x] Each note that floats over the transcript (`StateBanner`, `SessionStreamBanner`, and the other banners of the top bar and the bottom bar) uses the same glass material as the status line. The glass is in one `GlassEffectContainer` with the composer or the status line where they touch. No glass on glass.
- [x] The text is readable over any content, in light and dark appearance. With Reduce Transparency, the note has an opaque background.
- [x] A status text that does not float (for example in a list or an inspector) keeps no glass. Thus the glass is a choice of the place, not of every `StatusBar`.
- [x] Give a public modifier or style that a host uses to match the look for its own floating notes (Testudo `AppNoticeBanners`). Report its name.
- [x] Gallery screens: transcript text under the top and the bottom notes, in light and dark, and one screen with Reduce Transparency.

## Acceptance Criteria
- [x] In the new gallery screens, transcript text under a note does not show through the note in light and dark appearance.
- [x] In the Reduce Transparency screen, the note background is opaque.
- [x] A `StatusBar` that does not float has no glass.
- [x] The public modifier or style exists, and the host can apply it.

## Tests
- [x] Unit test first (fails before the fix): a floating `StatusBar` gets the glass style, and a `StatusBar` that does not float gets none (for example, read an environment value or a style value with a slot probe, as `Tests/AgentViewKitTests/Thread/ThreadHeaderTests.swift` does).
- [x] `swift test` in the root: all pass, no code warnings.
- [x] `HOME=<temp> swift test --package-path ScreenshotTests`: all pass. Give the PNG paths of the new screens.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #d213