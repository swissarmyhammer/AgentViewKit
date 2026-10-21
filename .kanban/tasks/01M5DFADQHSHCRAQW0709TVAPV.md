---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dfdwhe8yrf84h1z4a40y0b
  text: |-
    ### decision (testudoapp-4c, AVK-8 "Decisions for the plan")
    - Add a composer slot on `AgentThreadView`, with `PromptInputView` as the default. Put the pill and the composer in one `GlassEffectContainer`. The composer stays directly below its chat (D36).
    - D108 and D109: each new control is an EditorKit command that the palette shows.
  timestamp: 2026-10-20T20:18:15.726955+00:00
- actor: claude-code
  id: 01m5dxxmksced1ymccgje66x1r
  text: |-
    ### research
    - The pill is an overlay of the list in `ConversationView` (`ConversationPill`, private). The composer has its own `GlassEffectContainer` in `PromptInputView.body`. Only that file makes a container in the kit.
    - `AgentThreadView` is not generic. It keeps its `ScrollAnchorManager` in private state. A static func `inspectorSelection(host:own:)` is on the type, and `AttachmentInspectorHostedTests` calls it. A generic type cannot hold a stored static property, so the new identifier goes in a separate enum.
    - The commands exist: `AgentCommandVerb.scrollToBottom` runs `anchors.pinToBottom()`, as the pill does. `focusComposer` and `send` cover the composer. This card adds no new action, so no new command is necessary (D108, D109).
    - A jump command (`jumpToPrevious`) needs `visibleIDs.first`. The off-screen harness window can send no visibility report on mount, so a test must give the thread view a manager that it can give a report to.
    - Many hosted tests put `PromptInputHost` next to `AgentThreadView`. With a default composer in the slot, those tests get two composers, so they move their composer into the slot.
    - The demo app (`Examples/AgentViewKitDemo`, `SessionThreadColumn`) is an Xcode project. `swift test` does not build it.
    - Plan: (1) `AgentThreadView<Composer>` with `init(session:connection:composer:)`, and `init(session:connection:)` with `DefaultThreadComposer` (a `PromptInputView` with its own draft). (2) A shared `FloatingGlassContainer` that makes a `GlassEffectContainer` only when no outer one is in the environment, so the composer in the thread does not nest a container. (3) The thread view puts the pill and the slot in one container in `.safeAreaBar(edge: .bottom)`, with the identifier `AgentThreadLayout.floatingControlsIdentifier`. `ConversationView` in the thread draws no pill; a `ConversationView` alone keeps `ConversationPill`.
  timestamp: 2026-10-21T00:31:31.961379+00:00
- actor: claude-code
  id: 01m5dz3xp83d2g3491kw512zzm
  text: |-
    ### implementation
    - `AgentThreadView` is now `AgentThreadView<Composer: View>`. New public `init(session:connection:composer:)`. `init(session:connection:)` stays source compatible: it uses the new public `DefaultThreadComposer` (a `PromptInputView` with its own draft). An internal `init(session:connection:anchors:composer:)` lets a hosted test give the `ScrollAnchorManager`.
    - The thread view puts `ConversationPill` (now internal) and the slot in one container in `.safeAreaBar(edge: .bottom)`, with the accessibility container `AgentThreadLayout.floatingControlsIdentifier` ("thread-floating-controls"). It gives the slot `\.sessionModel` and `\.connectionModel`. The slot is in the focus scope and the agent command scope of the thread. `ConversationView` reads the internal `\.conversationShowsPill`; the thread view sets it to false. A `ConversationView` alone keeps its overlay pill.
    - Nested container: the new internal `FloatingGlassContainer` (Theme/FloatingGlassContainer.swift) is the only place that makes a `GlassEffectContainer`. In a container it makes none (`\.floatingGlassContainerCount`). `PromptInputView` uses it, so a composer alone has its own container, and a composer in the thread uses the container of the thread.
    - No new action, so no new command: the pill is `AgentCommandVerb.scrollToBottom`, the composer is `send` and `focusComposer` (D108, D109).
    - Limit: the list does not scroll under the bar, because `StateBanner` (and `AgentLoginPrompt`) are between the list and the bar. The bar is a safe area bar of the thread content.
    - Test support: `HostedViewHarness.elements(under:)` reads the elements under a container.
    - Tests that put a composer next to the thread view now put it in the slot (AgentCommandScope, ComposerSessionModel, SessionStateBanners, GalleryWindowReplica). `AgentThreadView.inspectorSelection` calls name `AgentThreadView<DefaultThreadComposer>`.
    - Docs: README quick start and component bullet, the ACPQuickStart snippet (regenerated), the `RequestDeck` and `PromptInputView` docs, plan.md §9. The demo `SessionThreadColumn` puts the usage, the deck and the composer in the slot; the demo builds with `xcodebuild -skipMacroValidation -skipPackagePluginValidation build -scheme AgentViewKitDemo` (BUILD SUCCEEDED).
    - Card description: the subtasks are checked, and the first one names the change of the default that the decision made.
    - What did not work: a test that checked the pin state right after a press on the pill failed. The pill goes away, the bar gets shorter, and the geometry change sends the old rows again. The test now waits for the `.bottom` scroll target, as `ConversationViewHostedTests` does.
  timestamp: 2026-10-21T00:52:26.440920+00:00
