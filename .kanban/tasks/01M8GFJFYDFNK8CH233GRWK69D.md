---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8gq4z3y7m1g7e0xd9ym5mce
  text: |-
    Research (2026-11-28):
    - Cause: `transcriptRowsHaveDefaultLook` does not read `messageFooter`, `TranscriptRowContent` has no footer data, and `TranscriptRowChrome.message` has no footer node. Thus the cache gives each message row the height with no footer (48 pt), and the real row with `MessageActions` is 73 pt.
    - The footer slot is a closure (`ItemViewRenderer<MessageEntry>`). Each production host (demo `SessionThreadColumn`, the hosted replicas, the gallery, the scroll profile harness) sets `.messageFooter { entry in MessageActions(entry: entry) }`, so the generic modifier sees `Content == MessageActions` at compile time. Plan: the slot keeps a footer kind (`messageActions` or `custom`). The kind goes into the row content: a custom footer makes the message row uncovered (no exact height, so no jump); `MessageActions` adds a chrome node of a probed height (`TranscriptRowMetrics.Atom.messageActions`).
    - Flat form: the footer is a chrome line `.messageActions(look)`. The look (the buttons and their enabled state) comes from the same rules as `MessageActions` (scope availability, or the reasons with no scope), computed in the leaf view of the flat row, so only that leaf observes the session.
    - Harness: spike-final ScrollProfileHarness V0 = recorded session 01M4PF8QH2HSSYSSJS6JVAW9B2 + 50 synthetic turns, `.messageFooter { MessageActions }`, `ExpandedBlocksStore()`.
  timestamp: 2026-11-28T09:18:00.830389+00:00
- actor: claude-code
  id: 01m8grbchks0adjm68zg5srzxr
  text: |-
    ### implement — changed
    - evidence: commit fddd024e (25 files). Decision: a footer kind in the slot (`MessageFooter`: `.messageFooter { MessageActions(entry:) }` is `messageActions`, each other footer is `custom`). Rule adds a chrome node `.messageActions` (probed height); custom footer = uncovered message row (no exact height, no jump). Flat form: chrome line `.messageActions(look)`, look from `MessageActions.Context` in leaf `TranscriptMessageActionsLine`.
    - RED: cached 209 vs mounted 234 (and 177 vs 202): 25 pt. GREEN: parity 0 pt (exactTolerance) for userMessage/agentProse/agentFenced at 320/480/720 and after a resize from 600; flat height == real height. Pixels flat vs real (mean, large part): user 0.065/0.0004 light, 0.071/0.0005 dark; prose 0.121/0.0009, 0.133/0.0011; fenced 0.126/0.0010, 0.133/0.0010 — within RowPixels limits.
    - Flick (50 turns, MessageActions footer): real-row bodies 0. In a scope, the look agrees with the registry (mutation run with no item payload fails the test).
    - Harness transcript (01M4PF8QH2HSSYSSJS6JVAW9B2 + 50 synthetic turns): 312 rows, 103 message rows with a footer. Before: 124 rows kept the old static form (103 messages + 21 terminals). After: 23 (21 terminals: no chrome line; 1 user message with tab-indented lines = indented code; 1 agent message with `<`) — the two messages are Markdown with no picture (`StaticMarkdownPicture.draws`).
    - Tests: root `swift test` 2107 tests / 262 suites + 59 / 12 suites, 0 issues, no warning of the kit. New tests 5 runs alone: 15 tests, 5/5 green.
    - Also removed a `try` with no throwing call in TranscriptFlatRowTests (a warning).
    - Tool friction: each kanban write returns the whole board plan (~190 KB), so the result overflows to a file.
    - next: /review
  timestamp: 2026-11-28T09:38:59.763723+00:00
- actor: claude-code
  id: 01m8gt21qptbrex5zpcbfwdjqa
  text: |-
    ### test — green
    - evidence: worktree HEAD fddd024e. `swift package update EditorKit` in IntegrationTests and ScreenshotTests. `swift build --build-tests`: IntegrationTests complete, ScreenshotTests complete, 0 errors; the nested packages set the footer only with `.messageFooter { ... }`, so the change of the environment value type (closure -> MessageFooter) needs no source change. Demo app: generate_xcodeproj.rb + xcodebuild Debug build: BUILD SUCCEEDED.
    - IntegrationTests (`timeout -s KILL 900 swift test`): 1100 tests in 164 suites passed, 230.8 s, 5 known issues (FontRoleExpectationsTests, expected). No fix, no commit.
    - Gallery (cache cleared, 47 tests passed) copied to scratchpad gallery-footer; compared with gallery-flat. Different PNGs: screens/thread-dark.png (mean 0.0266, large 0.00000, max 2/255, box x0-1519 y1297-1719) and screens/thread-light.png (mean 0.0099, large 0.00000, max 1/255, box y1311-1719): only the backdrop of the bottom bar, no row pixel changes. generated/GlassSnapshotTests/floating-notes-dark.png and floating-notes-reduce-transparency-light.png: mean 0.0023, large 0.00002, box x1502-1513 (scroll indicator; also seen in earlier runs). A second gallery run at HEAD is identical to the first, so the bar backdrop change is certain and comes from HEAD. Its cause is not known yet (probably the content under the bar).
    - next: /review
  timestamp: 2026-11-28T10:08:50.934677+00:00
position_column: doing
position_ordinal: '8580'
title: Static message rows with a footer have a wrong height
---
Found in ^9ync5h3 (2026-11-28). `transcriptRowsHaveDefaultLook` does not look at `messageFooter`, and no chrome rule of `TranscriptRowChrome` has a footer. Thus in a host with a footer (the demo app sets `.messageFooter { MessageActions(entry:) }` in `SessionThreadColumn`), the cache gives each message row a height with no footer.

Probe (StaticRowHost, agent answer of one line, width 480, footer `MessageActions`): cache height 48 pt, static row 48 pt, real row 73 pt. The row jumps 25 pt when it becomes real, and the virtual stack places the rows below it at a wrong y.

## What
- [x] Decide how a footer enters the height: no cache for a thread with a footer, or a chrome rule for a footer of a known height (for example a kit footer API for `MessageActions`, whose height the probe measures).
- [x] When the footer has a rule, give the flat form of a message a chrome line for it (`TranscriptChromeLine`), so a message with `MessageActions` is one flat view while the rows move (today it keeps the views of its real row).

## Tests
- [x] Unit test: a message row with a footer has the same height in its static form and in its real form.

#perf