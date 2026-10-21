---
assignees:
- claude-code
position_column: todo
position_ordinal: b380
title: Make the Reduce Transparency glass test compare the inside of the glass only
---
Source: ^ffhv52w (the unstable glass test fix).

Problem: `AgentSurfacesTests.theFloatingGlassFollowsReduceTransparency` expects two renders to differ (`on != off`). In one process, `ImageRenderer` draws the edge of a rounded glass differently after its first renders, and the render where this happens is not the same in each run (see the doc comment of `RenderedPixels.isClose(to:at:tolerance:)`). Thus the two renders can differ only at the edge, and the test can pass even when the setting has no effect on the glass.

Do:
- Compare the two renders only at points far from the edge, with `RenderedPixels.isClose(to:at:tolerance:)` (for example `AgentSurfacesTests.insidePoints`), and expect that they are NOT close.
- Search the other glass tests (GlassRenderProbeTests, PromptInputGlassTests, RequestDeckSurfaceTests and others) for the same pattern `!=` or `isClose` on a full render of rounded glass, and fix each one the same way.

Acceptance:
- With the glass changed for one run so that it ignores Reduce Transparency, the test fails. Then put the code back.
- 3 full `swift test` runs one after the other pass.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8