- actor: claude-code
  id: 01m5dz42wy7dqvj1xhh3d07g9x
  text: |-
    ### implement — changed
    - evidence: `swift test` — 1435 tests in 176 suites passed, 2 known issues (existed before), mlx bundle warning only. `Scripts/check-readme.sh` passed. Demo app BUILD SUCCEEDED. New files: Sources/AgentViewKit/Theme/FloatingGlassContainer.swift, Sources/AgentViewKit/Input/DefaultThreadComposer.swift, Tests/AgentViewKitTests/Thread/ThreadFloatingControlsHostedTests.swift, Tests/AgentViewKitTests/Theme/FloatingGlassContainerHostedTests.swift. Changed: AgentThreadView.swift, ConversationView.swift, PromptInputView.swift, RequestDeck.swift, HostedViewHarness.swift, README.md, plan.md, ACPQuickStart.swift snippet, demo SessionThreadColumn.swift, and the tests named in the implementation comment.
    - next: /review
  timestamp: 2026-10-21T00:52:31.774448+00:00
- actor: claude-code
  id: 01m5dz98h2msfcv6z2adzsa0dc
  text: |-
    ### test - green
    - evidence: swift test - 1435 tests in 176 suites passed, 0 failed, 0 skipped, 2 known issues (old). PackageStructureTests: 146 tests in 20 suites passed. ReadmeSnippetsTests: 1 test passed. One warning only: the old mlx bundle build warning.
    - next: review
  timestamp: 2026-10-21T00:55:21.378294+00:00
- actor: claude-code
  id: 01m5dzdxy14b702phmxz1jqpwn
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (5b6336c). 1 finding: Sources/AgentViewKit/Input/DefaultThreadComposer.swift:13 code-hygiene/dead-code-swift — var.instance `draft` is unused.
    - next: Correct the finding in the "Review Findings (2026-10-20 19:55)" section. The task stays in review.
  timestamp: 2026-10-21T00:57:54.369139+00:00
- actor: claude-code
  id: 01m5dzefv8v7fnmr68q6t0kf4q
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 22 files
    - test: green — swift test, 1435 passed, 2 known issues that were there before; 146 structure tests and 1 README snippet test passed
    - commit: 5b6336c
    - review: findings — Sources/AgentViewKit/Input/DefaultThreadComposer.swift:13
  timestamp: 2026-10-21T00:58:12.712688+00:00
- actor: claude-code
  id: 01m5e1kg8d1s5qharvncp9htxc
  text: |-
    ### finding fix — dead-code-swift `draft`
    - Cause: `draft` was used only through its projected value (`$draft`). Periphery 3.8.0 records the `$draft` use as a use of the projection, not of `draft`, so it reported `draft` as unused. `PromptInputView.ownAttachments` uses the same kind of state with a plain `Binding(get:set:)`, and periphery does not report it.
    - Change: `DefaultThreadComposer` now gives `PromptInputView` a private computed `text` binding that reads and writes `draft` directly (`Binding(get: { draft }, set: { draft = $0 })`). The composer still keeps its own text. The public API does not change. No other `$` projection is in the file.
    - RED: `periphery scan --skip-build --index-store-path .build/out --retain-public --retain-objc-accessible --retain-swift-ui-previews --retain-codable-properties --relative-results --report-exclude "Tests/**"` after `swift build --build-tests` reported `DefaultThreadComposer.swift:13:22: warning: Unused property 'draft'`. GREEN: the same scan reports nothing for the file.
    - What did not work: the first `swift test` run in the sah shell, piped to `rg | head`, gave no result for 30 minutes and the shell tool stopped. A second run with the output in a file ended normally in 138 s. Run the full suite with the output to a file.
  timestamp: 2026-10-21T01:35:54.125110+00:00
