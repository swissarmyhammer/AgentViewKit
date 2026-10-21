---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5fed49v0rjwcnxbm8cmxwzt
  text: |-
    Research and implementation:
    - Search of Tests/ for the on/off render and compare pattern found two tests that expect different pixels: AgentSurfacesTests.theFloatingGlassFollowsReduceTransparency (at insidePoints, size 80) and GlassRenderProbeTests.theGlassFollowsTheSetting (each pixel, `on != off`, for each GlassProbeSetting). PromptInputGlassTests already calls the helper. The ContentEdgeHostedProbe tests do not compare on and off renders; they check the backdrop for each value.
    - Both tests now call `GlassRenderProbeTests.expectDifferentPixels`. The floating glass test keeps insidePoints and Self.size.
    - The helper `points` parameter is now `[CGPoint]? = nil`. With `nil`, the helper compares each pixel with `isClose(to:)`. Thus theGlassFollowsTheSetting keeps the full-image compare. Note: the compare changed from exact `!=` to `!isClose` with the default tolerance. This is stronger: the renders must differ by more than the tolerance at one pixel or more, so each mutation that fails `!=` also fails this.
    - theContentEdgeHasNoGlassThatFollowsReduceTransparency is the only test that expects the SAME on/off renders. Only one test needs a "same" check, so no shared "same" helper was added (the instruction: add it only when two or more tests need it). It keeps its own compare.
    - Mutation check: a first mutation (`.environment(\._accessibilityReduceTransparency, false)` after `.glassEffect` in AgentFloatingGlass) did NOT change the render, and the test passed. Discovery: inside a GlassEffectContainer, the container draws the glass with the environment of the container, so an environment value on the glass view has no effect. A second mutation wrapped the glass in its own GlassEffectContainer with Reduce Transparency forced off. Then theFloatingGlassFollowsReduceTransparency failed at AgentSurfacesTests.swift:169 ("Expectation failed: !isSame"); the failure report points to the caller, so `sourceLocation` works. The source was put back; git diff shows no change in Sources/.
    - Full `swift test`: 1488 tests in 187 suites passed, 2 known issues (the deliberate withKnownIssue self-tests in HostedLayoutExpectationsTests and ThemeHeightExpectationsTests). The XCTest part ran 0 tests. The one build warning is the SwiftPM "missing creator for mutated node" warning for the mlx-swift bundle; it is not from source code.
  timestamp: 2026-10-21T14:38:51.195774+00:00
- actor: claude-code
  id: 01m5fed6dqtbrh7dzzm906c6tf
  text: |-
    ### implement — changed
    - evidence: 2 files — Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift, Tests/AgentViewKitTests/Theme/GlassRenderProbeTests.swift. Mutation check: the floating glass in its own GlassEffectContainer with Reduce Transparency off made theFloatingGlassFollowsReduceTransparency fail; source put back. `swift test`: 1488 tests in 187 suites passed, 2 known issues (deliberate).
    - next: /review
  timestamp: 2026-10-21T14:38:53.367953+00:00
- actor: claude-code
  id: 01m5fek31m0v601db8557wwa8m
  text: |-
    ### test - green
    - evidence: `swift test` ran one time. 1488 tests in 187 suites passed in 96.9 s (148 s wall time), 0 failures, 0 skipped, 2 known issues (they existed before).
    - warnings: 1 warning only. It is the mlx bundle build warning (it existed before). No new warning.
    - suites: ReadmeSnippetTests, ReadmeCoverageTests, PackageFilesTests, ThreadBottomBarStructureTests, ThreadTopBarStructureTests and ComposerGlassStructureTests ran and passed. The ReadmeSnippetsTests target only compiles the snippets, and it built.
    - next: review.
  timestamp: 2026-10-21T14:42:06.516044+00:00
position_column: doing
position_ordinal: '80'
title: Use the shared Reduce Transparency check in AgentSurfacesTests
---
Source: the review of ^a21et0q (commit 7f5da21), finding at Tests/AgentViewKitTests/Input/PromptInputGlassTests.swift:39 (`duplication/duplication`). The finding asks to report the existing copies in AgentSurfacesTests.swift as a separate task.

Problem: tests in Tests/AgentViewKitTests/Theme/AgentSurfacesTests.swift render a view with Reduce Transparency on and off, then check that the pixels differ at a point or at the inside points. ^a21et0q adds one shared helper for this check (in GlassRenderProbeTests or a shared place). The copies in AgentSurfacesTests can drift from that helper.

Do:
- Make each such test in AgentSurfacesTests call the shared helper. Keep each test's points and its mutation strength.
- Search the rest of the test target for the same pattern and use the helper there too.

Acceptance:
- No test in the target repeats the on/off render and compare logic; each calls the shared helper.
- Full `swift test` passes. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8