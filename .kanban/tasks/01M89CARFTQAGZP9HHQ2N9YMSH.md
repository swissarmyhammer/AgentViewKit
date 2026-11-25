---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m89qhanp1esgghah5hpztgs0
  text: |-
    Implementation notes (worktree branch worktree-agent-a586372dc589cfa65, commit 33aebfba).

    Discoveries:
    - SwiftUI `Text(AttributedString)` drops `NSTextAttachment` images (measured: "ab" + attachment has the same width as "ab"). Thus a span set with an SF Symbol or an icon cannot be one `Text(attributedString)`. Each sequence of text spans is one `AttributedString`, and the images join them in one flat `Text` (one interpolation level, not a depth of 17). A span set with no image is one `Text(attributedString)`. Bold and italic use `inlinePresentationIntent` (measured: the same widths as `.bold()` and `.italic()`).
    - `StatusLineFitTests` measure with `NSHostingController.sizeThatFits` and no layout pass, so no geometry callback runs. Thus a choice from state only cannot give the size. `StatusLineFormLayout` (a `Layout`) measures each form one time in its cache and gives the size of the widest form that fits. The view reads each form width and the part width with `onGeometryChange` and shows only that form (the others have opacity 0 and are hidden from VoiceOver).
    - The scroll counter test (`StatusLineScrollBuildTests`) passes also with no memo: a scroll in a window that is not ordered in does not evaluate the `StatusLineText` body again. Thus it cannot fail on that change. `StatusLineTextMemoTests` is the test that fails with no memo (checked: RED with no memo, GREEN with the memo).
    - The harness refuses `HOME=$(mktemp -d) swift test` in this worktree. The suite ran with no HOME change. The new tests do not touch home.
    - The kanban tool writes to the main checkout board, not to the worktree copy.

    Needs a run (not done here; the screen is shared): the scroll profile harness (`scratchpad/ScrollProfile`, case A) for the new frame times, and the gallery images (light, dark) of the status line.
  timestamp: 2026-11-25T16:10:04.854360+00:00
- actor: claude-code
  id: 01m89qhde1w3k44467qn4t26r7
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/StatusLine/StatusLineView.swift, Tests/AgentViewKitTests/StatusLine/StatusLineFormChoiceTests.swift, Tests/AgentViewKitTests/StatusLine/StatusLineScrollBuildTests.swift, Tests/AgentViewKitTests/StatusLine/StatusLineTextMemoTests.swift
    - next: test

    ### test — green
    - evidence: swift test: 1747 tests in 199 suites passed, 59 tests in 12 suites passed, 0 failures, 0 warnings
    - next: commit

    ### commit — changed
    - evidence: 33aebfba
    - next: review HEAD~1..HEAD
  timestamp: 2026-11-25T16:10:07.681777+00:00
- actor: claude-code
  id: 01m89qxxa5asakpvvx2r9bjwn1
  text: |-
    ### review — findings
    - evidence: review sha 33aebfba~1..33aebfba: 1 finding — Sources/AgentViewKit/StatusLine/StatusLineView.swift:268 (swift/initialization). Note: `review sha HEAD~1..HEAD` resolves in the main checkout (other HEAD), so the sha must be named. The tool rules cannot read the new test files there.
    - next: fix the finding, test, commit, review again
  timestamp: 2026-11-25T16:16:57.157260+00:00
- actor: claude-code
  id: 01m89r5397e74qrkth2nhhqjsk
  text: |-
    ### test — green
    - evidence: swift test: 1747 tests in 199 suites passed, 59 tests in 12 suites passed, 0 failures, 0 warnings (after the fix of the finding)
    - next: commit

    ### commit — changed
    - evidence: 101a75f1
    - next: review

    ### review — clean
    - evidence: review sha 101a75f1~1..101a75f1: 0 findings (attempted 7, refuted 0). The prior finding StatusLineView.swift:268 is fixed in 101a75f1 and checked. Local swiftlint (no_magic_numbers, force rules) on the 4 changed files: no warnings.
    - next: none. Needs a run on a free screen: the scroll profile harness (case A) and the gallery images (light, dark) of the status line.
  timestamp: 2026-11-25T16:20:52.647246+00:00
