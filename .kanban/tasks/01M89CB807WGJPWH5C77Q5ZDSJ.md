---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m89r2j9x5t6wwhyvg796nd4b
  text: |-
    Research and discoveries:
    - A size query of a row from the bar layout comes through `InsetViewLayout.sizeThatFits` and `primaryMinimum`, then `ScrollViewLayoutComputer`, then `LazyStack.measureEstimates`. A placement of the lazy stack also asks the rows for a size, and its call stack has `InsetViewLayout.childGeometry` (the place path of the bar). Thus the test counts only the queries whose call stack has the mangled name `15InsetViewLayoutV12sizeThatFits`.
    - The proposal does not tell the two queries apart: both propose (480, nil).
    - In a test window, a scroll step alone does not make the bar measure again: SwiftUI keeps the cached size. A row that changes its height on each step (as a real row does when its text gets its layout) makes the bar measure the scroll view again. The test does this with an observable row height.
    - A list that is pinned to the bottom goes back to the bottom after each clip move. The test unpins the anchors first.
    - `StyleViewHost.host` puts a fixed frame on the root, so the root does not measure its content. The test uses its own `NSHostingView` with no frame, in a borderless window that is never ordered in.
    - The Bash sandbox of this worktree refuses a command that sets HOME, so `swift test` runs with the normal HOME. The new tests do not touch home.
    - Mutation check: a `ProposalSizedLayout` that asks its child makes the bar test fail with 17 bar queries.
  timestamp: 2026-11-25T16:19:29.725848+00:00
- actor: claude-code
  id: 01m89r5g0pz4j6d1hv74a0mcxy
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Thread/ProposalSizedLayout.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/ProposalSizedLayoutTests.swift, Tests/AgentViewKitTests/Thread/SizeQueryProbe.swift, Tests/AgentViewKitTests/Thread/ThreadBarSizeQueryTests.swift
    - RED: bar test 17 bar queries; GREEN: 0.
    ### test — green
    - evidence: `swift test`: 1746 tests in 198 suites passed, 59 tests in 12 suites passed, 0 failures, 0 code warnings.
    ### commit — changed
    - evidence: 4ea3642f
    - next: review HEAD~1..HEAD. Hosted run of ThreadBarAccessibilityFrameHostedTests, the profile harness (case A) and the gallery images are not done: the dispatcher forbids windowed runs in this session.
  timestamp: 2026-11-25T16:21:05.686917+00:00
- actor: claude-code
  id: 01m89sj7ye7j24b79d4t1chyde
  text: |-
    ### review — clean
    - evidence: `review sha 4ea3642f~1..4ea3642f`: 0 findings, 1 refuted, 7 validators attempted. The review tool runs in the main checkout, so `HEAD~1..HEAD` there named a different commit; the sha of this worktree commit was used. In the main checkout the tool rules of code-hygiene could not read the new files, so `review file` with `validators: [code-hygiene]` ran on each of the 4 new files at their worktree paths: 0 findings each.
    - `swift build --package-path IntegrationTests --build-tests`: Build complete.
    - next: these runs are open, because the dispatcher forbids windowed runs in this session: (1) `ThreadBarAccessibilityFrameHostedTests` in IntegrationTests (tell testudoapp-9a before and after the run); (2) the scratch profile harness, case A, numbers on this card; (3) the gallery images of the thread (light, dark), after `swift package update` in each nested package.
    - Note: the window minimum size: with a flexible host in a borderless window, `contentMinSize` was (0, 0) before the change; the new layout also gives zero for its minimum.
  timestamp: 2026-11-25T16:45:31.982792+00:00
position_column: done
position_ordinal: ffffffffa980
title: 'Scroll perf 3: the safe-area bars do not measure the transcript on each frame'
---
User request (2026-11-25): "scrolling is still way too slow", stay with SwiftUI. The scroll profile found that `InsetViewLayout.primaryMinimum` (the SwiftUI layout of `.safeAreaBar`) asks the scroll view for its minimum size on each frame. It is 25.8% of main-thread time with no status line, and 45.5% with it. It is the source of 94% of `EditorView.sizeThatFits`, all the LazyVStack estimates, 92% of the `ViewThatFits` work and 84% of the `EditorLabelTextView` sizing.

## What

- The `.safeAreaBar` modifiers: `Sources/AgentViewKit/Thread/AgentThreadView.swift` (about lines 433 and 450) and `Sources/AgentViewKit/Thread/ConversationView.swift` (about line 316).
- [ ] Add a small SwiftUI `Layout` (for example `ProposalSizedLayout` in `Sources/AgentViewKit/Thread/`) that answers `sizeThatFits` from the proposal (the full proposed size, and zero for a `nil` or zero dimension), does not ask its child for a size, and places its child at its full bounds.
- [ ] Wrap the main content under each `.safeAreaBar` in it: the `ScrollView` of `ConversationView`, and the content of `AgentThreadView`.
- [ ] Keep the bar insets, the scroll edge effect, the pin to the bottom and the window minimum size the same.

## Acceptance Criteria

- [ ] During a scroll, the rows get no size query from the bars: a counting `Layout` probe in a row sees only its placements.
- [ ] The bar insets and the scroll edge effect do not change (the existing thread bar tests pass, and the gallery thread images show the same layout).

## Tests

- [ ] New test in `Tests/AgentViewKitTests/Thread/`: put a counting `Layout` probe in a row through an item view override (`Sources/AgentViewKit/Thread/ItemViewOverrides.swift`), mount `AgentThreadView` with a top and a bottom bar in a window that is never ordered in, move the clip by N steps with one `layoutSubtreeIfNeeded()` each, and expect no size query of the probe from the bar layout (count only the queries of the lazy stack).
- [ ] A test of `ProposalSizedLayout`: its size is the proposal, and it does not ask the child.
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings. Then run `ThreadBarAccessibilityFrameHostedTests` in IntegrationTests (tell testudoapp-9a before the hosted run and when it ends).

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- After the change, run the scratch profile harness again (case A) and add the numbers to the card. Gallery images (light, dark) of the thread for review; run `swift package update` in each nested package first. #perf