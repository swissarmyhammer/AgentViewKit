---
assignees:
- claude-code
position_column: todo
position_ordinal: '8380'
title: 'Scroll perf 1: the status line text is one flat Text, with no ViewThatFits in layout'
---
User request (2026-11-25): "scrolling is still way too slow", stay with SwiftUI. The scroll profile (release, 120 Hz, 200 rows; traces in the session scratchpad, `A-mixed-tp.trace`) found that this is 48% of main-thread time during a scroll. With no status line, the median frame goes from 63–69 ms to 14–17 ms.

## What

- `Sources/AgentViewKit/StatusLine/StatusLineView.swift`:
  - `StatusLineText.body` (about line 275) nests `Text("\(text)\(styled(span))")` once for each span (a depth up to 17). SwiftUI parses it again (`LocalizedStringKey.scan`) on each layout pass.
  - `StatusLinePieceText.body` (about line 257) puts each form in a `ViewThatFits`. The safe-area minimum-size query and the window size constraints run it on each frame.
- [ ] Build one `AttributedString` for each span set, one time (a memo on the spans and the theme colors), and show one `Text(attributedString)`. Keep the styles, the colors and the accessibility text the same.
- [ ] Choose the form from the measured width: read the width with `onGeometryChange(for:)`, keep the measured width of each form (one hidden measure each time the spans change), and show only the widest form that fits. No `ViewThatFits`.
- [ ] Keep the truncation forms of `piece.narrowerSpans` as they are now.

## Acceptance Criteria

- [ ] During a scroll with no change to the status line, `StatusLineText` builds no new text (counter stays 0).
- [ ] The status line shows the same forms at the same widths as before (the existing status line tests pass with no change).

## Tests

- [ ] New counter test in `Tests/AgentViewKitTests/StatusLine/` (use `BodyEvaluationCounter` or a package counter in the text build): mount `AgentThreadView` with a status line in a window that is never ordered in (the `mount(_:)` pattern of `Tests/AgentViewKitTests/Thread/AnswerTextHitTests.swift`), lay out, move the scroll view clip by N steps with one `layoutSubtreeIfNeeded()` per step, and expect 0 new text builds.
- [ ] A test of the form choice: for 3 widths, the shown form is the widest that fits.
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings. No source-scan test.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- After the change, run the scratch profile harness again (`scratchpad/ScrollProfile`, case A) and add the new frame-time numbers to the card. Gallery images (light, dark) of the status line for review. #perf