- actor: claude-code
  id: 01m89taser28y1akagnx6kf0s0
  text: |-
    ### review — clean
    - evidence: `review sha 33aebfba~1..101a75f1` in the main checkout after the merge (HEAD c4ac6dfa): findings 0, confirmed 0, refuted 0, attempted 7, failed 0, skipped 0. 4 files reviewed, 0 not reviewed. The engine read all new files. All prior Review Findings items are checked.
    - next: none. The task stays in done.
  timestamp: 2026-11-25T16:58:56.344986+00:00
position_column: done
position_ordinal: ffffffffa780
title: 'Scroll perf 1: the status line text is one flat Text, with no ViewThatFits in layout'
---
User request (2026-11-25): "scrolling is still way too slow", stay with SwiftUI. The scroll profile (release, 120 Hz, 200 rows; traces in the session scratchpad, `A-mixed-tp.trace`) found that this is 48% of main-thread time during a scroll. With no status line, the median frame goes from 63–69 ms to 14–17 ms.

## What

- `Sources/AgentViewKit/StatusLine/StatusLineView.swift`:
  - `StatusLineText.body` (about line 275) nests `Text("\(text)\(styled(span))")` once for each span (a depth up to 17). SwiftUI parses it again (`LocalizedStringKey.scan`) on each layout pass.
  - `StatusLinePieceText.body` (about line 257) puts each form in a `ViewThatFits`. The safe-area minimum-size query and the window size constraints run it on each frame.
- [x] Build one `AttributedString` for each span set, one time (a memo on the spans and the theme colors), and show one `Text(attributedString)`. Keep the styles, the colors and the accessibility text the same.
  - Note: SwiftUI `Text(AttributedString)` drops image attachments. A span set with an SF Symbol or an icon is one flat `Text` of its `AttributedString` text parts and its images (one interpolation level). A span set with no image is one `Text(attributedString)`.
- [x] Choose the form from the measured width: read the width with `onGeometryChange(for:)`, keep the measured width of each form (one hidden measure each time the spans change), and show only the widest form that fits. No `ViewThatFits`.
- [x] Keep the truncation forms of `piece.narrowerSpans` as they are now.

## Acceptance Criteria

- [x] During a scroll with no change to the status line, `StatusLineText` builds no new text (counter stays 0).
- [x] The status line shows the same forms at the same widths as before (the existing status line tests pass with no change).

## Tests

- [x] New counter test in `Tests/AgentViewKitTests/StatusLine/` (use `BodyEvaluationCounter` or a package counter in the text build): mount `AgentThreadView` with a status line in a window that is never ordered in (the `mount(_:)` pattern of `Tests/AgentViewKitTests/Thread/AnswerTextHitTests.swift`), lay out, move the scroll view clip by N steps with one `layoutSubtreeIfNeeded()` per step, and expect 0 new text builds.
- [x] A test of the form choice: for 3 widths, the shown form is the widest that fits.
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings. No source-scan test.
  - Note: the worktree harness refuses a HOME change. `swift test` with no HOME change passes with 0 failures and 0 warnings. No source-scan test.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- After the change, run the scratch profile harness again (`scratchpad/ScrollProfile`, case A) and add the new frame-time numbers to the card. Gallery images (light, dark) of the status line for review. #perf
  - Note: not run. Both need a window on the shared screen. They need a run.

## Review Findings (2026-11-25 10:11)

> Scope: `review sha 33aebfba~1..33aebfba` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 0 not reviewed.

> The tool rules (disallowed-constructs-swift, function-length-swift, idioms-swift, magic-numbers-swift, missing-docs-swift) declined the three new test files: the engine reads the main checkout, where these files do not exist.

- [x] `Sources/AgentViewKit/StatusLine/StatusLineView.swift:268` `swift/initialization` — The stored property `width` is an Optional that a later callback fills in. Until the first layout, it holds nil. Each reader must test for nil. nil does not mean true absence. It means the width is not measured yet. The `guard let width else { return 0 }` branch in `indexOfWidestForm` handles this state. Declare `@State private var width: CGFloat = .infinity`. `indexOfWidestForm` then returns index 0 for an unmeasured part, the same as nil does now. The non-optional state removes the nil state. Keep the optional parameter on `indexOfWidestForm`, because `sizeThatFits` still passes a nil proposal width.