---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dv36j36v0f04d5618escy5
  text: |-
    Implementation landed.

    - `PromptInputView.body` is now one `GlassEffectContainer(spacing: theme.spacing.s)` with a VStack of two siblings: the field and the accessory. `.disabled`, `.attachmentDropDestination` and the two environment values stay on the whole composer.
    - The field (chips + editor) is a private `field(_:)` builder with the new internal modifier `PromptFieldSurface` (in `PromptInputView.swift`). It adds the medium padding, `.agentFloatingGlass()`, `.accessibilityElement(children: .contain)` and the identifier `prompt-field-surface` (`PromptFieldSurface.identifier`). The identifier is on a non-generic type because a generic type (`PromptInputView<Editor, Accessory>`) cannot hold a static stored property.
    - `DefaultPromptAccessory`, `SuggestionsView` and `SpeechInputButton` did not change. Their buttons keep `.glass` / `.glassProminent`.
    - Reduce Motion: the composer writes no `glassEffectID`, so it adds no glass morph in any mode. A structure test holds this.
    - The composer no longer has the outer padding inside one glass; the padding is now on the field only.

    Tests:
    - `PromptInputViewHostedTests.theSubmitButtonIsOutsideTheGlassOfTheField`: the frames of `prompt-submit` and `prompt-field-surface` do not intersect.
    - `PromptInputGlassTests.theFieldSurfaceFollowsReduceTransparency` (method of ^dbbyg9w): `PromptFieldSurface` over the backdrop in a container gives different pixels with Reduce Transparency on and off. I saw it fail with `.agentFloatingGlass()` removed.
    - `PackageStructureTests/ComposerGlassStructureTests`: `PromptInputView.swift` has one `GlassEffectContainer(`, one `.agentFloatingGlass()`, no `.glassEffect(` and no `.glassEffectID(` on code lines.

    What did not work: a pixel test of the full composer (backdrop shows behind the accessory). `ImageRenderer` does not draw the composer: `.onPasteCommand` in `attachmentDropDestination` makes it focusable, and the full composer area came out as a non-backdrop color, also 100 pt below the field. A probe without the composer showed that `agentFloatingGlass` in a container ends at the edge of its view. The window cache shows no glass. Thus the hosted frame test is the check that the accessory is outside the field glass.
  timestamp: 2026-10-20T23:42:08.451258+00:00
- actor: claude-code
  id: 01m5dv3qzbzrkg1zfn88jv8t7p
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Input/PromptInputView.swift, Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift, Tests/AgentViewKitTests/Input/PromptInputGlassTests.swift (new), Tests/PackageStructureTests/ComposerGlassStructureTests.swift (new). `swift test`: 1410 tests in 172 suites passed with 2 known issues, 141 tests in 20 suites passed, 1 test passed. The mlx bundle warning existed before.
    - next: /review
  timestamp: 2026-10-20T23:42:26.283473+00:00
- actor: claude-code
  id: 01m5dvg7tjp1pe9v2rh06283ch
  text: |-
    ### test — green
    - evidence: swift test — 1413 tests in 172 suites passed, 2 known issues (before this change), 0 new warnings. First run: 1 failure, theContentSurfaceHasNoGlassThatFollowsReduceTransparency (on == off). 28 anti-aliased edge pixels differed by one level between two renders.
    - fix: added RenderedPixels.isClose(to:tolerance:) in Sources/AgentViewKitTestSupport/RenderedPixels.swift, with 3 tests in RenderedPixelsTests. AgentSurfacesTests now uses isClose. No clock, sleep, poll or retry.
    - next: review
  timestamp: 2026-10-20T23:49:15.730711+00:00
- actor: claude-code
  id: 01m5dvkgsz4aa3jn8c32ycsmsf
  text: |-
    ### review — findings
    - evidence: review sha HEAD~2..HEAD (9c9406c, 92d01f5). 1 finding (1 confirmed, 1 refuted). Sources/AgentViewKitTestSupport/RenderedPixels.swift:164 `reuse/reuse`.
    - next: Do the open item in "Review Findings (2026-10-20 18:49)". Put the per-component tolerance comparison in one private helper and call it from isClose(to:tolerance:) and pixel(atOffset:matches:tolerance:). Then review again.
  timestamp: 2026-10-20T23:51:03.231336+00:00
- actor: claude-code
  id: 01m5dvm0jvr7tvf2hqz1vd3827
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 4 files
    - test: green — swift test, 1413 passed, 2 known issues that were there before (one fix: RenderedPixels.isClose for the content surface test)
    - commit: 9c9406c, 92d01f5
    - review: findings — Sources/AgentViewKitTestSupport/RenderedPixels.swift:164
  timestamp: 2026-10-20T23:51:19.387936+00:00
