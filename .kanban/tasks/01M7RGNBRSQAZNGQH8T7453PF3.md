---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7rjspy6h7dbkywn4w78ghmk
  text: |-
    ### implement — changed
    - Close and Open are available while the fork needs input. The card shows Open and Close. Escape on a focused card runs Close in that state (new test).
    - Send to Chat stays unavailable while the fork needs input, with the reason "The side question needs input. Open it to answer." Thus that string is still in use and stays in the catalog.
    - Tests failed first (3 failures), then passed. `swift test`: 1395 + 54 tests pass. ScreenshotTests and IntegrationTests compile with `swift build --build-tests`. `swift format lint -s`: no new findings.
    - evidence: SideCardCommands.swift, SideQuestionCard.swift, SideCardCommandsTests.swift, SideQuestionCardTests.swift, GlassSnapshotTests.swift, ARCHITECTURE.md
    - next: review. Not committed, not pushed (the order said no push).
  timestamp: 2026-11-19T00:20:11.334766+00:00
- actor: claude-code
  id: 01m7rjt79k7nv6v5165b482d0r
  text: 'Orchestrator decision: the implement step is `changed`, not stuck. The card says to remove the string "The side question needs input. Open it to answer." only if nothing uses it. Send to Chat still uses it as its reason while the fork needs input (Send to Chat is hidden then, but the palette can show the reason). Thus the string stays. Continue to test, commit and review.'
  timestamp: 2026-11-19T00:20:28.083554+00:00
- actor: claude-code
  id: 01m7rjwvxa7mkyar81hf7mqs7q
  text: |-
    ### test — green
    - evidence: `swift test` at package root. "Test run with 1395 tests in 164 suites passed after 28.056 seconds." and "Test run with 54 tests in 11 suites passed after 0.012 seconds." `swift build --build-tests` in ScreenshotTests: Build complete. `swift format lint -s` on the 5 changed Swift files: 0 findings.
    - next: review. IntegrationTests and ScreenshotTests were not run (they take the screen focus).
  timestamp: 2026-11-19T00:21:54.730950+00:00
- actor: claude-code
  id: 01m7rk17wwdhkqqycxdzge9748
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (a0810719). 0 findings, 0 confirmed, 0 refuted. 7 pairs attempted, 0 failed. The engine reviewed 5 files. It did not review 2 .kanban files (ignore rule) and ARCHITECTURE.md (no validator matched).
    - next: The task is in done. Push, and send the sha to testudoapp-9a, as the task tells.
  timestamp: 2026-11-19T00:24:18.076550+00:00
- actor: claude-code
  id: 01m7rk1k891hy8dd8wrey8pyrk
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — SideCardCommands.swift, SideQuestionCard.swift, 2 unit test files, GlassSnapshotTests.swift, ARCHITECTURE.md
    - test: green — swift test, 1395 tests in 164 suites + 54 tests in 11 suites passed
    - commit: a0810719
    - review: clean — 0 findings
  timestamp: 2026-11-19T00:24:29.705139+00:00
position_column: done
position_ordinal: fffffff780
title: 'Side card: Close stays available while the fork needs input'
---
Request from testudoapp-9a (2026-11-18), after task 01M7QV7CE6YS0MPFZY7XF6J8GK (8eab72b1, 497a1d5a, 968473ff).

Now: while the fork of a `SideQuestionCard` needs input (a pending permission request or an elicitation), the card shows "Needs input" and the Open button only. The Close verb is unavailable, with the reason "The side question needs input. Open it to answer."

The user must always be able to dismiss a side question. The app handles Close: it stops the turn of the fork and archives the fork (D204, so undo brings it back).

Do:
- While the fork needs input, Close stays available with no reason, and the card shows the Close button. Open also stays available. Send to Chat stays hidden in that state.
- Escape on a focused card runs Close also in that state.
- Remove the string "The side question needs input. Open it to answer." from the catalog if nothing uses it.
- Update the unit tests and the snapshot test of the needs-input card (compile only, do not run ScreenshotTests).

Run `swift test`. Push, and send the sha to testudoapp-9a.