---
assignees:
- claude-code
position_column: todo
position_ordinal: b380
title: Find why ImageRenderer draws nothing when the first render of a process is AgentInfoHeader or PendingRequestCountBadge
---
Source: ^2g7w4mz (AVK-8aj) implement step.

Problem: when the first `ImageRenderer` render of the test process is `AgentInfoHeader` or `PendingRequestCountBadge`, these two views draw nothing in that render and in all later renders. A plain `Text` still draws. When the first render is a clear view, they draw. This happened the same way in each probe run. A clear warm-up render inside `RenderedPixels` did not prevent it.

Today `EditorThemeViewsTests.drawnPixels(of:)` renders a clear view first as a work-around. A render test that renders such a view first, with no clear render before it, can fail. The result of such a test depends on the order of the tests, and the test rules forbid this.

Do:
- Find the root cause (for example SF Symbol or font loading, the first `NSHostingView`, a `.symbolRenderingMode`, the `@Environment(\.editorTheme)` default, or the image scale of the first render).
- Fix it in one place, so each render gives the same result in any order: in `RenderedPixels` (Sources/AgentViewKitTestSupport/RenderedPixels.swift) or in the view if the view is wrong.
- Remove the work-around from `drawnPixels(of:)` if the fix makes it unnecessary.
- Do not add a retry, a sleep, a poll, a clock or a time limit.

Acceptance:
- A test that renders `AgentInfoHeader` as the first render of a new process draws pixels. Run it alone in a new process, with a filter, two times.
- 3 full `swift test` runs one after the other pass. #avk-8