- actor: claude-code
  id: 01m5dvsk7es0br8fh60p62f4bf
  text: 'Fix for the finding `RenderedPixels.swift` `reuse/reuse`. The file had two copies of the cause: the byte normalization (`Double(byte) / componentMaximum`) and the tolerance comparison (`abs(a - b) <= tolerance`). Both copies were in isClose(to:tolerance:) and in pixel(atOffset:matches:tolerance:). Now two private static helpers hold them: `component(_:)` and `isWithin(_:_:tolerance:)`. Both methods call the two helpers. `abs(` and `/ componentMaximum` now occur one time each in the file. The behavior did not change, so the existing RenderedPixelsTests cover it. I added no new test.'
  timestamp: 2026-10-20T23:54:22.318567+00:00
- actor: claude-code
  id: 01m5dvsmqk9aykb2pdam58s6ss
  text: |-
    ### implement — changed
    - evidence: 1 file — Sources/AgentViewKitTestSupport/RenderedPixels.swift. `swift test`: 1413 tests in 172 suites passed with 2 known issues, 141 tests in 20 suites passed, 1 test passed. The 2 known issues and the mlx bundle warning existed before.
    - next: /review
  timestamp: 2026-10-20T23:54:23.859374+00:00
- actor: claude-code
  id: 01m5dw25dv3kh1qz81t4fjwn41
  text: |-
    ### test — green
    - evidence: swift test — 1413 tests in 172 suites passed, 0 failed, 0 skipped, 2 known issues (existed before). Build warnings: only the known mlx bundle warning.
    - next: review
  timestamp: 2026-10-20T23:59:03.099343+00:00
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
position_column: doing
position_ordinal: '80'
title: 'AVK-8i Composer: put the field and the accessory cluster in one GlassEffectContainer, with no glass on glass'
---
## Why

D110 (c). The composer is a floating control, so it can use glass. Today `PromptInputView` puts one `.glassEffect` on the whole VStack (chips, editor and accessory). The accessory buttons (Send, Stop, dictation, suggestion chips) use the `.glass` and `.glassProminent` styles inside that glass. That is glass on glass. There is no `GlassEffectContainer` in the kit today.

## Files

- `Sources/AgentViewKit/Input/PromptInputView.swift` body, about lines 167-195. Line 189: `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`.
- `Sources/AgentViewKit/Input/DefaultPromptAccessory.swift` body, about lines 61-80 (suggestions at line 64, the button row with `SpeechInputButton` at 73, Stop, Send).
- No change in `Input/SuggestionsView.swift` line 52 and `Input/SpeechInputButton.swift` line 67. They keep `.buttonStyle(.glass)`.

## What to do

- [x] Wrap the body of `PromptInputView` in `GlassEffectContainer(spacing: theme.spacing.s)`.
- [x] Put `agentFloatingGlass()` (AVK-8b) on the field only: the attachment chips and the editor.
- [x] Put the accessory below the field, as a sibling in the container, not inside the field glass. Its buttons keep their glass button styles. The container blends the shapes.
- [x] Give the field surface an accessibility identifier, for example `prompt-field-surface`, so a hosted test can read its frame.
- [x] Keep `.disabled(isSessionClosed)`, the drop destination and the environment values on the whole composer.
- [x] With Reduce Motion on, add no glass morph (plan.md §6).

## Acceptance

- `PromptInputView.swift` has one `GlassEffectContainer` and no direct `.glassEffect` call. The field uses `agentFloatingGlass()`.
- A hosted test (`HostedViewHarness`) shows `PromptInputView` with `DefaultPromptAccessory`. The frame of the submit button (`prompt-submit`) does not intersect the frame of `prompt-field-surface`.
- All tests in `Tests/AgentViewKitTests/Input/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. After each key press, the test waits for its result before the next step. #avk-8

## Review Findings (2026-10-20 18:49)

> Scope: `review sha HEAD~2..HEAD` — reviewed the diffs only — lines this change added or modified. 7 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKitTestSupport/RenderedPixels.swift:164` `reuse/reuse` — The new isClose(to:tolerance:) repeats the per-component tolerance check that the private pixel(atOffset:matches:tolerance:) already does. It normalizes each byte by componentMaximum and compares the difference with tolerance. A change to the tolerance rule must then be made in two places. Move the component comparison into one private helper, for example `isWithin(_ a: Double, _ b: Double, tolerance: Double) -> Bool`. Call it from both isClose(to:tolerance:) and pixel(atOffset:matches:tolerance:).
