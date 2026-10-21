---
assignees:
- claude-code
position_column: todo
position_ordinal: b180
title: Fix the unstable test AgentSurfacesTests.theFloatingGlassIsTheSameForEachMaterialLevel(.clear)
---
Source: ^6dvspvv (AVK-8ac) implement step. The test came from ^sdkm4qt (AVK-8ad, commit ea259e1).

Problem: `AgentSurfacesTests.theFloatingGlassIsTheSameForEachMaterialLevel(level: .clear)` fails in some full `swift test` runs and passes in others. It passed in 2 of 4 full runs. It passes when it runs alone. A comparison with `RenderedPixels.isClose(to:)` also fails, so the difference is large. `agentFloatingGlass()` does not read `materialLevel`, so the two renders are of the same view. The result probably depends on the order of the parallel tests (glass rendering in `ImageRenderer` depends on process state, see ^dbbyg9w: glass draws only after the first `NSHostingView`).

The test rules forbid a test that is not stable: a test must give the same result in each run.

Do:
- Find the root cause. Do not add a retry, a sleep, a poll, a clock or a time limit.
- Make the test deterministic, for example: render both images in the same state, in one serial test, or make the render helper set the same process state before each render.
- If the comparison cannot be made deterministic, replace it with a check that is deterministic and that still fails when the glass reads `materialLevel` (for example a source scan or a value check).

Acceptance:
- The test passes in 5 full `swift test` runs one after the other, and when it runs alone.
- With `agentFloatingGlass()` changed for one run to read `materialLevel`, the test fails. #avk-8