- actor: claude-code
  id: 01m5e1kj4e39mh2zqhzc3nayfq
  text: |-
    ### implement — changed
    - evidence: 1 file — Sources/AgentViewKit/Input/DefaultThreadComposer.swift. `swift test`: 1435 tests in 176 suites passed with 2 known issues (old); 146 tests in 20 suites passed; 1 test in 1 suite passed. One warning only: the old mlx bundle warning. Periphery reports nothing for the file.
    - next: /review
  timestamp: 2026-10-21T01:35:56.046849+00:00
- actor: claude-code
  id: 01m5e1vapkhmhhfastbry7z3pc
  text: |-
    ### test - green
    - evidence: swift test (output in scratchpad full.log), 220 s. XCTest: 0 tests, 0 failures. Swift Testing: 1435 tests in 176 suites passed, 2 known issues (existed before). 1 test in 1 suite (ReadmeSnippetsTests) passed. 146 tests in 20 suites passed.
    - warnings: only the mlx bundle build warning (existed before). No new warning. No skipped test. No hang.
    - changes: none to files.
    - next: review
  timestamp: 2026-10-21T01:40:10.579653+00:00
- actor: claude-code
  id: 01m5e1xcf5gvyyztaa3y6gk2d6
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (eddd08a). 0 findings, 0 confirmed, 0 refuted. 7 validator runs, 0 failed. The prior finding at `Sources/AgentViewKit/Input/DefaultThreadComposer.swift:13` is checked.
    - next: The task moved to done.
  timestamp: 2026-10-21T01:41:17.925502+00:00
- actor: claude-code
  id: 01m5e1xwqpwzx39zfwwpp8t1kj
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — 1 file (DefaultThreadComposer uses `draft` directly)
    - test: green — swift test, 1435 passed, 2 known issues that were there before
    - commit: eddd08a
    - review: clean — 0 findings, the prior finding is checked
  timestamp: 2026-10-21T01:41:34.582728+00:00
depends_on:
- 01M5DF9SKZ4BRGBD6BFG5XY664
position_column: done
position_ordinal: ffff8480
title: AVK-8l Put the scroll-to-bottom pill and the composer in one GlassEffectContainer
---
## Why

AVK-8 asks for one `GlassEffectContainer` for the composer bar, its accessory cluster, the suggestions and the scroll-to-bottom pill. Today these are in two separate view trees:

- The pill is an overlay of the list in `ConversationView` (`Sources/AgentViewKit/Thread/ConversationView.swift`, `ConversationPill`). It uses `.buttonStyle(.glass)` (`Thread/ScrollToBottomPill.swift`).
- The composer (`PromptInputView`) is not in `AgentThreadView` (`Thread/AgentThreadView.swift`). The host puts it below the thread.

So no single kit view can hold both in one container today.

## Decision needed first

Pick one method, and record it as a comment on this card:

1. **A composer slot on the thread view (recommended).** `AgentThreadView` gets an optional bottom slot for the composer. The thread view puts the slot and the pill in one `GlassEffectContainer` in a `.safeAreaBar(edge: .bottom)`, so the list scrolls under it. `ConversationView` does not draw its own pill when the thread view draws it.
2. **A public container view.** The kit gives a public view, for example `AgentFloatingControls`, that holds the pill and the composer. The host puts it in its layout.
3. **Two containers.** The pill keeps its own place. The rule changes to "one container for each group of floating controls". Change AVK-8 text in TestudoApp and in plan.md §5 to match.

Decision (testudoapp-4c, see the comment): method 1, with `PromptInputView` as the default composer.

## What to do (method 1)

- [x] Add the slot to `AgentThreadView`. The decision changes the default: the default slot is `DefaultThreadComposer` (a `PromptInputView` that keeps its own text). A host gives `EmptyView()` for no composer.
- [x] Move the pill into the container of the thread view. Keep `ConversationPill` for a `ConversationView` with no thread view.
- [x] Keep the pill identifier and its action (`anchors.pinToBottom()`).

## Acceptance

- With a composer in the slot, a hosted test scrolls up by a command (not by a timed gesture), waits for the pill to show, and finds the pill and `prompt-submit` in the same container: both are children of one element with a known identifier.
- With no composer, the pill shows as today, and all tests in `Tests/AgentViewKitTests/Thread/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8

## Review Findings (2026-10-20 19:55)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 18 file(s) reviewed, 4 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file
> - `plan.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Input/DefaultThreadComposer.swift:13` `code-hygiene/dead-code-swift` — var.instance `draft` is unused.
