---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m86psvj7qw68kggzbwmj6k3x
  text: |-
    ### Cause found: cause 2 (the anchors are pinned, but the hidden button draws)
    - Evidence 1: a headless probe mounted a short thread as `AnswerTextHitTests.mountAnswer()` does (borderless window, never ordered in). After layout, `anchors.isPinnedToBottom == true` and `newItemsSinceUnpinned == 0`. Thus cause 1 is false.
    - Evidence 2: `cacheDisplay(in:to:)` of that host draws the gray label "Scroll to Bottom" at x 252...367 pt, the same place as in `thread-light.png`. The platform views of the pill have alpha 0 and a frame at x 240 (the center of the pill, because of `.scaleEffect(0)`), with the full size 139 x 24. The label starts at that center point, which agrees with the gallery images.
    - Evidence 3: probes of `ScrollToBottomPill` alone. Out of a glass container, `.opacity(0)` and `.scaleEffect(0)` each hide the label (0 drawn pixels). In a `FloatingGlassContainer` or a raw `GlassEffectContainer`, these do NOT hide the label: `.opacity(0)`, `.scaleEffect(0)`, `.compositingGroup().opacity(0)`, `.geometryGroup().opacity(0)`, `.visualEffect { $0.opacity(0) }`, `.mask(Color.clear)`, `.clipShape(zero rect)`, `.blur`, `.blendMode(.destinationOut)`, `.foregroundStyle(.clear)`, `.labelsVisibility(.hidden)`, `.labelStyle(.iconOnly)`, and an opacity on an overlay host around the pill. Only `.hidden()` (no Bool form; a conditional changes the identity of the button) and a NESTED `GlassEffectContainer` with the opacity outside it hide the label.
    - Conclusion: the `GlassEffectContainer` draws the label of a `.glass` button (EditorButton action look on the content surface) itself, and it does not apply the opacity or the scale of the views between the container and the button. The glass capsule hides (the gallery shows no capsule), but the label stays.

    ### Fix (in the tree, not committed)
    - `ConversationPill` puts `ConversationPillButton` in its own `GlassEffectContainer`, and applies the opacity, scale, hit test, accessibility, disabled and targetable modifiers to that container. The button stays in the tree (^ts5hyjr).
    - New test `Tests/AgentViewKitTests/Thread/ConversationPillDrawTests.swift`: `aPinnedPillDrawsNothingAboveTheComposer` (failed before the fix with `drawn == 0` false, passes after it) and the counter test `anUnpinnedPillDrawsItsLabel`. `AnswerTextHitTests` got a shared `mount(_:)` helper.
    - `swift test`: 1728 tests in 195 suites passed, and 59 tests in 12 suites passed; 0 warnings. `swift build --build-tests` in `IntegrationTests` and `ScreenshotTests` complete.
  timestamp: 2026-11-24T11:59:32.423441+00:00
- actor: claude-code
  id: 01m86pt1qxx54vg1xdyss9gt8m
  text: |-
    ### Blocker: the fix goes against 2 documented glass rules. A person must decide.
    - `plan.md` ("Glass only on floating controls"): "The kit makes no glass of its own, so it uses no `.glassEffect(`, `.glassEffectID(` or `GlassEffectContainer`." and "A container in a container makes no second container, so in `AgentThreadView` the state banner, the sign-in prompt, the pill and the composer slot share one container." The fix adds one raw `GlassEffectContainer` in `ConversationView.swift`, so the pill no longer shares the container of the composer.
    - EditorKit `style.md` rule 4: "Put adjacent glass elements in one `GlassEffectContainer`", and its Morphs rule names "the pill beside the composer".
    - Effect of the fix on the look: the glass of the shown pill does not blend or morph with the glass of the composer. Since ^ts5hyjr the pill never shows with an insert, so no morph ran before this fix either.
    - No hide that keeps one container was found (see the probe list in the comment above). `FloatingGlassContainer` cannot help: in a container it makes no second container.
    - Decision needed: (a) accept the own container for the pill, and update `plan.md` (D110 (c) text) and EditorKit `style.md` with this exception; or (b) add an API in EditorKit (for example, a hidden state of `EditorButton` or of `.floatingGlassID` that hides the label inside the glass) and use it in place of the own container.
    - The code comments in `ConversationView.swift`, `ScrollToBottomPill.swift` and `AgentThreadView.swift` already tell the own container. `plan.md` is not changed.
  timestamp: 2026-11-24T11:59:38.749387+00:00
- actor: claude-code
  id: 01m86pt4v4q4d1zja7jd0e3fg8
  text: |-
    ### implement — stuck
    - evidence: 5 files — Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Thread/ScrollToBottomPill.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Tests/AgentViewKitTests/Thread/ConversationPillDrawTests.swift (new), Tests/AgentViewKitTests/Thread/AnswerTextHitTests.swift; `swift test` 1728/195 + 59/12 passed, 0 warnings; build-tests of IntegrationTests and ScreenshotTests complete.
    - next: a person decides on the blocker (own glass container of the pill against plan.md and EditorKit style.md rule 4). Then the gallery run and the CI Integration job.
  timestamp: 2026-11-24T11:59:41.924111+00:00
