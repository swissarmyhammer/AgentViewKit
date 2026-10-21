---
assignees:
- claude-code
position_column: todo
position_ordinal: b680
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