- actor: claude-code
  id: 01m86sbqct6t74ysncbx6q44h7
  text: |-
    ### Blocker cleared: user decision
    - The user decided: "no glass of its own means not to re-implement glass". Thus a separate glass container for the pill is permitted.
    - I tried the EditorKit wrapper `FloatingGlassContainer` in place of the raw `GlassEffectContainer`. `aPinnedPillDrawsNothingAboveTheComposer` failed (`drawn == 0` false): in the container of the floating controls, a `FloatingGlassContainer` makes no second container, so the label draws again. Thus the pill keeps the raw SwiftUI `GlassEffectContainer`, and the comment of `ConversationPill` tells why.
    - `plan.md` now states the meaning in ASD-STE100: the "Glass only on floating controls" paragraph (the kit does not re-implement glass; the permitted glass APIs; the pill exception with the evidence of this card), the "Morphs (D113 answer 2)" paragraph (the pill does not morph with the composer), and the `AgentThreadView` entry (D110 (c): the button of the pill has its own container). The file line counts in that paragraph are still true (1 `FloatingGlassContainer` line in `PromptInputView.swift`, 2 in `AgentThreadView.swift`). No EditorKit file is changed.
  timestamp: 2026-11-24T12:44:15.130384+00:00
- actor: claude-code
  id: 01m86seetbm35mmhjbeh7w78j4
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Thread/ScrollToBottomPill.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, plan.md, Tests/AgentViewKitTests/Thread/ConversationPillDrawTests.swift (new), Tests/AgentViewKitTests/Thread/AnswerTextHitTests.swift; `swift build` 0 warnings; `swift test` 1728 tests / 195 suites and 59 tests / 12 suites passed, 0 warnings; `swift build --build-tests` complete in IntegrationTests and ScreenshotTests. Ticked 4/7 (unchanged): the gallery and CI items have no evidence yet.
    - next: /review; then the gallery run (thread-light.png, thread-external-composer-light.png, bottom-bar-buttons-light.png) and the CI Integration job (`ConversationPillMountHostedTests`).
  timestamp: 2026-11-24T12:45:44.651261+00:00
- actor: claude-code
  id: 01m86sr6a2sv3j4xpf9p3paj7z
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit b57c8c89): 0 findings, 0 confirmed, 0 refuted; 7 validator runs attempted, 0 failed. The engine reviewed 5 files. It did not review 6 `.kanban/` files (`.reviewignore`) and `plan.md` (no validator matches it).
    - next: the card stays in review. The gallery run and the CI Integration job (`ConversationPillMountHostedTests`) stay open until those runs occur. They are not findings.
  timestamp: 2026-11-24T12:51:03.618954+00:00
position_column: review
position_ordinal: '8480'
title: The gallery images show the Scroll to Bottom pill over a thread that is at the bottom
---
## What
The gallery run of 2026-11-24 05:37 (`HOME=<temp> swift test --package-path ScreenshotTests`, 46 tests passed) shows a gray "Scroll to Bottom" label above the composer in these images:
- `~/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/thread-light.png`
- `.../thread-external-composer-light.png`
- `.../bottom-bar-buttons-light.png`

Each transcript is short and shows its last row, so the pill must not show.

Since 3b88266a (^ts5hyjr), `ConversationPill` (`Sources/AgentViewKit/Thread/ConversationView.swift`) always shows `ConversationPillButton`, and it hides the button with `.opacity(0)`, `.scaleEffect(0)`, `.allowsHitTesting(false)`, `.accessibilityHidden(true)` and `.disabled(true)` while `anchors.isPinnedToBottom`. Before 3b88266a the pill showed only when `!anchors.isPinnedToBottom`.

Find which of these 2 causes is true, with a headless test:
1. `anchors.isPinnedToBottom` is `false` in the fixture after layout, so the pill shows. Then the old code also showed the pill: find why a short thread is not pinned.
2. `anchors.isPinnedToBottom` is `true`, but the hidden button still draws (the gray label is the disabled look). Then the hide does not work for this button (`ScrollToBottomPill` → `EditorButton` with `.floatingGlassAction(glassID:identifier:)` → `.floatingGlassID`, in the `FloatingGlassContainer` of the thread).

Fix it in SwiftUI (no AppKit rewrite). Keep the gains of ^ts5hyjr: the button stays in the tree, and `ConversationPillMountHostedTests` and its counter tests still pass.

## Acceptance Criteria
- [x] A headless test fails before the fix: a thread with a short transcript, mounted as `AnswerTextHitTests.mountAnswer()` does (window never ordered in), has no visible pill after layout (the pill is pinned-hidden and draws nothing, or is not shown).
- [x] The fix makes that test pass.
- [x] The next gallery run shows no pill in `thread-light.png`, `thread-external-composer-light.png` and `bottom-bar-buttons-light.png`.

## Tests
- [x] New headless test in `Tests/AgentViewKitTests/Thread/` (fails first).
- [x] `swift test` at the root: 0 failures, 0 warnings. `swift build --build-tests` in `IntegrationTests` and `ScreenshotTests` complete.
- [ ] CI Integration job: `ConversationPillMountHostedTests` green.
- [x] Gallery run when the screen is free (one windowed run at a time); give the PNG paths.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
#bug #scroll-perf